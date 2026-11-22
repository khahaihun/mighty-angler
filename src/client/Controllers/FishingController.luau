--!strict
-- FishingController.luau: Dieu phoi Quang Can, Auto-Fish (Free 1.10s / Pro 0.45s Perfect), Minigame Server-Ack & Recast Coordinator

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

local AnimationController = require(script.Parent.AnimationController)
local CameraFocusController = require(script.Parent.CameraFocusController)
local MinigameBar = require(script.Parent.Parent.UI.Panels.MinigameBar)

local FishingController = {}

local localPlayer = Players.LocalPlayer
local isCastingOrWaiting = false
local autoFishEnabled = false
local nextCastAt = 0
local manualCastAt = 0
local activeSessionId: string? = nil
local lastClosedSessionId: string? = nil
local autoRequestId = 0
local acknowledgedIntent = 0
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

function FishingController.CanManualCast(): boolean
	return Workspace:GetServerTimeNow() >= manualCastAt
end

function FishingController.IsAutoFishEnabled(): boolean
	return autoFishEnabled
end

function FishingController.SetAutoFishPerkAvailable(_ownsPro: boolean)
	notifyUiState()
end

local function isCharacterAlive(): boolean
	local char = localPlayer.Character
	local hum = if char then char:FindFirstChildOfClass("Humanoid") else nil
	return hum ~= nil and hum.Health > 0
end

local function sendIntentUntilAcknowledged(requestId: number)
 if requestId ~= autoRequestId or acknowledgedIntent >= requestId then return end
 Net.FireServer(Net.ClientToServer.SetAutoFish, autoFishEnabled, requestId)
 task.delay(1.1, function() sendIntentUntilAcknowledged(requestId) end)
end
local function changeIntent(active: boolean)
 autoFishEnabled = active
 autoRequestId += 1
 recastTicket += 1
 sendIntentUntilAcknowledged(autoRequestId)
end
local function resumes(reason: string): boolean
 return reason == "Died" or reason == "IslandChange" or reason == "Rebirth" or reason == "Win" or reason == "Miss" or reason == "Timeout"
  or reason == "CastCooldown"
end

local function scheduleSingleAutoRecast(extraDelay: number?)
 recastTicket += 1
 local myTicket = recastTicket
 if not autoFishEnabled or acknowledgedIntent < autoRequestId or isCastingOrWaiting or MinigameBar.IsOpen() then return end
 task.delay(math.max(extraDelay or 0, nextCastAt - Workspace:GetServerTimeNow()), function()
  if recastTicket ~= myTicket or not autoFishEnabled or isCastingOrWaiting or MinigameBar.IsOpen() then return end
  if not isCharacterAlive() then scheduleSingleAutoRecast(0.25); return end
  if currentHotbarSlot ~= 1 then
   changeIntent(false)
   notifyUiState()
   return
  end
  isCastingOrWaiting = true -- Reserve the pending request before sending it.
  Net.FireServer(Net.ClientToServer.FishingCastWithAim, { castMode = "Auto" })
  local requestTicket = recastTicket
  task.delay(1.1, function()
   if requestTicket ~= recastTicket or activeSessionId ~= nil then return end
   isCastingOrWaiting = false
   scheduleSingleAutoRecast()
  end)
 end)
end

function FishingController.CancelCurrentCast()
	recastTicket += 1
	if MinigameBar.IsOpen() then
		return
	end
	if autoFishEnabled then
		changeIntent(false)
	end
	if isCastingOrWaiting then
		isCastingOrWaiting = false
		AnimationController.StopFishingHold()
		Net.FireServer(Net.ClientToServer.FishingCancel)
	end
	notifyUiState()
end

function FishingController.ToggleAutoFish()
 changeIntent(not autoFishEnabled)
 notifyUiState()
 -- Only the authoritative enable reply can schedule the first cast or equip the rod.
end

local function setMinigameCameraZoom(inMinigame: boolean)
	CameraFocusController.SetMinigame(inMinigame)
end

function FishingController.Init(rootGui: ScreenGui)
 localPlayer.CharacterAdded:Connect(function()
  isCastingOrWaiting = false; activeSessionId = nil
  scheduleSingleAutoRecast(0.25)
 end)
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
				changeIntent(false)
				notifyUiState()
			end
		end
	end)

	Net.OnClientEvent(Net.ServerToClient.StateSnapshot, function(snap: any)
		if type(snap) == "table" and type(snap.profile) == "table" then
			currentHotbarSlot = tonumber(snap.profile.equippedHotbarSlot) or 1
		end
	end)

	Net.OnClientEvent(Net.ServerToClient.FishingCastStarted, function(payload: any)
		activeSessionId = if type(payload) == "table" then tostring(payload.sessionId or "") else nil
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

 Net.OnClientEvent(Net.ServerToClient.FishingAutoState, function(payload: any)
  if type(payload) ~= "table" then return end
  if tonumber(payload.requestId) ~= autoRequestId then return end
  acknowledgedIntent = autoRequestId
  nextCastAt = math.max(nextCastAt, tonumber(payload.readyAt) or 0)
  if payload.enabled ~= true then autoFishEnabled = false; recastTicket += 1 end
  if activeSessionId == nil then isCastingOrWaiting = false end
  notifyUiState()
  scheduleSingleAutoRecast()
 end)
 Net.OnClientEvent(Net.ServerToClient.FishingSessionClosed, function(payload: any)
  if type(payload) ~= "table" then return end
  local sid = tostring(payload.sessionId or "")
  if sid == lastClosedSessionId or sid ~= activeSessionId then return end
  lastClosedSessionId = sid; activeSessionId = nil
  isCastingOrWaiting = false
  nextCastAt = math.max(nextCastAt, tonumber(payload.readyAt) or 0)
  manualCastAt = math.max(manualCastAt, tonumber(payload.manualReadyAt) or 0)
  local reason = tostring(payload.reason or "")
  if not resumes(reason) and (tonumber(payload.requestId) or 0) >= autoRequestId then changeIntent(false) end
  MinigameBar.ForceClose()
  AnimationController.StopFishingHold()
  notifyUiState()
  scheduleSingleAutoRecast()
 end)
 Net.OnClientEvent(Net.ServerToClient.FishingCatchResult, function(payload: any)
  AnimationController.PlayReelPull()
  for _, cb in ipairs(catchListeners) do task.spawn(cb, payload) end
 end)

 Net.OnClientEvent(Net.ServerToClient.FishingStateReset, function(payload: any)
  if type(payload) ~= "table" or (tonumber(payload.requestId) or 0) < autoRequestId then return end
  isCastingOrWaiting = false
  MinigameBar.ForceClose()
  AnimationController.StopFishingHold()
  activeSessionId = nil
  local reason = if type(payload) == "table" then tostring(payload.reason or "") else ""
  if type(payload) == "table" then nextCastAt = math.max(nextCastAt, tonumber(payload.readyAt) or 0) end
  if not resumes(reason) and (tonumber(payload.requestId) or 0) >= autoRequestId then changeIntent(false) end
  notifyUiState()
  scheduleSingleAutoRecast(if resumes(reason) then 0.55 else nil)
	end)
end

return FishingController
