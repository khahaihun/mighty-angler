--!strict
-- init.client.luau: Khoi dong Client UI responsive, ket noi Controllers, Hotbar/Raycast Cast & dong bo State tu Server

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))

local FishingController = require(script.Controllers.FishingController)
local HotbarAndCastController = require(script.Controllers.HotbarAndCastController)
local GymController = require(script.Controllers.GymController)
local SoundAndFxController = require(script.Controllers.SoundAndFxController)
local PromptController = require(script.Controllers.PromptController)
local StudioErrorReporter = require(script.Controllers.StudioErrorReporter)
local ClientStateController = require(script.Controllers.ClientStateController)
local ClientPetRenderer = require(script.Controllers.ClientPetRenderer)
local EggHatchCutscene = require(script.Controllers.EggHatchCutscene)
local TutorialController = require(script.Controllers.TutorialController)

local WindowFrame = require(script.UI.Components.WindowFrame)
local NpcDialogueModal = require(script.UI.Components.NpcDialogueModal)
local HudPanel = require(script.UI.Panels.HudPanel)
local BagPanel = require(script.UI.Panels.BagPanel)
local ShopPanel = require(script.UI.Panels.ShopPanel)
local PetsPanel = require(script.UI.Panels.PetsPanel)
local ProgressPanel = require(script.UI.Panels.ProgressPanel)
local EnchantAndBountyModal = require(script.UI.Panels.EnchantAndBountyModal)
local PlaytimeAndSettingsModal = require(script.UI.Panels.PlaytimeAndSettingsModal)
local DevTestPanel = require(script.UI.Panels.DevTestPanel)

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local rootGui = Instance.new("ScreenGui")
rootGui.Name = "MightyAnglerHud"
rootGui.ResetOnSpawn = false
rootGui.IgnoreGuiInset = false
rootGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
rootGui.Parent = playerGui

local uiScale = Instance.new("UIScale")
uiScale.Parent = rootGui

local function updateResponsiveScale()
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	local vp = cam.ViewportSize
	uiScale.Scale = math.clamp(math.min(vp.X / 1180, vp.Y / 680), 0.62, 1.08)
end

if Workspace.CurrentCamera then
	updateResponsiveScale()
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsiveScale)
end

StudioErrorReporter.Mount(rootGui)
SoundAndFxController.Init(rootGui)

local windows: { [string]: WindowFrame.BuiltWindow } = {}
windows["Bag"] = BagPanel.Mount(rootGui)
windows["Shop"] = ShopPanel.Mount(rootGui)
windows["Pets"] = PetsPanel.Mount(rootGui)
windows["Progress"] = ProgressPanel.Mount(rootGui)
windows["Islands"] = ProgressPanel.GetIslandsWindow(rootGui)
windows["Enchant"] = EnchantAndBountyModal.Mount(rootGui)
windows["Gifts"] = PlaytimeAndSettingsModal.Mount(rootGui)

local progressModRef: any = ProgressPanel

local function isAnyModalOrWindowOpen(): boolean
	if NpcDialogueModal.IsOpen() then
		return true
	end
	for _, w in pairs(windows) do
		if w.IsVisible() then
			return true
		end
	end
	return false
end

local function openSpecificWindow(key: string)
	NpcDialogueModal.Close()
	for k, w in pairs(windows) do
		w.SetVisible(k == key)
	end
	if key == "Bag" then
		BagPanel.Render()
	elseif key == "Shop" then
		ShopPanel.Render()
	elseif key == "Pets" then
		PetsPanel.Render()
	elseif key == "Progress" then
		ProgressPanel.Render()
	elseif key == "Islands" then
		ProgressPanel.RenderIslands()
	elseif key == "Enchant" then
		EnchantAndBountyModal.Render()
	elseif key == "Gifts" then
		PlaytimeAndSettingsModal.Render()
	end
end

local function toggleExclusivePanel(key: string)
	SoundAndFxController.PlaySfx("Click")
	local target = windows[key]
	if not target then
		return
	end
	if target.IsVisible() then
		target.SetVisible(false)
	else
		openSpecificWindow(key)
	end
end

HudPanel.Mount(rootGui, {
	OnTogglePanel = toggleExclusivePanel,
	OnCancelCast = function()
		SoundAndFxController.PlaySfx("Click")
		FishingController.CancelCurrentCast()
	end,
	OnToggleAutoFish = function()
		SoundAndFxController.PlaySfx("Click")
		FishingController.ToggleAutoFish()
	end,
	OnToggleAutoTrain = function()
		SoundAndFxController.PlaySfx("Click")
		GymController.ToggleAutoTrain()
	end,
	OnManualGymTap = function()
		GymController.TriggerManualRep()
	end,
})

DevTestPanel.Mount(rootGui)
FishingController.Init(rootGui)
GymController.Init()
HotbarAndCastController.Init(isAnyModalOrWindowOpen)
ClientPetRenderer.Init()
EggHatchCutscene.Init(rootGui)
ClientStateController.Init(progressModRef)
TutorialController.Init(rootGui)

NpcDialogueModal.Mount(rootGui, {
	OpenPanel = openSpecificWindow,
	OpenBagSelectMode = function()
		local bagAny: any = BagPanel
		if bagAny.EnableMultiSelectMode then
			bagAny.EnableMultiSelectMode()
		end
		openSpecificWindow("Bag")
	end,
	OpenEnchantOrBounty = function(tabName: string)
		openSpecificWindow("Enchant")
		if tabName == "Bounties" then
			EnchantAndBountyModal.OpenTab("Bounties")
		else
			EnchantAndBountyModal.OpenTab("Enchants")
		end
	end,
	SellHeldFish = function()
		Net.FireServer(Net.ClientToServer.SellHeldFish)
	end,
	AppraiseHeldFish = function()
		Net.FireServer(Net.ClientToServer.AppraiseFish, nil)
	end,
})

PromptController.Init({
	OpenPanel = openSpecificWindow,
	OpenNpcDialogue = function(role: string)
		SoundAndFxController.PlaySfx("Click")
		for _, w in pairs(windows) do
			w.SetVisible(false)
		end
		NpcDialogueModal.OpenForRole(role)
	end,
	OpenEnchantAltar = function()
		SoundAndFxController.PlaySfx("Click")
		openSpecificWindow("Enchant")
		EnchantAndBountyModal.OpenTab("Enchants")
	end,
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
	local sizeTier = tostring(payload.sizeTier or "Normal")
	local prefix = if mut ~= "None" then ("[" .. mut .. "] ") else ""
	local tierTxt = if sizeTier ~= "Normal" then (sizeTier .. " ") else ""
	SoundAndFxController.SpawnFloatingGain(
		"Gold",
		0,
		string.format("🐟 %s%s%s (%s)", prefix, tierTxt, tostring(payload.fishName), Util.FormatWeight(tonumber(payload.weight) or 1))
	)
end)

GymController.OnStateChanged(function(stName: string?, isAutoTrain: boolean)
	HudPanel.UpdateGymState(stName, isAutoTrain)
end)

GymController.OnRepFeedback(function(gained: number, _stName: string)
	SoundAndFxController.PlaySfx("GymRep")
	SoundAndFxController.SpawnFloatingGain("Strength", gained, nil)
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
	elseif input.KeyCode == Enum.KeyCode.K then
		toggleExclusivePanel("Enchant")
	end
end)

Net.FireServer(Net.ClientToServer.RequestInitialState)
