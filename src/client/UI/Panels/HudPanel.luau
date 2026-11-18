--!strict
-- HudPanel.luau: Thanh Tien Te, Chi so 5-Stat Can Cau + Effective Luck, Menu Trai & uy quyen Hotbar/Bait/Auto

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Util = require(Shared:WaitForChild("Util"))
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local RodsConfig = require(Shared:WaitForChild("Config"):WaitForChild("RodsConfig"))
local EnchantsConfig = require(Shared:WaitForChild("Config"):WaitForChild("EnchantsConfig"))
local IslandsRegistry = require(Shared:WaitForChild("Config"):WaitForChild("Islands"))

local Theme = require(script.Parent.Parent.Theme)
local HotbarAndBaitUi = require(script.Parent.Parent.Components.HotbarAndBaitUi)

export type HudActions = {
	OnTogglePanel: (panelKey: string) -> (),
	OnCancelCast: () -> (),
	OnToggleAutoFish: () -> (),
	OnToggleAutoTrain: () -> (),
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
local gymWorkoutBanner: TextButton? = nil

local curStrength = 0
local curRodId = "Twig"
local ownedRodsCache: { [string]: boolean } = { Twig = true }
local rodEnchantsCache: { [string]: string } = {}
local canAutoTrainPerk = false
local hasAutoFishPerk = false
local isCastingState = false
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
	local eff = RodsConfig.GetEffectiveStats(curRodId, ownedRodsCache, rodEnchantsCache)
	local ench = if eff.enchantId then EnchantsConfig.ById[eff.enchantId] else nil
	local baseline = math.max(eff.masteryBaselineStrength, 300)
	local mastery = math.clamp(math.log10(1 + curStrength / baseline) / 2.0, 0, 1)
	local barWidthPct = math.floor(math.clamp(0.28 + eff.controlBonus + (if ench then ench.controlBonus else 0) + mastery * GameConfig.STRENGTH_MAX_BAR_BONUS, 0.20, GameConfig.MINIGAME_MAX_WIDTH) * 100 + 0.5)
	local totalLuckPct = math.floor((eff.luckBonus + (if ench then ench.luckBonus else 0) + (if autoFishOn and hasAutoFishPerk then GameConfig.PERFECT_CAST_LUCK_ADD else 0)) * 100 + 0.5)
	local enchTag = if ench then (" • 🔮 " .. ench.name) else ""

	rodHintLbl.Text = string.format(
		"🎣 %s (%s Max) • +%d%% Luck • Bar %d%%%s  |  Hold Click on Water to Cast!",
		eff.name,
		Util.FormatWeight(eff.maxWeight),
		totalLuckPct,
		barWidthPct,
		enchTag
	)
end

local function syncHotbarStateFlags()
	HotbarAndBaitUi.SyncStates(isCastingState, autoFishOn, autoTrainOn, canAutoTrainPerk, hasAutoFishPerk)
	refreshRodProgressHint()
end

function HudPanel.Mount(rootGui: ScreenGui, actions: HudActions)
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

	local subHint = Instance.new("TextLabel")
	subHint.Name = "RodStrengthHint"
	subHint.AnchorPoint = Vector2.new(0.5, 0)
	subHint.Position = UDim2.new(0.5, 0, 0, 54)
	subHint.Size = UDim2.fromOffset(760, 20)
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
	islTag.Size = UDim2.fromOffset(240, 28)
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
	evLbl.Size = UDim2.fromOffset(290, 22)
	evLbl.BackgroundTransparency = 1
	evLbl.Font = Theme.FontBody
	evLbl.TextSize = 13
	evLbl.TextXAlignment = Enum.TextXAlignment.Left
	evLbl.TextColor3 = Theme.Colors.Gold
	evLbl.Text = ""
	evLbl.Parent = rootGui
	Theme.AddTextStroke(evLbl, 1.5)
	eventBannerLbl = evLbl

	local leftDock = Instance.new("Frame")
	leftDock.Name = "LeftMenuDock"
	leftDock.AnchorPoint = Vector2.new(0, 0.5)
	leftDock.Position = UDim2.new(0, 14, 0.50, 0)
	leftDock.Size = UDim2.fromOffset(136, 368)
	leftDock.BackgroundTransparency = 1
	leftDock.Parent = rootGui

	local leftLayout = Instance.new("UIListLayout")
	leftLayout.Padding = UDim.new(0, 7)
	leftLayout.SortOrder = Enum.SortOrder.LayoutOrder
	leftLayout.Parent = leftDock

	local bagBtn = Theme.CreateButton(leftDock, "BtnBag", "🎒 Bag (0/60)", UDim2.new(1, 0, 0, 42), UDim2.new(), Theme.Colors.Primary, function() actions.OnTogglePanel("Bag") end)
	bagBtn.TextSize = 14
	bagBtnRef = bagBtn

	local shopBtn = Theme.CreateButton(leftDock, "BtnShop", "🛒 Shop", UDim2.new(1, 0, 0, 42), UDim2.new(), Theme.Colors.Warning, function() actions.OnTogglePanel("Shop") end)
	shopBtn.TextSize = 15

	local enchBtn = Theme.CreateButton(leftDock, "BtnAltar", "🔮 Enchants", UDim2.new(1, 0, 0, 42), UDim2.new(), Color3.fromRGB(118, 212, 255), function() actions.OnTogglePanel("Enchant") end)
	enchBtn.TextSize = 15

	local petsBtn = Theme.CreateButton(leftDock, "BtnPets", "🐾 Pets", UDim2.new(1, 0, 0, 42), UDim2.new(), Color3.fromRGB(186, 92, 255), function() actions.OnTogglePanel("Pets") end)
	petsBtn.TextSize = 15

	local islBtn = Theme.CreateButton(leftDock, "BtnIslands", "🗺️ Islands", UDim2.new(1, 0, 0, 42), UDim2.new(), Color3.fromRGB(48, 188, 176), function() actions.OnTogglePanel("Islands") end)
	islBtn.TextSize = 15

	local progBtn = Theme.CreateButton(leftDock, "BtnProgress", "🏆 Progress", UDim2.new(1, 0, 0, 42), UDim2.new(), Color3.fromRGB(238, 118, 72), function() actions.OnTogglePanel("Progress") end)
	progBtn.TextSize = 15

	local giftBtn = Theme.CreateButton(leftDock, "BtnGifts", "🎁 Gifts & ⚙️", UDim2.new(1, 0, 0, 42), UDim2.new(), Color3.fromRGB(82, 198, 128), function() actions.OnTogglePanel("Gifts") end)
	giftBtn.TextSize = 14

	local gymBanner = Theme.CreateButton(rootGui, "GymActiveBanner", "🏋️ GYM — CLICK TO LIFT!", UDim2.fromOffset(380, 40), UDim2.new(0.5, -190, 1, -168), Theme.Colors.Strength, actions.OnManualGymTap)
	gymBanner.Visible = false
	gymWorkoutBanner = gymBanner

	HotbarAndBaitUi.Mount(rootGui, {
		OnToggleAutoFish = actions.OnToggleAutoFish,
		OnToggleAutoTrain = actions.OnToggleAutoTrain,
		OnCancelCast = actions.OnCancelCast,
	})
	refreshRodProgressHint()
end

function HudPanel.UpdateCurrencies(gold: number, gems: number, strength: number)
	curStrength = strength
	if goldLbl then goldLbl.Text = "🪙 " .. Util.FormatNumber(gold) end
	if strengthLbl then strengthLbl.Text = "💪 " .. Util.FormatNumber(strength) end
	if gemsLbl then gemsLbl.Text = "💎 " .. Util.FormatNumber(gems) end
	refreshRodProgressHint()
end

function HudPanel.UpdateRodAndIsland(rodId: string, islandId: number, ownedRods: { [string]: boolean }?, rodEnchants: { [string]: string }?)
	curRodId = rodId
	if ownedRods then ownedRodsCache = ownedRods end
	if rodEnchants then rodEnchantsCache = rodEnchants end
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

function HudPanel.UpdatePerks(canTrain: boolean, canFishPro: boolean)
	canAutoTrainPerk = canTrain
	hasAutoFishPerk = canFishPro
	syncHotbarStateFlags()
end

function HudPanel.UpdateFishingState(isCasting: boolean, isAutoFish: boolean)
	isCastingState = isCasting
	autoFishOn = isAutoFish
	syncHotbarStateFlags()
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
	syncHotbarStateFlags()
end

function HudPanel.UpdateEventBanner(text: string)
	if eventBannerLbl then
		eventBannerLbl.Text = text
	end
end

return HudPanel
