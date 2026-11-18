--!strict
-- FishingController.luau: Dieu phoi Quang Can, Auto-Fish (Free 1.10s / Pro 0.45s Perfect), Minigame Per-Strike & 1 Recast Coordinator

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))

local AnimationController = require(script.Parent.AnimationController)
local MinigameBar = require(script.Parent.Parent.UI.Panels.MinigameBar)

local FishingController = {}

local isCastingOrWaiting = false
local autoFishEnabled = false
local hasAutoFishPro = false
local recastTicket = 0

local stateListeners: { (boolean, boolean) -> () } = {}
local catchListeners: { (any) -> () } = {}

local function notifyUiState()
	for _, cb in ipairs(stateListeners) do
		task.spawn(cb, isCastingOrWaiting, autoFishEnabled)
	end
end

function FishingController.OnStateChanged(callback: (boolean, boolean) -> ())
	table.insert(stateListeners, callback)
end

function FishingController.OnCatchResult(callback: (any) -> ())
	table.insert(catchListeners, callback)
end

function FishingController.IsBusy(): boolean
	return isCastingOrWaiting or MinigameBar.IsOpen()
end

function FishingController.SetAutoFishPerkAvailable(ownsPro: boolean)
	hasAutoFishPro = ownsPro
	notifyUiState()
end

local function scheduleSingleAutoRecast()
	recastTicket += 1
	local myTicket = recastTicket
	if not autoFishEnabled then
		return
	end
	local delaySec = if hasAutoFishPro then GameConfig.AUTO_FISH_PRO_RECAST_SEC else GameConfig.AUTO_FISH_FREE_RECAST_SEC
	task.delay(delaySec, function()
		if recastTicket == myTicket and autoFishEnabled and not isCastingOrWaiting and not MinigameBar.IsOpen() then
			Net.FireServer(Net.ClientToServer.FishingCastWithAim, {
				castMode = "Auto",
				hitWater = true,
			})
		end
	end)
end

function FishingController.CancelCurrentCast()
	recastTicket += 1
	if MinigameBar.IsOpen() then
		return
	end
	if isCastingOrWaiting then
		isCastingOrWaiting = false
		AnimationController.StopFishingHold()
		Net.FireServer(Net.ClientToServer.FishingCancel)
		notifyUiState()
	end
end

function FishingController.RequestCastOrCancel()
	if isCastingOrWaiting then
		FishingController.CancelCurrentCast()
	elseif not MinigameBar.IsOpen() then
		Net.FireServer(Net.ClientToServer.FishingCastWithAim, {
			castMode = "Manual",
			holdRatio = 0.85,
			hitWater = true,
		})
	end
end

function FishingController.ToggleAutoFish()
	autoFishEnabled = not autoFishEnabled
	recastTicket += 1
	Net.FireServer(Net.ClientToServer.SetAutoFish, autoFishEnabled)
	notifyUiState()

	if autoFishEnabled and not isCastingOrWaiting and not MinigameBar.IsOpen() then
		Net.FireServer(Net.ClientToServer.FishingCastWithAim, {
			castMode = "Auto",
			hitWater = true,
		})
	end
end

local function setMinigameCameraZoom(inMinigame: boolean)
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	local targetFov = if inMinigame then 64 else 70
	TweenService:Create(cam, TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		FieldOfView = targetFov,
	}):Play()
end

function FishingController.Init(rootGui: ScreenGui)
	MinigameBar.OnOpenStateChanged(function(isOpen: boolean)
		setMinigameCameraZoom(isOpen)
	end)

	MinigameBar.Mount(rootGui, function(sessionId: string, roundIdx: number, clientElapsed: number)
		AnimationController.PlayReelPull()
		Net.FireServer(Net.ClientToServer.FishingMinigameStrike, sessionId, roundIdx, clientElapsed)
	end)

	Net.OnClientEvent(Net.ServerToClient.FishingCastStarted, function(_payload: any)
		isCastingOrWaiting = true
		AnimationController.PlayCast()
		notifyUiState()
	end)

	Net.OnClientEvent(Net.ServerToClient.FishingMinigamePrompt, function(payload: any)
		if type(payload) ~= "table" then
			return
		end
		local rawCenters = if type(payload.zoneCenters) == "table" then payload.zoneCenters else { 0.52 }
		MinigameBar.Start({
			sessionId = tostring(payload.sessionId or ""),
			fishName = tostring(payload.fishName or "Rare Fish"),
			rarity = tostring(payload.rarity or "Rare"),
			mutation = tostring(payload.mutation or "None"),
			rounds = tonumber(payload.rounds) or 1,
			zoneWidth = tonumber(payload.zoneWidth) or 0.28,
			zoneCenters = rawCenters,
			speed = tonumber(payload.speed) or 1.1,
			timeoutSec = tonumber(payload.timeoutSec) or 7.5,
		})
	end)

	Net.OnClientEvent(Net.ServerToClient.FishingMinigameStep, function(payload: any)
		if type(payload) == "table" then
			MinigameBar.SyncRoundFromServer(tostring(payload.sessionId or ""), tonumber(payload.nextRound) or 1)
		end
	end)

	Net.OnClientEvent(Net.ServerToClient.FishingCatchResult, function(payload: any)
		isCastingOrWaiting = false
		MinigameBar.ForceClose()
		AnimationController.PlayReelPull()
		notifyUiState()

		for _, cb in ipairs(catchListeners) do
			task.spawn(cb, payload)
		end

		scheduleSingleAutoRecast()
	end)

	Net.OnClientEvent(Net.ServerToClient.FishingStateReset, function(payload: any)
		isCastingOrWaiting = false
		MinigameBar.ForceClose()
		AnimationController.StopFishingHold()
		if type(payload) == "table" and (payload.bagFull or payload.tooFar or payload.weakRod or payload.reason == "Unequip") then
			autoFishEnabled = false
			recastTicket += 1
			Net.FireServer(Net.ClientToServer.SetAutoFish, false)
		end
		notifyUiState()
	end)
end

return FishingController
