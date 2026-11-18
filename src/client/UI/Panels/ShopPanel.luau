--!strict
-- ShopPanel.luau: Cua hang O Luoi 3D (ViewportPool) cho 6 Can thuong (5 chi so), Bait, Gym Gear & 5 Gamepasses

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))
local RodsConfig = require(Shared:WaitForChild("Config"):WaitForChild("RodsConfig"))
local BaitConfig = require(Shared:WaitForChild("Config"):WaitForChild("BaitConfig"))
local GymGearConfig = require(Shared:WaitForChild("Config"):WaitForChild("GymGearConfig"))
local GamepassesConfig = require(Shared:WaitForChild("Config"):WaitForChild("GamepassesConfig"))

local Theme = require(script.Parent.Parent.Theme)
local WindowFrame = require(script.Parent.Parent.Components.WindowFrame)
local ViewportCard = require(script.Parent.Parent.Components.ViewportCard)
local ViewportPool = require(script.Parent.Parent.Components.ViewportPool)

local ShopPanel = {}

local win: WindowFrame.BuiltWindow? = nil
local infoLbl: TextLabel? = nil
local gridHandle: ViewportPool.GridHandle? = nil
local currentTab = "Rods"
local focusedKey: string? = nil

local curGold = 0
local curStrength = 0
local curRodId = "Twig"
local ownedRods: { [string]: boolean } = { Twig = true }
local curGearLevel = 0
local ownedPasses: { [string]: boolean } = {}

function ShopPanel.Render()
	local w = win
	local gh = gridHandle
	if not w or not gh then return end

	local specs: { ViewportCard.CardVisualSpec } = {}

	if currentTab == "Rods" then
		if infoLbl then
			infoLbl.Text = "🎣 Normal Rods (5 Stats: Max Kg • Lure • Luck • Ctrl • Steadiness) — Visit Enchants Window for 3 Exclusive Rods!"
		end
		for idx, rod in ipairs(RodsConfig.NormalList) do
			local isOwned = ownedRods[rod.id] == true
			local isEquipped = (curRodId == rod.id)
			local strMet = (curStrength >= rod.strengthReq)
			local fText = if isEquipped then "EQUIPPED"
				elseif isOwned then (if strMet then "EQUIP" else ("NEED " .. Util.FormatNumber(rod.strengthReq) .. " STR"))
				elseif not strMet then ("REQ " .. Util.FormatNumber(rod.strengthReq) .. " STR")
				else (Util.FormatNumber(rod.priceGold) .. " Gold")
			local fCol = if isEquipped then Theme.Colors.Primary
				elseif isOwned then (if strMet then Theme.Colors.Warning else Theme.Colors.Danger)
				elseif not strMet then Color3.fromRGB(92, 68, 78)
				elseif curGold >= rod.priceGold then Theme.Colors.Success
				else Color3.fromRGB(78, 88, 112)

			table.insert(specs, {
				key = "rod_" .. rod.id,
				order = idx,
				title = rod.name,
				subtitle = string.format("%s • +%d%% Luck • +%d%% Lure", Util.FormatWeight(rod.maxWeight), math.floor(rod.luckBonus * 100), math.floor(rod.lureSpeed * 100)),
				footerText = fText,
				footerColor = fCol,
				strokeColor = rod.accentColor,
				bgColor = if isEquipped then Theme.Colors.CardOwned else Theme.Colors.CardBg,
				topLeftBadge = string.format("P%d • +%d%% Ctrl", rod.power, math.floor(rod.controlBonus * 100)),
				topLeftColor = rod.accentColor,
				modelSignature = "Rod_" .. rod.id,
				modelSpec = { kind = "Rod", primaryColor = rod.rodColor, secondaryColor = rod.accentColor, modelRefData = rod },
				onActivate = function()
					focusedKey = "rod_" .. rod.id
					if isOwned then Net.FireServer(Net.ClientToServer.EquipRod, rod.id)
					else Net.FireServer(Net.ClientToServer.BuyRod, rod.id) end
				end,
			})
		end
	elseif currentTab == "Bait" then
		if infoLbl then infoLbl.Text = "🪱 Fishing Bait Packs (Switch equipped bait anytime at the bottom-right Bait Selector!)" end
		for idx, bDef in ipairs(BaitConfig.List) do
			table.insert(specs, {
				key = "shopbait_" .. bDef.id,
				order = idx,
				title = bDef.name,
				subtitle = string.format("+%d%% Luck • x%d Pack", math.floor(bDef.luckBonus * 100), bDef.packSize),
				footerText = Util.FormatNumber(bDef.priceGold) .. " Gold",
				footerColor = if curGold >= bDef.priceGold then Theme.Colors.Success else Color3.fromRGB(78, 88, 112),
				strokeColor = bDef.color,
				bgColor = Theme.Colors.CardBg,
				topLeftBadge = "x" .. tostring(bDef.packSize),
				topLeftColor = bDef.color,
				modelSignature = "ShopBait_" .. bDef.id,
				modelSpec = { kind = "Bait", primaryColor = bDef.color, secondaryColor = Theme.Colors.Gold },
				onActivate = function()
					focusedKey = "shopbait_" .. bDef.id
					Net.FireServer(Net.ClientToServer.BuyBait, bDef.id)
				end,
			})
		end
	elseif currentTab == "Gear" then
		if infoLbl then infoLbl.Text = "🥊 Permanent Gym Gear Upgrades (Boosts Strength gained per rep!)" end
		for idx, gDef in ipairs(GymGearConfig.List) do
			local owned = (curGearLevel >= gDef.level)
			local isNext = (curGearLevel + 1 == gDef.level)
			table.insert(specs, {
				key = "gear_" .. gDef.id,
				order = idx,
				title = gDef.name,
				subtitle = string.format("+%d%% Gym Strength", math.floor(gDef.strengthBonus * 100)),
				footerText = if owned then "OWNED ✅" elseif isNext then (Util.FormatNumber(gDef.priceGold) .. " Gold") else "LOCKED",
				footerColor = if owned then Theme.Colors.Primary elseif isNext then Theme.Colors.Success else Color3.fromRGB(78, 86, 108),
				strokeColor = gDef.color,
				bgColor = if owned then Theme.Colors.CardOwned else Theme.Colors.CardBg,
				topLeftBadge = "Lv." .. tostring(gDef.level),
				topLeftColor = gDef.color,
				modelSignature = "Gear_" .. gDef.id,
				modelSpec = { kind = "Gear", primaryColor = gDef.color, secondaryColor = Color3.fromRGB(228, 236, 248) },
				onActivate = function()
					focusedKey = "gear_" .. gDef.id
					if isNext then Net.FireServer(Net.ClientToServer.BuyGymGear, gDef.level) end
				end,
			})
		end
	else
		if infoLbl then infoLbl.Text = "⭐ Permanent VIP Perks (Auto-Fish Pro gives 100% Perfect Cast +25% Luck & 0.45s Recast!)" end
		for idx, gp in ipairs(GamepassesConfig.List) do
			local hasPass = ownedPasses[gp.key] == true
			table.insert(specs, {
				key = "pass_" .. gp.key,
				order = idx,
				title = gp.name,
				subtitle = gp.description,
				footerText = if hasPass then "ACTIVE ✅" else ("R$ " .. tostring(gp.robuxDisplay)),
				footerColor = if hasPass then Theme.Colors.Primary else Theme.Colors.Success,
				strokeColor = gp.color,
				bgColor = if hasPass then Theme.Colors.CardOwned else Theme.Colors.CardBg,
				topLeftBadge = "PASS",
				topLeftColor = gp.color,
				modelSignature = "Pass_" .. gp.key,
				modelSpec = { kind = "Gear", primaryColor = gp.color, secondaryColor = Theme.Colors.Gold },
				onActivate = function()
					focusedKey = "pass_" .. gp.key
					if not hasPass then Net.FireServer(Net.ClientToServer.PromptGamepass, gp.key) end
				end,
			})
		end
	end

	gh.SyncItems(specs, focusedKey)
end

function ShopPanel.Mount(rootGui: ScreenGui): WindowFrame.BuiltWindow
	local built = WindowFrame.Create(rootGui, "ShopWindow", "🛒 ANGLER & GYM 3D SHOP", UDim2.fromOffset(610, 455), Theme.Colors.Warning)
	win = built

	local info = Instance.new("TextLabel")
	info.Size = UDim2.new(1, 0, 0, 26)
	info.BackgroundTransparency = 1
	info.Font = Theme.FontBody
	info.TextSize = 13
	info.TextXAlignment = Enum.TextXAlignment.Left
	info.TextColor3 = Theme.Colors.TextMuted
	info.LayoutOrder = 1
	info.ZIndex = 22
	info.Parent = built.body
	infoLbl = info

	gridHandle = ViewportPool.CreateGrid(built.body, 2, UDim2.fromOffset(136, 154))
	built.OnVisibilityChanged(function(vis: boolean)
		if not vis then ViewportPool.ClearFocus() end
	end)

	local rodTab = built.AddTab("Rods", function() currentTab = "Rods"; ShopPanel.Render() end)
	built.AddTab("Bait", function() currentTab = "Bait"; ShopPanel.Render() end)
	built.AddTab("Gear", function() currentTab = "Gear"; ShopPanel.Render() end)
	built.AddTab("Passes", function() currentTab = "Passes"; ShopPanel.Render() end)
	built.SetActiveTab(rodTab)
	return built
end

function ShopPanel.SyncState(gold: number, strength: number, rodId: string, ownedMap: { [string]: boolean }, gearLv: number)
	curGold = gold
	curStrength = strength
	curRodId = rodId
	ownedRods = ownedMap
	curGearLevel = gearLv
	if win and win.IsVisible() then ShopPanel.Render() end
end

function ShopPanel.SyncPasses(perkSnap: any)
	if type(perkSnap) ~= "table" then return end
	ownedPasses = {
		AutoFish = perkSnap.autoFish == true,
		DoubleGold = perkSnap.doubleGold == true,
		DoubleStrength = perkSnap.doubleStrength == true,
		ExtraPets = perkSnap.extraPets == true,
		ExclusiveDragonRod = perkSnap.exclusiveDragonRod == true,
	}
	if win and win.IsVisible() and currentTab == "Passes" then ShopPanel.Render() end
end

return ShopPanel
