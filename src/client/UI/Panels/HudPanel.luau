--!strict
-- HudPanel.luau: Thanh Tien Te, Chi so 5-Stat Can Cau + Bang % Base vs Effective Live, Menu Trai & Hotbar/Bait/Auto

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Util = require(Shared:WaitForChild("Util"))
local CatchControl = require(Shared:WaitForChild("CatchControl"))
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local RodsConfig = require(Shared:WaitForChild("Config"):WaitForChild("RodsConfig"))
local EnchantsConfig = require(Shared:WaitForChild("Config"):WaitForChild("EnchantsConfig"))
local IslandsRegistry = require(Shared:WaitForChild("Config"):WaitForChild("Islands"))

local Theme = require(script.Parent.Parent.Theme)
local PurchaseOddsController = require(script.Parent.Parent.Parent.Controllers.PurchaseOddsController)
local HotbarAndBaitUi = require(script.Parent.Parent.Components.HotbarAndBaitUi)
local ProfileAccessBanner = require(script.Parent.Parent.Components.ProfileAccessBanner)

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
local liveOddsLbl: TextButton? = nil
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
	if not rodHintLbl then return end
	local eff = RodsConfig.GetEffectiveStats(curRodId, ownedRodsCache, rodEnchantsCache)
	local ench = if eff.enchantId then EnchantsConfig.ById[eff.enchantId] else nil
	local ctrlTotal = CatchControl.ComputeWidthBonus(curStrength, eff.masteryBaselineStrength, eff.controlBonus + (if ench then ench.controlBonus else 0))
	local rareBarPct = math.floor(CatchControl.ComputeWidth(false, ctrlTotal) * 100 + 0.5)
	local bossBarPct = math.floor(CatchControl.ComputeWidth(true, ctrlTotal) * 100 + 0.5)
	local rodLuckPct = math.floor((eff.luckBonus + (if ench then ench.luckBonus else 0) + (if autoFishOn and hasAutoFishPerk then GameConfig.PERFECT_CAST_LUCK_ADD else 0)) * 100 + 0.5)
	local enchTag = if ench then (" • 🔮 " .. ench.name) else ""

	rodHintLbl.Text = string.format(
		"🎣 %s (%s Max • %d%% Stdy) • +%d%% Rod/Cast Luck • Bar %d%% (Boss %d%%)%s",
		eff.name,
		Util.FormatWeight(eff.maxWeight),
		math.floor((eff.steadiness + (if ench then ench.steadinessBonus else 0)) * 100 + 0.5),
		rodLuckPct,
		rareBarPct,
		bossBarPct,
		enchTag
	)
end

local function syncHotbarStateFlags()
	HotbarAndBaitUi.SyncStates(isCastingState, autoFishOn, autoTrainOn, canAutoTrainPerk, hasAutoFishPerk)
	refreshRodProgressHint()
end

function HudPanel.Mount(rootGui: ScreenGui, actions: HudActions)
	ProfileAccessBanner.Mount(rootGui, Theme)
	local topBar = Instance.new("Frame")
	topBar.Name = "TopCurrencyBar"
	topBar.AnchorPoint = Vector2.new(0.5, 0)
	topBar.Position = UDim2.new(0.5, 0, 0, 8)
	topBar.Size = UDim2.fromOffset(560, 44)
	topBar.BackgroundTransparency = 1
	topBar.Parent = rootGui
	HotbarAndBaitUi.BindLayout(rootGui, topBar, topBar.Name)

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
	subHint.Position = UDim2.new(0.5, 0, 0, 53)
	subHint.Size = UDim2.fromOffset(780, 18)
	subHint.BackgroundTransparency = 1
	subHint.Font = Theme.FontBody
	Theme.FitText(subHint, 14, 12)
	subHint.TextColor3 = Theme.Colors.TextMuted
	subHint.Text = ""
	subHint.Parent = rootGui
	HotbarAndBaitUi.BindLayout(rootGui, subHint, subHint.Name)
	Theme.AddTextStroke(subHint, 1.5)
	rodHintLbl = subHint

	local oddsHint = Instance.new("TextButton")
	oddsHint.Name = "LiveOddsBanner"
	oddsHint.AnchorPoint = Vector2.new(0.5, 0)
	oddsHint.Position = UDim2.new(0.5, 0, 0, 71)
	oddsHint.Size = UDim2.fromOffset(820, 18)
	oddsHint.BackgroundTransparency = 1
	oddsHint.Font = Theme.FontBody
	Theme.FitText(oddsHint, 13, 11)
	oddsHint.TextColor3 = Color3.fromRGB(132, 238, 255)
	oddsHint.Text = ""
	oddsHint.Parent = rootGui
	HotbarAndBaitUi.BindLayout(rootGui, oddsHint, oddsHint.Name)
	oddsHint.Activated:Connect(PurchaseOddsController.ShowLive)
	Theme.AddTextStroke(oddsHint, 1.4)
	liveOddsLbl = oddsHint

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
	HotbarAndBaitUi.BindLayout(rootGui, islTag, islTag.Name)
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
	HotbarAndBaitUi.BindLayout(rootGui, evLbl, evLbl.Name)
	Theme.AddTextStroke(evLbl, 1.5)
	eventBannerLbl = evLbl

	local leftDock = Instance.new("Frame")
	leftDock.Name = "LeftMenuDock"
	leftDock.AnchorPoint = Vector2.new(0, 0.5)
	leftDock.Position = UDim2.new(0, 14, 0.50, 0)
	leftDock.Size = UDim2.fromOffset(136, 368)
	leftDock.BackgroundTransparency = 1
	leftDock.Parent = rootGui
	HotbarAndBaitUi.BindLayout(rootGui, leftDock, leftDock.Name)

	local leftLayout = Instance.new("UIListLayout")
	leftLayout.Padding = UDim.new(0, 7)
	leftLayout.SortOrder = Enum.SortOrder.LayoutOrder
	leftLayout.Parent = leftDock

	local bagBtn = Theme.CreateButton(leftDock, "BtnBag", "🎒 Bag (0/60)", UDim2.new(1, 0, 0, 42), UDim2.new(), Theme.Colors.Primary, function() actions.OnTogglePanel("Bag") end)
	bagBtn.TextSize = 14
	bagBtnRef = bagBtn

	local navButtons = {
		{ id = "BtnShop", label = "🛒 Shop", col = Theme.Colors.Warning, key = "Shop", sz = 15 },
		{ id = "BtnAltar", label = "🔮 Enchants", col = Color3.fromRGB(118, 212, 255), key = "Enchant", sz = 15 },
		{ id = "BtnPets", label = "🐾 Pets", col = Color3.fromRGB(186, 92, 255), key = "Pets", sz = 15 },
		{ id = "BtnIslands", label = "🗺️ Islands", col = Color3.fromRGB(48, 188, 176), key = "Islands", sz = 15 },
		{ id = "BtnProgress", label = "🏆 Progress", col = Color3.fromRGB(238, 118, 72), key = "Progress", sz = 15 },
		{ id = "BtnGifts", label = "🎁 Gifts & ⚙️", col = Color3.fromRGB(82, 198, 128), key = "Gifts", sz = 14 },
	}
	for _, nb in ipairs(navButtons) do
		local b = Theme.CreateButton(leftDock, nb.id, nb.label, UDim2.new(1, 0, 0, 42), UDim2.new(), nb.col, function() actions.OnTogglePanel(nb.key) end)
		b.TextSize = nb.sz
	end

	local gymBanner = Theme.CreateButton(rootGui, "GymActiveBanner", "🏋️ GYM — CLICK TO LIFT!", UDim2.fromOffset(380, 40), UDim2.new(0.5, -190, 1, -168), Theme.Colors.Strength, actions.OnManualGymTap)
	HotbarAndBaitUi.BindLayout(rootGui, gymBanner, "GymActiveBanner")
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
	if bagBtnRef then bagBtnRef.Text = string.format("🎒 Bag (%d/%d)", count, GameConfig.BAG_CAPACITY) end
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
		gymWorkoutBanner.Visible = (stationName ~= nil)
		if stationName then gymWorkoutBanner.Text = string.format("🏋️ %s — TAP / CLICK TO LIFT!", string.upper(stationName)) end
	end
	syncHotbarStateFlags()
end

function HudPanel.UpdateEventBanner(text: string)
	if eventBannerLbl then eventBannerLbl.Text = text end
end

function HudPanel.UpdateLiveOddsText(text: string)
	if liveOddsLbl then liveOddsLbl.Text = "[View all odds] " .. text end
end

function HudPanel.UpdateProfileAccess(readOnly: boolean, loading: boolean, version: number, retrying: boolean?, outage: boolean?)
	ProfileAccessBanner.Update(readOnly, loading, version, retrying, outage)
end

return HudPanel
