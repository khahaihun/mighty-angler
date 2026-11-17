--!strict
-- init.client.luau: Khoi dong Client UI responsive, ket noi Controllers & dong bo State tu Server

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))

local FishingController = require(script.Controllers.FishingController)
local GymController = require(script.Controllers.GymController)
local SoundAndFxController = require(script.Controllers.SoundAndFxController)
local PromptController = require(script.Controllers.PromptController)
local StudioErrorReporter = require(script.Controllers.StudioErrorReporter)

local WindowFrame = require(script.UI.Components.WindowFrame)
local HudPanel = require(script.UI.Panels.HudPanel)
local BagPanel = require(script.UI.Panels.BagPanel)
local ShopPanel = require(script.UI.Panels.ShopPanel)
local DevTestPanel = require(script.UI.Panels.DevTestPanel)

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local rootGui = Instance.new("ScreenGui")
rootGui.Name = "MightyAnglerHud"
rootGui.ResetOnSpawn = false
rootGui.IgnoreGuiInset = false
rootGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
rootGui.Parent = playerGui

-- Tu dong co gian UIScale cho man hinh nho / dien thoai (720p & Mobile safe)
local uiScale = Instance.new("UIScale")
uiScale.Parent = rootGui

local function updateResponsiveScale()
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	local vp = cam.ViewportSize
	local scaleByWidth = vp.X / 1180
	local scaleByHeight = vp.Y / 680
	uiScale.Scale = math.clamp(math.min(scaleByWidth, scaleByHeight), 0.62, 1.08)
end

if Workspace.CurrentCamera then
	updateResponsiveScale()
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsiveScale)
end

StudioErrorReporter.Mount(rootGui)
SoundAndFxController.Init(rootGui)

-- Cac cua so Modal (Pets / Islands / Progress se tu dong nap khi module co san o Chang 2 & 3)
local windows: { [string]: WindowFrame.BuiltWindow } = {}
windows["Bag"] = BagPanel.Mount(rootGui)
windows["Shop"] = ShopPanel.Mount(rootGui)

local petsModRef: any = nil
local progressModRef: any = nil

local panelsFolder = script.UI:FindFirstChild("Panels")
if panelsFolder then
	local pMod = panelsFolder:FindFirstChild("PetsPanel")
	if pMod and pMod:IsA("ModuleScript") then
		petsModRef = require(pMod) :: any
		windows["Pets"] = petsModRef.Mount(rootGui)
	end
	local prMod = panelsFolder:FindFirstChild("ProgressPanel")
	if prMod and prMod:IsA("ModuleScript") then
		progressModRef = require(prMod) :: any
		windows["Progress"] = progressModRef.Mount(rootGui)
		windows["Islands"] = progressModRef.GetIslandsWindow(rootGui)
	end
end

local function toggleExclusivePanel(key: string)
	SoundAndFxController.PlaySfx("Click")
	local target = windows[key]
	if not target then
		SoundAndFxController.ShowToast("Info", key .. " unlocks in the next Milestone!")
		return
	end
	local nextVisible = not target.IsVisible()
	for k, w in pairs(windows) do
		w.SetVisible(k == key and nextVisible)
	end
	if nextVisible then
		if key == "Bag" then
			BagPanel.Render()
		elseif key == "Shop" then
			ShopPanel.Render()
		elseif key == "Pets" and petsModRef then
			petsModRef.Render()
		elseif (key == "Progress" or key == "Islands") and progressModRef then
			progressModRef.Render()
		end
	end
end

-- State cache tren Client
local goldCache = 0
local gemsCache = 0
local strengthCache = 0
local rodIdCache = "Twig"
local islandCache = 1
local ownedRodsCache: { [string]: boolean } = { Twig = true }
local gearLvCache = 0

HudPanel.Mount(rootGui, {
	OnTogglePanel = toggleExclusivePanel,
	OnCastOrCancel = function()
		SoundAndFxController.PlaySfx("Cast")
		FishingController.RequestCastOrCancel()
	end,
	OnToggleAutoFish = function()
		SoundAndFxController.PlaySfx("Click")
		FishingController.ToggleAutoFish()
	end,
	OnToggleAutoTrain = function()
		SoundAndFxController.PlaySfx("Click")
		GymController.ToggleAutoTrain()
	end,
	OnSellAllQuick = function()
		SoundAndFxController.PlaySfx("Click")
		Net.FireServer(Net.ClientToServer.SellAllFish)
	end,
	OnManualGymTap = function()
		GymController.TriggerManualRep()
	end,
})

DevTestPanel.Mount(rootGui)
FishingController.Init(rootGui)
GymController.Init()

PromptController.Init({
	OpenPanel = toggleExclusivePanel,
	TriggerGymRep = function()
		GymController.TriggerManualRep()
	end,
})

FishingController.OnStateChanged(function(isCasting: boolean, isAutoFish: boolean)
	HudPanel.UpdateFishingState(isCasting, isAutoFish)
end)

FishingController.OnCatchResult(function(payload: any)
	if type(payload) ~= "table" or payload.success ~= true then
		return
	end
	local rarity = tostring(payload.rarity or "Common")
	if rarity == "Rare" or rarity == "Epic" or rarity == "Legendary" or rarity == "Boss" then
		SoundAndFxController.PlaySfx("CatchRare")
		SoundAndFxController.PunchCamera(2.0)
	else
		SoundAndFxController.PlaySfx("CatchCommon")
	end
	local mut = tostring(payload.mutation or "None")
	local prefix = if mut ~= "None" then ("[" .. mut .. "] ") else ""
	SoundAndFxController.SpawnFloatingGain(
		"Gold",
		0,
		string.format("🐟 %s%s (%s)", prefix, tostring(payload.fishName), Util.FormatWeight(tonumber(payload.weight) or 1))
	)
end)

GymController.OnStateChanged(function(stName: string?, isAutoTrain: boolean)
	HudPanel.UpdateGymState(stName, isAutoTrain)
end)

GymController.OnRepFeedback(function(gained: number, _stName: string)
	SoundAndFxController.PlaySfx("GymRep")
	SoundAndFxController.SpawnFloatingGain("Strength", gained, nil)
end)

-- Lang nghe dong bo du lieu tu Server
local function applyFullSnapshot(snap: any)
	if type(snap) ~= "table" or type(snap.profile) ~= "table" then
		return
	end
	local p = snap.profile
	goldCache = tonumber(p.gold) or 0
	gemsCache = tonumber(p.gems) or 0
	strengthCache = tonumber(p.strength) or 0
	rodIdCache = tostring(p.rodId or "Twig")
	islandCache = tonumber(p.currentIsland) or 1
	ownedRodsCache = if type(p.ownedRods) == "table" then p.ownedRods else { Twig = true }
	gearLvCache = tonumber(p.gymGearLevel) or 0

	HudPanel.UpdateCurrencies(goldCache, gemsCache, strengthCache)
	HudPanel.UpdateRodAndIsland(rodIdCache, islandCache)
	GymController.SetCurrentIsland(islandCache)

	local bagList = if type(p.fishBag) == "table" then p.fishBag else {}
	HudPanel.UpdateBagCount(#bagList)
	BagPanel.UpdateFishBag(bagList)
	BagPanel.UpdateItems(p.potions or {}, p.bait or {}, p.activeBait)
	ShopPanel.SyncState(goldCache, strengthCache, rodIdCache, ownedRodsCache, gearLvCache)

	if petsModRef then
		petsModRef.SyncFromProfile(p)
	end
	if progressModRef then
		progressModRef.SyncFromProfile(p)
	end
end

Net.OnClientEvent(Net.ServerToClient.StateSnapshot, applyFullSnapshot)

Net.OnClientEvent(Net.ServerToClient.CurrencyUpdated, function(payload: any)
	if type(payload) ~= "table" then
		return
	end
	goldCache = tonumber(payload.gold) or goldCache
	gemsCache = tonumber(payload.gems) or gemsCache
	strengthCache = tonumber(payload.strength) or strengthCache
	HudPanel.UpdateCurrencies(goldCache, gemsCache, strengthCache)
	ShopPanel.SyncState(goldCache, strengthCache, rodIdCache, ownedRodsCache, gearLvCache)
	if progressModRef then
		progressModRef.SyncCurrencies(goldCache, gemsCache, strengthCache, tonumber(payload.rebirths) or 0)
	end
end)

Net.OnClientEvent(Net.ServerToClient.BagUpdated, function(payload: any)
	if type(payload) == "table" and type(payload.fishBag) == "table" then
		HudPanel.UpdateBagCount(#payload.fishBag)
		BagPanel.UpdateFishBag(payload.fishBag)
	end
end)

Net.OnClientEvent(Net.ServerToClient.InventoryUpdated, function(payload: any)
	if type(payload) ~= "table" then
		return
	end
	rodIdCache = tostring(payload.rodId or rodIdCache)
	ownedRodsCache = if type(payload.ownedRods) == "table" then payload.ownedRods else ownedRodsCache
	gearLvCache = tonumber(payload.gymGearLevel) or gearLvCache
	HudPanel.UpdateRodAndIsland(rodIdCache, islandCache)
	BagPanel.UpdateItems(payload.potions or {}, payload.bait or {}, payload.activeBait)
	ShopPanel.SyncState(goldCache, strengthCache, rodIdCache, ownedRodsCache, gearLvCache)
end)

Net.OnClientEvent(Net.ServerToClient.PerksUpdated, function(payload: any)
	if type(payload) ~= "table" then
		return
	end
	local canTrain = payload.canAutoTrain == true
	local canFish = payload.autoFish == true
	GymController.SetAutoTrainPerkAvailable(canTrain)
	FishingController.SetAutoFishPerkAvailable(canFish)
	HudPanel.UpdatePerks(canTrain, canFish)
	ShopPanel.SyncPasses(payload)
end)

Net.OnClientEvent(Net.ServerToClient.IslandChanged, function(payload: any)
	if type(payload) == "table" then
		islandCache = tonumber(payload.islandId) or islandCache
		HudPanel.UpdateRodAndIsland(rodIdCache, islandCache)
		GymController.SetCurrentIsland(islandCache)
		if progressModRef and type(payload.unlockedIslands) == "table" then
			progressModRef.SyncIslands(islandCache, payload.unlockedIslands)
		end
	end
end)

Net.OnClientEvent(Net.ServerToClient.ServerEventChanged, function(payload: any)
	if type(payload) == "table" then
		HudPanel.UpdateEventBanner(tostring(payload.bannerText or ""))
	end
end)

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.B then
		toggleExclusivePanel("Bag")
	elseif input.KeyCode == Enum.KeyCode.G then
		toggleExclusivePanel("Shop")
	elseif input.KeyCode == Enum.KeyCode.P then
		toggleExclusivePanel("Pets")
	elseif input.KeyCode == Enum.KeyCode.M then
		toggleExclusivePanel("Islands")
	elseif input.KeyCode == Enum.KeyCode.J then
		toggleExclusivePanel("Progress")
	end
end)

-- Gui yeu cau lay State lan dau ngay khi UI san sang
Net.FireServer(Net.ClientToServer.RequestInitialState)
