--!strict
-- FishingController.luau: Dieu phoi Quang Can, Auto-Fish (Free 1.10s / Pro 0.45s Perfect), Minigame Server-Ack & Recast Coordinator

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))

local AnimationController = require(script.Parent.AnimationController)
local CameraFocusController = require(script.Parent.CameraFocusController)
local MinigameBar = require(script.Parent.Parent.UI.Panels.MinigameBar)

local FishingController = {}

local localPlayer = Players.LocalPlayer
local isCastingOrWaiting = false
local autoFishEnabled = false
local hasAutoFishPro = false
local currentHotbarSlot = 1
local recastTicket = 0

local stateListeners: { (boolean, boolean) -> () } = {}
local catchListeners: { (any) -> () } = {}

local function notifyUiState()
	-- An nut REEL IN ngay khi Minigame dang mo de nguoi choi khong bam nham!
	local canCancelWaiting = isCastingOrWaiting and not MinigameBar.IsOpen()
	for _, cb in ipairs(stateListeners) do
		task.spawn(cb, canCancelWaiting, autoFishEnabled)
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

function FishingController.IsAutoFishEnabled(): boolean
	return autoFishEnabled
end

function FishingController.SetAutoFishPerkAvailable(ownsPro: boolean)
	hasAutoFishPro = ownsPro
	notifyUiState()
end

local function isCharacterAlive(): boolean
	local char = localPlayer.Character
	local hum = if char then char:FindFirstChildOfClass("Humanoid") else nil
	return hum ~= nil and hum.Health > 0
end

local function scheduleSingleAutoRecast(extraDelaySec: number?)
	recastTicket += 1
	local myTicket = recastTicket
	if not autoFishEnabled then
		return
	end
	local baseDelay = if hasAutoFishPro then GameConfig.AUTO_FISH_PRO_RECAST_SEC else GameConfig.AUTO_FISH_FREE_RECAST_SEC
	local delaySec = baseDelay + (extraDelaySec or 0)
	task.delay(delaySec, function()
		if recastTicket ~= myTicket or not autoFishEnabled or isCastingOrWaiting or MinigameBar.IsOpen() then
			return
		end
		if currentHotbarSlot ~= 1 then
			autoFishEnabled = false
			Net.FireServer(Net.ClientToServer.SetAutoFish, false)
			notifyUiState()
			return
		end
		if not isCharacterAlive() then
			scheduleSingleAutoRecast(1.0)
			return
		end
		Net.FireServer(Net.ClientToServer.FishingCastWithAim, {
			castMode = "Auto",
			hitWater = true,
		})
	end)
end

function FishingController.CancelCurrentCast()
	recastTicket += 1
	if MinigameBar.IsOpen() then
		return
	end
	if autoFishEnabled then
		autoFishEnabled = false
		Net.FireServer(Net.ClientToServer.SetAutoFish, false)
	end
	if isCastingOrWaiting then
		isCastingOrWaiting = false
		AnimationController.StopFishingHold()
		Net.FireServer(Net.ClientToServer.FishingCancel)
	end
	notifyUiState()
end

function FishingController.ToggleAutoFish()
	autoFishEnabled = not autoFishEnabled
	recastTicket += 1
	Net.FireServer(Net.ClientToServer.SetAutoFish, autoFishEnabled)
	notifyUiState()

	if autoFishEnabled and not isCastingOrWaiting and not MinigameBar.IsOpen() then
		if currentHotbarSlot ~= 1 then
			Net.FireServer(Net.ClientToServer.SelectHotbarSlot, 1)
			currentHotbarSlot = 1
		end
		Net.FireServer(Net.ClientToServer.FishingCastWithAim, {
			castMode = "Auto",
			hitWater = true,
		})
	end
end

local function setMinigameCameraZoom(inMinigame: boolean)
	CameraFocusController.SetMinigame(inMinigame)
end

function FishingController.Init(rootGui: ScreenGui)
	MinigameBar.OnOpenStateChanged(function(isOpen: boolean)
		setMinigameCameraZoom(isOpen)
		notifyUiState()
	end)

	MinigameBar.Mount(rootGui, function(sessionId: string, roundIdx: number, clientElapsed: number)
		AnimationController.PlayReelPull()
		Net.FireServer(Net.ClientToServer.FishingMinigameStrike, sessionId, roundIdx, clientElapsed)
	end)

	Net.OnClientEvent(Net.ServerToClient.HotbarUpdated, function(payload: any)
		if type(payload) == "table" then
			local slot = tonumber(payload.equippedSlot) or 1
			currentHotbarSlot = slot
			if slot ~= 1 and autoFishEnabled then
				autoFishEnabled = false
				recastTicket += 1
				Net.FireServer(Net.ClientToServer.SetAutoFish, false)
				notifyUiState()
			end
		end
	end)

	Net.OnClientEvent(Net.ServerToClient.StateSnapshot, function(snap: any)
		if type(snap) == "table" and type(snap.profile) == "table" then
			currentHotbarSlot = tonumber(snap.profile.equippedHotbarSlot) or 1
		end
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
		scheduleSingleAutoRecast(0)
	end)

	Net.OnClientEvent(Net.ServerToClient.FishingStateReset, function(payload: any)
		isCastingOrWaiting = false
		MinigameBar.ForceClose()
		AnimationController.StopFishingHold()
		local reason = if type(payload) == "table" then tostring(payload.reason or "") else ""
		local stopAuto = type(payload) == "table" and (
			payload.bagFull == true
			or payload.tooFar == true
			or payload.weakRod == true
			or reason == "Unequip"
			or reason == "ManualCancel"
		)
		if stopAuto then
			autoFishEnabled = false
			recastTicket += 1
			Net.FireServer(Net.ClientToServer.SetAutoFish, false)
			notifyUiState()
			return
		end
		notifyUiState()
		if autoFishEnabled then
			local resumeExtra = if reason == "Died" then 1.2 elseif (reason == "IslandChange" or reason == "Rebirth") then 0.55 else 0
			scheduleSingleAutoRecast(resumeExtra)
		end
	end)
end

return FishingController
