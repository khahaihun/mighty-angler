--!strict
-- HudPanel.luau: Giao dien chinh (Gold, Gems, Strength, Tien do Can ke tiep, Menu trai, Nut Cast/Auto/Sell)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Util = require(Shared:WaitForChild("Util"))
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local RodsConfig = require(Shared:WaitForChild("Config"):WaitForChild("RodsConfig"))
local IslandsRegistry = require(Shared:WaitForChild("Config"):WaitForChild("Islands"))

local Theme = require(script.Parent.Parent.Theme)

export type HudActions = {
	OnTogglePanel: (panelKey: string) -> (),
	OnCastOrCancel: () -> (),
	OnToggleAutoFish: () -> (),
	OnToggleAutoTrain: () -> (),
	OnSellAllQuick: () -> (),
	OnManualGymTap: () -> (),
}

local HudPanel = {}

local goldLbl: TextLabel? = nil
local gemsLbl: TextLabel? = nil
local strengthLbl: TextLabel? = nil
local rodHintLbl: TextLabel? = nil
local islandBannerLbl: TextLabel? = nil
local eventBannerLbl: TextLabel? = nil
local bagBtnRef: TextButton? = nil
local castBtnRef: TextButton? = nil
local autoFishBtnRef: TextButton? = nil
local autoTrainBtnRef: TextButton? = nil
local gymWorkoutBanner: TextButton? = nil

local curStrength = 0
local curRodId = "Twig"
local canAutoTrainPerk = false
local hasAutoFishPerk = false
local autoFishOn = false
local autoTrainOn = false

local function createCurrencyPill(parent: Instance, title: string, accent: Color3, order: number): TextLabel
	local pill = Instance.new("Frame")
	pill.Name = "Pill_" .. title
	pill.Size = UDim2.fromOffset(172, 42)
	pill.BackgroundColor3 = Theme.Colors.PanelBg
	pill.LayoutOrder = order
	pill.Parent = parent
	Theme.AddCorner(pill, 12)
	Theme.AddStroke(pill, accent, 2.2)

	local val = Instance.new("TextLabel")
	val.Name = "Value"
	val.Size = UDim2.new(1, -16, 1, 0)
	val.Position = UDim2.fromOffset(8, 0)
	val.BackgroundTransparency = 1
	val.Font = Theme.FontTitle
	val.TextSize = 18
	val.TextColor3 = accent
	val.Text = "0 " .. title
	val.Parent = pill
	Theme.AddTextStroke(val, 1.8)
	return val
end

local function refreshRodProgressHint()
	if not rodHintLbl then
		return
	end
	local curRod = RodsConfig.Get(curRodId)
	local nextRod = RodsConfig.GetNextRod(curRodId)
	local baseline = math.max(curRod.strengthReq, 300)
	local mastery = math.clamp(math.log10(1 + curStrength / baseline) / 2.0, 0, 1)
	local biteBonusPct = math.floor(mastery * GameConfig.STRENGTH_MAX_SPEED_BONUS * 100 + 0.5)
	local barBonusPct = math.floor(mastery * GameConfig.STRENGTH_MAX_BAR_BONUS * 100 + 0.5)

	if nextRod then
		rodHintLbl.Text = string.format(
			"Rod: %s • Next: %s (%s / %s Str) • Str Bonus: +%d%% Speed, +%d%% Bar",
			curRod.name,
			nextRod.name,
			Util.FormatNumber(curStrength),
			Util.FormatNumber(nextRod.strengthReq),
			biteBonusPct,
			barBonusPct
		)
	else
		rodHintLbl.Text = string.format(
			"MAX ROD: %s • Strength Bonus: +%d%% Speed, +%d%% Catch Bar",
			curRod.name,
			biteBonusPct,
			barBonusPct
		)
	end
end

local function refreshAutoButtons()
	if autoFishBtnRef then
		if autoFishOn then
			autoFishBtnRef.Text = "🤖 AUTO-FISH: ON"
			autoFishBtnRef.BackgroundColor3 = Theme.Colors.Success
		elseif hasAutoFishPerk then
			autoFishBtnRef.Text = "🤖 AUTO-FISH: OFF"
			autoFishBtnRef.BackgroundColor3 = Theme.Colors.CardBg
		else
			autoFishBtnRef.Text = "🔒 AUTO-FISH (PASS)"
			autoFishBtnRef.BackgroundColor3 = Color3.fromRGB(78, 64, 118)
		end
	end
	if autoTrainBtnRef then
		if autoTrainOn then
			autoTrainBtnRef.Text = "🏋️ AUTO-TRAIN: ON"
			autoTrainBtnRef.BackgroundColor3 = Theme.Colors.Success
		elseif canAutoTrainPerk then
			autoTrainBtnRef.Text = "🏋️ AUTO-TRAIN: OFF"
			autoTrainBtnRef.BackgroundColor3 = Theme.Colors.CardBg
		else
			autoTrainBtnRef.Text = "🔒 AUTO-TRAIN (GROUP)"
			autoTrainBtnRef.BackgroundColor3 = Color3.fromRGB(64, 82, 112)
		end
	end
end

function HudPanel.Mount(rootGui: ScreenGui, actions: HudActions)
	-- 1. Top Currency Bar
	local topBar = Instance.new("Frame")
	topBar.Name = "TopCurrencyBar"
	topBar.AnchorPoint = Vector2.new(0.5, 0)
	topBar.Position = UDim2.new(0.5, 0, 0, 8)
	topBar.Size = UDim2.fromOffset(560, 44)
	topBar.BackgroundTransparency = 1
	topBar.Parent = rootGui

	local topLayout = Instance.new("UIListLayout")
	topLayout.FillDirection = Enum.FillDirection.Horizontal
	topLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	topLayout.Padding = UDim.new(0, 10)
	topLayout.SortOrder = Enum.SortOrder.LayoutOrder
	topLayout.Parent = topBar

	goldLbl = createCurrencyPill(topBar, "Gold", Theme.Colors.Gold, 1)
	strengthLbl = createCurrencyPill(topBar, "Str", Theme.Colors.Strength, 2)
	gemsLbl = createCurrencyPill(topBar, "Gems", Theme.Colors.Gems, 3)

	-- 2. Sub-header: Island Name + Rod/Strength Bonus Hint + Active Event
	local subHint = Instance.new("TextLabel")
	subHint.Name = "RodStrengthHint"
	subHint.AnchorPoint = Vector2.new(0.5, 0)
	subHint.Position = UDim2.new(0.5, 0, 0, 54)
	subHint.Size = UDim2.fromOffset(680, 20)
	subHint.BackgroundTransparency = 1
	subHint.Font = Theme.FontBody
	subHint.TextSize = 13
	subHint.TextColor3 = Theme.Colors.TextMuted
	subHint.Text = ""
	subHint.Parent = rootGui
	Theme.AddTextStroke(subHint, 1.5)
	rodHintLbl = subHint

	local islTag = Instance.new("TextLabel")
	islTag.Name = "IslandTag"
	islTag.Position = UDim2.fromOffset(16, 12)
	islTag.Size = UDim2.fromOffset(220, 28)
	islTag.BackgroundTransparency = 1
	islTag.Font = Theme.FontTitle
	islTag.TextSize = 18
	islTag.TextXAlignment = Enum.TextXAlignment.Left
	islTag.TextColor3 = Color3.fromRGB(116, 238, 255)
	islTag.Text = "🏝️ Sunny Shores"
	islTag.Parent = rootGui
	Theme.AddTextStroke(islTag, 1.8)
	islandBannerLbl = islTag

	local evLbl = Instance.new("TextLabel")
	evLbl.Name = "EventBanner"
	evLbl.Position = UDim2.fromOffset(16, 40)
	evLbl.Size = UDim2.fromOffset(260, 22)
	evLbl.BackgroundTransparency = 1
	evLbl.Font = Theme.FontBody
	evLbl.TextSize = 13
	evLbl.TextXAlignment = Enum.TextXAlignment.Left
	evLbl.TextColor3 = Theme.Colors.Gold
	evLbl.Text = ""
	evLbl.Parent = rootGui
	Theme.AddTextStroke(evLbl, 1.5)
	eventBannerLbl = evLbl

	-- 3. Left Menu Dock
	local leftDock = Instance.new("Frame")
	leftDock.Name = "LeftMenuDock"
	leftDock.AnchorPoint = Vector2.new(0, 0.5)
	leftDock.Position = UDim2.new(0, 14, 0.52, 0)
	leftDock.Size = UDim2.fromOffset(132, 276)
	leftDock.BackgroundTransparency = 1
	leftDock.Parent = rootGui

	local leftLayout = Instance.new("UIListLayout")
	leftLayout.Padding = UDim.new(0, 8)
	leftLayout.SortOrder = Enum.SortOrder.LayoutOrder
	leftLayout.Parent = leftDock

	local bagBtn = Theme.CreateButton(leftDock, "BtnBag", "🎒 Bag (0/60)", UDim2.new(1, 0, 0, 44), UDim2.new(), Theme.Colors.Primary, function()
		actions.OnTogglePanel("Bag")
	end)
	bagBtn.TextSize = 15
	bagBtnRef = bagBtn

	local shopBtn = Theme.CreateButton(leftDock, "BtnShop", "🛒 Shop", UDim2.new(1, 0, 0, 44), UDim2.new(), Theme.Colors.Warning, function()
		actions.OnTogglePanel("Shop")
	end)
	shopBtn.TextSize = 16

	local petsBtn = Theme.CreateButton(leftDock, "BtnPets", "🐾 Pets", UDim2.new(1, 0, 0, 44), UDim2.new(), Color3.fromRGB(186, 92, 255), function()
		actions.OnTogglePanel("Pets")
	end)
	petsBtn.TextSize = 16

	local islBtn = Theme.CreateButton(leftDock, "BtnIslands", "🗺️ Islands", UDim2.new(1, 0, 0, 44), UDim2.new(), Color3.fromRGB(48, 188, 176), function()
		actions.OnTogglePanel("Islands")
	end)
	islBtn.TextSize = 16

	local progBtn = Theme.CreateButton(leftDock, "BtnProgress", "🏆 Progress", UDim2.new(1, 0, 0, 44), UDim2.new(), Color3.fromRGB(238, 118, 72), function()
		actions.OnTogglePanel("Progress")
	end)
	progBtn.TextSize = 16

	-- 4. Gym Active Banner (chi hien khi dung tren may Gym)
	local gymBanner = Theme.CreateButton(
		rootGui,
		"GymActiveBanner",
		"🏋️ GYM — CLICK TO LIFT!",
		UDim2.fromOffset(390, 44),
		UDim2.new(0.5, -195, 1, -124),
		Theme.Colors.Strength,
		actions.OnManualGymTap
	)
	gymBanner.Visible = false
	gymWorkoutBanner = gymBanner

	-- 5. Bottom Action Bar
	local bottomBar = Instance.new("Frame")
	bottomBar.Name = "BottomActionBar"
	bottomBar.AnchorPoint = Vector2.new(0.5, 1)
	bottomBar.Position = UDim2.new(0.5, 0, 1, -14)
	bottomBar.Size = UDim2.fromOffset(690, 52)
	bottomBar.BackgroundTransparency = 1
	bottomBar.Parent = rootGui

	local botLayout = Instance.new("UIListLayout")
	botLayout.FillDirection = Enum.FillDirection.Horizontal
	botLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	botLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	botLayout.Padding = UDim.new(0, 10)
	botLayout.Parent = bottomBar

	castBtnRef = Theme.CreateButton(bottomBar, "CastButton", "🎣 CAST ROD", UDim2.fromOffset(186, 50), UDim2.new(), Theme.Colors.Primary, actions.OnCastOrCancel)
	local afBtn = Theme.CreateButton(bottomBar, "AutoFishBtn", "🤖 AUTO-FISH: OFF", UDim2.fromOffset(172, 46), UDim2.new(), Theme.Colors.CardBg, actions.OnToggleAutoFish)
	afBtn.TextSize = 14
	autoFishBtnRef = afBtn
	local atBtn = Theme.CreateButton(bottomBar, "AutoTrainBtn", "🏋️ AUTO-TRAIN: OFF", UDim2.fromOffset(178, 46), UDim2.new(), Theme.Colors.CardBg, actions.OnToggleAutoTrain)
	atBtn.TextSize = 14
	autoTrainBtnRef = atBtn

	local sellQuick = Theme.CreateButton(bottomBar, "SellQuickBtn", "💰 SELL ALL", UDim2.fromOffset(124, 46), UDim2.new(), Theme.Colors.Gold, actions.OnSellAllQuick)
	sellQuick.TextSize = 15

	refreshRodProgressHint()
	refreshAutoButtons()
end

function HudPanel.UpdateCurrencies(gold: number, gems: number, strength: number)
	curStrength = strength
	if goldLbl then
		goldLbl.Text = "🪙 " .. Util.FormatNumber(gold)
	end
	if strengthLbl then
		strengthLbl.Text = "💪 " .. Util.FormatNumber(strength)
	end
	if gemsLbl then
		gemsLbl.Text = "💎 " .. Util.FormatNumber(gems)
	end
	refreshRodProgressHint()
end

function HudPanel.UpdateRodAndIsland(rodId: string, islandId: number)
	curRodId = rodId
	if islandBannerLbl then
		local isl = IslandsRegistry.Get(islandId)
		islandBannerLbl.Text = string.format("🏝️ Island %d: %s", isl.id, isl.name)
	end
	refreshRodProgressHint()
end

function HudPanel.UpdateBagCount(count: number)
	if bagBtnRef then
		bagBtnRef.Text = string.format("🎒 Bag (%d/%d)", count, GameConfig.BAG_CAPACITY)
	end
end

function HudPanel.UpdatePerks(canTrain: boolean, canFish: boolean)
	canAutoTrainPerk = canTrain
	hasAutoFishPerk = canFish
	refreshAutoButtons()
end

function HudPanel.UpdateFishingState(isCasting: boolean, isAutoFish: boolean)
	autoFishOn = isAutoFish
	if castBtnRef then
		castBtnRef.Text = if isCasting then "✖ CANCEL CAST" else "🎣 CAST ROD"
		castBtnRef.BackgroundColor3 = if isCasting then Theme.Colors.Danger else Theme.Colors.Primary
	end
	refreshAutoButtons()
end

function HudPanel.UpdateGymState(stationName: string?, isAutoTrain: boolean)
	autoTrainOn = isAutoTrain
	if gymWorkoutBanner then
		if stationName then
			gymWorkoutBanner.Text = string.format("🏋️ %s — TAP / CLICK TO LIFT!", string.upper(stationName))
			gymWorkoutBanner.Visible = true
		else
			gymWorkoutBanner.Visible = false
		end
	end
	refreshAutoButtons()
end

function HudPanel.UpdateEventBanner(text: string)
	if eventBannerLbl then
		eventBannerLbl.Text = text
	end
end

return HudPanel
