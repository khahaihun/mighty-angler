--!strict
-- ShopPanel.luau: Cua hang O Luoi 3D (6 Can thuong du 5 chi so + Bar %, Bait, Gym Gear & 5 Gamepasses kem Hop Chi Tiet Before/After)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))
local CatchControl = require(Shared:WaitForChild("CatchControl"))
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local RodsConfig = require(Shared:WaitForChild("Config"):WaitForChild("RodsConfig"))
local BaitConfig = require(Shared:WaitForChild("Config"):WaitForChild("BaitConfig"))
local GymGearConfig = require(Shared:WaitForChild("Config"):WaitForChild("GymGearConfig"))
local GamepassesConfig = require(Shared:WaitForChild("Config"):WaitForChild("GamepassesConfig"))

local Theme = require(script.Parent.Parent.Theme)
local PurchaseOddsController = require(script.Parent.Parent.Parent.Controllers.PurchaseOddsController)
local WindowFrame = require(script.Parent.Parent.Components.WindowFrame)
local ViewportCard = require(script.Parent.Parent.Components.ViewportCard)
local ViewportPool = require(script.Parent.Parent.Components.ViewportPool)

local ShopPanel = {}

local win: WindowFrame.BuiltWindow? = nil
local detailBox: Frame? = nil
local detailTitle: TextLabel? = nil
local detailSub: TextLabel? = nil
local detailActionBtn: TextButton? = nil
local gridHandle: ViewportPool.GridHandle? = nil
local currentTab = "Rods"
local focusedKey: string? = nil
local selectedPassKey = "AutoFish"
local detailBtnHandler: (() -> ())? = nil

local curGold = 0
local curStrength = 0
local curRodId = "Twig"
local ownedRods: { [string]: boolean } = { Twig = true }
local curGearLevel = 0
local ownedPasses: { [string]: boolean } = {}

local function getPassBeforeAfterNote(gpKey: string): string
	if gpKey == "AutoFish" then
		return "Before (Free Auto): +0% Cast Luck, +0% Lure, 1.10s Recast  →  After (Auto-Fish Pro): 100% Perfect Cast (+25% Cast Luck, +15% Lure) & 0.45s Recast!"
	elseif gpKey == "ExclusiveDragonRod" then
		local best = RodsConfig.GetBestNormalRod(ownedRods)
		local eff = RodsConfig.GetEffectiveStats("SeraphimDragon", ownedRods, {})
		return string.format("Scales 130%% off %s → %s Max Kg, +%d%% Lure, +%d%% Luck, +%d%% Ctrl, %d%% Stdy (0 Str Equip, Keeps on Rebirth, Enchantable)!", best.name, Util.FormatWeight(eff.maxWeight), math.floor(eff.lureSpeed * 100), math.floor(eff.luckBonus * 100), math.floor(eff.controlBonus * 100), math.floor(eff.steadiness * 100))
	elseif gpKey == "DoubleGold" then
		return "Multiplies Gold earned from all 4 Fish Market sell modes by 2.0x permanently!"
	elseif gpKey == "DoubleStrength" then
		return "Multiplies Strength gained from Gym Stations & Fish Catches by 2.0x permanently!"
	end
	return string.format("Active Pet slots: %d → %d simultaneously!", GameConfig.BASE_PET_EQUIP_SLOTS, GameConfig.BASE_PET_EQUIP_SLOTS + GameConfig.BONUS_PET_EQUIP_SLOTS)
end

local function setDetailHeader(titleTxt: string, subTxt: string, col: Color3, btnTxt: string?, btnCol: Color3?, onBtn: (() -> ())?)
	if not detailBox or not detailTitle or not detailSub or not detailActionBtn then return end
	detailTitle.Text = titleTxt
	detailTitle.TextColor3 = col
	detailSub.Text = subTxt
	local margin = if btnTxt then -152 else -20
	detailTitle.Size = UDim2.new(1, margin, 0, 22)
	detailSub.Size = UDim2.new(1, margin, 0, 46)
	detailBtnHandler = onBtn
	if btnTxt then
		detailActionBtn.Visible = true
		detailActionBtn.Text = btnTxt
		detailActionBtn.BackgroundColor3 = btnCol or Theme.Colors.Success
	else
		detailActionBtn.Visible = false
	end
end

function ShopPanel.Render()
	local w = win
	local gh = gridHandle
	if not w or not gh then return end

	local specs: { ViewportCard.CardVisualSpec } = {}

	if currentTab == "Rods" then
		setDetailHeader(
			"🎣 Normal Rods — Full 5 Stats (Max Kg • Lure • Luck • Control • Steadiness)",
			"Catch Bar Base: Rare/Leg 28% + Ctrl • Boss 22% + Ctrl (Capped at 68% with Strength Mastery). Visit [🔮 Enchants] for 3 Exclusive Rods!",
			Theme.Colors.Warning, nil, nil, nil
		)
		for idx, rod in ipairs(RodsConfig.NormalList) do
			local isOwned = ownedRods[rod.id] == true
			local isEquipped = (curRodId == rod.id)
			local strMet = (curStrength >= rod.strengthReq)
			local bonus = CatchControl.ComputeWidthBonus(curStrength, rod.strengthReq, rod.controlBonus)
			local rareBar = math.floor(CatchControl.ComputeWidth(false, bonus) * 100 + 0.5)
			local bossBar = math.floor(CatchControl.ComputeWidth(true, bonus) * 100 + 0.5)
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
				key = "rod_" .. rod.id, order = idx, title = rod.name,
				subtitle = string.format("%s • +%d%%Lk • +%d%%Lr • Bar %d/%d%%", Util.FormatWeight(rod.maxWeight), math.floor(rod.luckBonus * 100), math.floor(rod.lureSpeed * 100), rareBar, bossBar),
				footerText = fText, footerColor = fCol, strokeColor = rod.accentColor,
				bgColor = if isEquipped then Theme.Colors.CardOwned else Theme.Colors.CardBg,
				topLeftBadge = string.format("P%d • +%d%%Ctrl • %d%%Stdy", rod.power, math.floor(rod.controlBonus * 100), math.floor(rod.steadiness * 100)),
				topLeftColor = rod.accentColor, modelSignature = "Rod_" .. rod.id,
				modelSpec = { kind = "Rod", primaryColor = rod.rodColor, secondaryColor = rod.accentColor, modelRefData = rod },
				onActivate = function()
					focusedKey = "rod_" .. rod.id
					if isOwned then Net.FireServer(Net.ClientToServer.EquipRod, rod.id)
					else Net.FireServer(Net.ClientToServer.BuyRod, rod.id) end
				end,
			})
		end
	elseif currentTab == "Bait" then
		setDetailHeader("🪱 Fishing Bait Packs (Consumed ONLY when a fish is landed!)", "Land bounces, cancellations & missed minigames never consume bait. Switch bait anytime at bottom-right!", Theme.Colors.Primary, nil, nil, nil)
		for idx, bDef in ipairs(BaitConfig.List) do
			table.insert(specs, {
				key = "shopbait_" .. bDef.id, order = idx, title = bDef.name,
				subtitle = string.format("%s • x%d", bDef.description, bDef.packSize),
				footerText = Util.FormatNumber(bDef.priceGold) .. " Gold",
				footerColor = if curGold >= bDef.priceGold then Theme.Colors.Success else Color3.fromRGB(78, 88, 112),
				strokeColor = bDef.color, bgColor = Theme.Colors.CardBg,
				topLeftBadge = "x" .. tostring(bDef.packSize), topLeftColor = bDef.color,
				modelSignature = "ShopBait_" .. bDef.id,
				modelSpec = { kind = "Bait", primaryColor = bDef.color, secondaryColor = Theme.Colors.Gold },
				onActivate = function() focusedKey = "shopbait_" .. bDef.id; Net.FireServer(Net.ClientToServer.BuyBait, bDef.id) end,
			})
		end
	elseif currentTab == "Gear" then
		setDetailHeader("🥊 Permanent Gym Gear Upgrades", "Boosts Strength gained per training rep across all 5 Islands! Resets on Rebirth for higher Rank Multipliers.", Theme.Colors.Strength, nil, nil, nil)
		for idx, gDef in ipairs(GymGearConfig.List) do
			local owned = (curGearLevel >= gDef.level)
			local isNext = (curGearLevel + 1 == gDef.level)
			table.insert(specs, {
				key = "gear_" .. gDef.id, order = idx, title = gDef.name,
				subtitle = string.format("+%d%% Gym Strength", math.floor(gDef.strengthBonus * 100)),
				footerText = if owned then "OWNED ✅" elseif isNext then (Util.FormatNumber(gDef.priceGold) .. " Gold") else "LOCKED",
				footerColor = if owned then Theme.Colors.Primary elseif isNext then Theme.Colors.Success else Color3.fromRGB(78, 86, 108),
				strokeColor = gDef.color, bgColor = if owned then Theme.Colors.CardOwned else Theme.Colors.CardBg,
				topLeftBadge = "Lv." .. tostring(gDef.level), topLeftColor = gDef.color,
				modelSignature = "Gear_" .. gDef.id,
				modelSpec = { kind = "Gear", primaryColor = gDef.color, secondaryColor = Color3.fromRGB(228, 236, 248) },
				onActivate = function() focusedKey = "gear_" .. gDef.id; if isNext then Net.FireServer(Net.ClientToServer.BuyGymGear, gDef.level) end end,
			})
		end
	else
		local selGp = GamepassesConfig.ByKey[selectedPassKey] or GamepassesConfig.List[1]
		local selOwned = ownedPasses[selGp.key] == true
		setDetailHeader(
			string.format("⭐ %s (%s)", selGp.name, if selOwned then "ACTIVE ✅" else ("R$ " .. tostring(selGp.robuxDisplay))),
			selGp.description .. "\n" .. getPassBeforeAfterNote(selGp.key),
			selGp.color,
			if selOwned then "OWNED ✅" else ("BUY R$ " .. tostring(selGp.robuxDisplay)),
			if selOwned then Theme.Colors.Primary else Theme.Colors.Success,
			function()
				if not selOwned then PurchaseOddsController.Show(selGp.key) end
			end
		)

		for idx, gp in ipairs(GamepassesConfig.List) do
			local hasPass = ownedPasses[gp.key] == true
			local isSel = (selectedPassKey == gp.key)
			table.insert(specs, {
				key = "pass_" .. gp.key, order = idx, title = gp.name,
				subtitle = if isSel then "Selected — See Full Details Above" else "Tap to Preview Full Stats",
				footerText = if hasPass then "ACTIVE ✅" elseif isSel then ("BUY R$ " .. tostring(gp.robuxDisplay)) else ("VIEW • R$ " .. tostring(gp.robuxDisplay)),
				footerColor = if hasPass then Theme.Colors.Primary elseif isSel then Theme.Colors.Success else Theme.Colors.Warning,
				strokeColor = if isSel then Theme.Colors.Gold else gp.color,
				bgColor = if hasPass or isSel then Theme.Colors.CardOwned else Theme.Colors.CardBg,
				topLeftBadge = "PASS", topLeftColor = gp.color,
				modelSignature = "Pass_" .. gp.key,
				modelSpec = { kind = "Gear", primaryColor = gp.color, secondaryColor = Theme.Colors.Gold },
				onActivate = function()
					focusedKey = "pass_" .. gp.key
					if selectedPassKey ~= gp.key then
						selectedPassKey = gp.key
						ShopPanel.Render()
					elseif not hasPass then
						PurchaseOddsController.Show(gp.key)
					end
				end,
			})
		end
	end

	gh.SyncItems(specs, focusedKey)
end

function ShopPanel.Mount(rootGui: ScreenGui): WindowFrame.BuiltWindow
	local built = WindowFrame.Create(rootGui, "ShopWindow", "🛒 ANGLER & GYM 3D SHOP", UDim2.fromOffset(620, 465), Theme.Colors.Warning)
	win = built

	local box = Instance.new("Frame")
	box.Size = UDim2.new(1, 0, 0, 80)
	box.BackgroundColor3 = Theme.Colors.CardOwned
	box.LayoutOrder = 1
	box.ZIndex = 22
	box.Parent = built.body
	Theme.AddCorner(box, 10)
	Theme.AddStroke(box, Theme.Colors.Warning, 2)
	detailBox = box

	local dt = Instance.new("TextLabel")
	dt.Position = UDim2.fromOffset(10, 5)
	dt.Size = UDim2.new(1, -20, 0, 22)
	dt.BackgroundTransparency = 1
	dt.Font = Theme.FontTitle
	dt.TextSize = 14
	dt.TextXAlignment = Enum.TextXAlignment.Left
	dt.ZIndex = 23
	dt.Parent = box
	Theme.AddTextStroke(dt, 1.4)
	detailTitle = dt

	local ds = Instance.new("TextLabel")
	ds.Position = UDim2.fromOffset(10, 27)
	ds.Size = UDim2.new(1, -20, 0, 46)
	ds.BackgroundTransparency = 1
	ds.Font = Theme.FontBody
	Theme.FitText(ds, 13, 11)
	ds.TextWrapped = true
	ds.TextXAlignment = Enum.TextXAlignment.Left
	ds.TextColor3 = Theme.Colors.TextPrimary
	ds.ZIndex = 23
	ds.Parent = box
	detailSub = ds

	local dBtn = Theme.CreateButton(box, "DetailActionBtn", "BUY", UDim2.fromOffset(132, 38), UDim2.new(1, -142, 0.5, -19), Theme.Colors.Success, function()
		if detailBtnHandler then detailBtnHandler() end
	end)
	dBtn.TextSize = 13; dBtn.ZIndex = 24; dBtn.Visible = false
	detailActionBtn = dBtn

	gridHandle = ViewportPool.CreateGrid(built.body, 2, UDim2.fromOffset(136, 154))
	built.OnVisibilityChanged(function(vis: boolean)
		if not vis then ViewportPool.ClearFocus() else ShopPanel.Render() end
	end)

	local rodTab = built.AddTab("Rods", function() currentTab = "Rods"; ShopPanel.Render() end)
	built.AddTab("Bait", function() currentTab = "Bait"; ShopPanel.Render() end)
	built.AddTab("Gear", function() currentTab = "Gear"; ShopPanel.Render() end)
	built.AddTab("Passes", function() currentTab = "Passes"; ShopPanel.Render() end)
	built.SetActiveTab(rodTab)
	return built
end

function ShopPanel.SyncState(gold: number, strength: number, rodId: string, ownedMap: { [string]: boolean }, gearLv: number)
	curGold = gold; curStrength = strength; curRodId = rodId; ownedRods = ownedMap; curGearLevel = gearLv
	if win and win.IsVisible() then ShopPanel.Render() end
end

function ShopPanel.SyncPasses(perkSnap: any)
	if type(perkSnap) ~= "table" then return end
	ownedPasses = {
		AutoFish = perkSnap.autoFish == true, DoubleGold = perkSnap.doubleGold == true,
		DoubleStrength = perkSnap.doubleStrength == true, ExtraPets = perkSnap.extraPets == true,
		ExclusiveDragonRod = perkSnap.exclusiveDragonRod == true,
	}
	if win and win.IsVisible() and currentTab == "Passes" then ShopPanel.Render() end
end

return ShopPanel
