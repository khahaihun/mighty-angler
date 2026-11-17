--!strict
-- ShopPanel.luau: Cua hang 4 tab (Rods, Bait, Gym Gear, Passes) voi hien thi dieu kien Strength & Gold ro rang

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))
local RodsConfig = require(Shared:WaitForChild("Config"):WaitForChild("RodsConfig"))
local GamepassesConfig = require(Shared:WaitForChild("Config"):WaitForChild("GamepassesConfig"))

local Theme = require(script.Parent.Parent.Theme)
local WindowFrame = require(script.Parent.Parent.Components.WindowFrame)

local ShopPanel = {}

local win: WindowFrame.BuiltWindow? = nil
local currentTab = "Rods"

local curGold = 0
local curStrength = 0
local curRodId = "Twig"
local ownedRods: { [string]: boolean } = { Twig = true }
local curGearLevel = 0
local ownedPasses: { [string]: boolean } = {}

local baitCfgRef: any = nil
local gearCfgRef: any = nil

local function ensureOptionalConfigs()
	local cfg = Shared:FindFirstChild("Config")
	if not cfg then
		return
	end
	if not baitCfgRef then
		local b = cfg:FindFirstChild("BaitConfig")
		if b and b:IsA("ModuleScript") then
			baitCfgRef = require(b) :: any
		end
	end
	if not gearCfgRef then
		local g = cfg:FindFirstChild("GymGearConfig")
		if g and g:IsA("ModuleScript") then
			gearCfgRef = require(g) :: any
		end
	end
end

local function clearBody(body: ScrollingFrame)
	for _, ch in ipairs(body:GetChildren()) do
		if ch:IsA("GuiObject") then
			ch:Destroy()
		end
	end
end

local function makeRowCard(body: ScrollingFrame, order: number, titleText: string, subText: string, strokeCol: Color3, bgCol: Color3): Frame
	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, 0, 0, 64)
	card.BackgroundColor3 = bgCol
	card.LayoutOrder = order
	card.ZIndex = 22
	card.Parent = body
	Theme.AddCorner(card, 10)
	Theme.AddStroke(card, strokeCol, 2)

	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(0.66, 0, 0, 28)
	t.Position = UDim2.fromOffset(12, 6)
	t.BackgroundTransparency = 1
	t.Font = Theme.FontTitle
	t.TextSize = 17
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.TextColor3 = strokeCol
	t.Text = titleText
	t.ZIndex = 23
	t.Parent = card
	Theme.AddTextStroke(t, 1.5)

	local s = Instance.new("TextLabel")
	s.Size = UDim2.new(0.66, 0, 0, 22)
	s.Position = UDim2.fromOffset(12, 34)
	s.BackgroundTransparency = 1
	s.Font = Theme.FontBody
	s.TextSize = 13
	s.TextXAlignment = Enum.TextXAlignment.Left
	s.TextColor3 = Theme.Colors.TextMuted
	s.Text = subText
	s.ZIndex = 23
	s.Parent = card

	return card
end

function ShopPanel.Render()
	local w = win
	if not w then
		return
	end
	ensureOptionalConfigs()
	clearBody(w.body)

	if currentTab == "Rods" then
		for idx, rod in ipairs(RodsConfig.List) do
			local isOwned = ownedRods[rod.id] == true
			local isEquipped = (curRodId == rod.id)
			local strMet = (curStrength >= rod.strengthReq)
			local sub = string.format(
				"Power %d • +%d%% Luck • Req: %s Str",
				rod.power,
				math.floor(rod.luckBonus * 100 + 0.5),
				Util.FormatNumber(rod.strengthReq)
			)

			local cardBg = if isEquipped then Theme.Colors.CardOwned else Theme.Colors.CardBg
			local card = makeRowCard(w.body, idx, "🎣 " .. rod.name, sub, rod.accentColor, cardBg)

			local btnText = "BUY: " .. Util.FormatNumber(rod.priceGold) .. "G"
			local btnCol = Theme.Colors.Success
			if isEquipped then
				btnText = "EQUIPPED"
				btnCol = Theme.Colors.Primary
			elseif isOwned then
				btnText = if strMet then "EQUIP" else "NEED STR"
				btnCol = if strMet then Theme.Colors.Warning else Theme.Colors.Danger
			elseif not strMet then
				btnText = "LOCKED (STR)"
				btnCol = Color3.fromRGB(92, 68, 78)
			elseif curGold < rod.priceGold then
				btnCol = Color3.fromRGB(82, 92, 114)
			end

			local btn = Theme.CreateButton(card, "ActionBtn", btnText, UDim2.fromOffset(144, 38), UDim2.new(1, -156, 0.5, -19), btnCol, function()
				if isOwned then
					Net.FireServer(Net.ClientToServer.EquipRod, rod.id)
				else
					Net.FireServer(Net.ClientToServer.BuyRod, rod.id)
				end
			end)
			btn.TextSize = 14
			btn.ZIndex = 23
		end
	elseif currentTab == "Bait" then
		if not baitCfgRef then
			makeRowCard(w.body, 1, "🪱 Bait Shop", "Bait packs unlock in Milestone 2!", Theme.Colors.Gold, Theme.Colors.CardBg)
			return
		end
		for idx, bDef in ipairs(baitCfgRef.List) do
			local sub = string.format("%s • Pack of %d", bDef.description, bDef.packSize)
			local card = makeRowCard(w.body, idx, "🪱 " .. bDef.name, sub, bDef.color, Theme.Colors.CardBg)
			local btn = Theme.CreateButton(
				card,
				"BuyBaitBtn",
				Util.FormatNumber(bDef.priceGold) .. "G (x" .. tostring(bDef.packSize) .. ")",
				UDim2.fromOffset(144, 38),
				UDim2.new(1, -156, 0.5, -19),
				Theme.Colors.Success,
				function()
					Net.FireServer(Net.ClientToServer.BuyBait, bDef.id)
				end
			)
			btn.TextSize = 14
			btn.ZIndex = 23
		end
	elseif currentTab == "Gear" then
		if not gearCfgRef then
			makeRowCard(w.body, 1, "🥊 Gym Gear", "Permanent Gym Gear upgrades unlock in Milestone 2!", Theme.Colors.Strength, Theme.Colors.CardBg)
			return
		end
		for idx, gDef in ipairs(gearCfgRef.List) do
			local owned = (curGearLevel >= gDef.level)
			local isNext = (curGearLevel + 1 == gDef.level)
			local cardBg = if owned then Theme.Colors.CardOwned else Theme.Colors.CardBg
			local card = makeRowCard(w.body, idx, "🥊 " .. gDef.name, gDef.description, gDef.color, cardBg)
			local btnText = if owned then "OWNED" elseif isNext then (Util.FormatNumber(gDef.priceGold) .. " Gold") else "BUY PREV FIRST"
			local btnCol = if owned then Theme.Colors.Primary elseif isNext then Theme.Colors.Success else Color3.fromRGB(78, 86, 108)
			local btn = Theme.CreateButton(card, "BuyGearBtn", btnText, UDim2.fromOffset(144, 38), UDim2.new(1, -156, 0.5, -19), btnCol, function()
				if isNext then
					Net.FireServer(Net.ClientToServer.BuyGymGear, gDef.level)
				end
			end)
			btn.TextSize = 14
			btn.ZIndex = 23
		end
	else
		for idx, gp in ipairs(GamepassesConfig.List) do
			local hasPass = ownedPasses[gp.key] == true
			local card = makeRowCard(w.body, idx, "⭐ " .. gp.name, gp.description, gp.color, if hasPass then Theme.Colors.CardOwned else Theme.Colors.CardBg)
			local btnText = if hasPass then "ACTIVE" else ("R$ " .. tostring(gp.robuxDisplay))
			local btnCol = if hasPass then Theme.Colors.Primary else Theme.Colors.Success
			local btn = Theme.CreateButton(card, "PassBtn", btnText, UDim2.fromOffset(132, 38), UDim2.new(1, -144, 0.5, -19), btnCol, function()
				if not hasPass then
					Net.FireServer(Net.ClientToServer.PromptGamepass, gp.key)
				end
			end)
			btn.TextSize = 15
			btn.ZIndex = 23
		end
	end
end

function ShopPanel.Mount(rootGui: ScreenGui): WindowFrame.BuiltWindow
	local built = WindowFrame.Create(rootGui, "ShopWindow", "🛒 ANGLER & GYM SHOP", UDim2.fromOffset(600, 430), Theme.Colors.Warning)
	win = built

	local rodTab = built.AddTab("Rods", function()
		currentTab = "Rods"
		ShopPanel.Render()
	end)
	built.AddTab("Bait", function()
		currentTab = "Bait"
		ShopPanel.Render()
	end)
	built.AddTab("Gear", function()
		currentTab = "Gear"
		ShopPanel.Render()
	end)
	built.AddTab("Passes", function()
		currentTab = "Passes"
		ShopPanel.Render()
	end)
	built.SetActiveTab(rodTab)
	ShopPanel.Render()
	return built
end

function ShopPanel.SyncState(gold: number, strength: number, rodId: string, ownedMap: { [string]: boolean }, gearLv: number)
	curGold = gold
	curStrength = strength
	curRodId = rodId
	ownedRods = ownedMap
	curGearLevel = gearLv
	if win and win.IsVisible() then
		ShopPanel.Render()
	end
end

function ShopPanel.SyncPasses(perkSnap: any)
	if type(perkSnap) ~= "table" then
		return
	end
	ownedPasses = {
		AutoFish = perkSnap.autoFish == true,
		DoubleGold = perkSnap.doubleGold == true,
		DoubleStrength = perkSnap.doubleStrength == true,
		ExtraPets = perkSnap.extraPets == true,
	}
	if win and win.IsVisible() and currentTab == "Passes" then
		ShopPanel.Render()
	end
end

return ShopPanel
