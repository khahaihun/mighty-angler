--!strict
-- FishingController.luau: Dieu khien luong Quang Can, Tu Giat Ca Thuong, Minigame Ca Hiem/Boss va Auto-Fish

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

local AnimationController = require(script.Parent.AnimationController)
local MinigameBar = require(script.Parent.Parent.UI.Panels.MinigameBar)

local FishingController = {}

local isCastingOrWaiting = false
local autoFishEnabled = false
local hasAutoFishPerk = false
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

function FishingController.SetAutoFishPerkAvailable(unlocked: boolean)
	hasAutoFishPerk = unlocked
	if not unlocked and autoFishEnabled then
		autoFishEnabled = false
		notifyUiState()
	end
end

function FishingController.RequestCastOrCancel()
	if MinigameBar.IsOpen() then
		return
	end
	if isCastingOrWaiting then
		isCastingOrWaiting = false
		AnimationController.StopFishingHold()
		Net.FireServer(Net.ClientToServer.FishingCancel)
		notifyUiState()
	else
		Net.FireServer(Net.ClientToServer.FishingCast)
	end
end

function FishingController.ToggleAutoFish()
	if not hasAutoFishPerk then
		Net.FireServer(Net.ClientToServer.PromptGamepass, "AutoFish")
		return
	end
	autoFishEnabled = not autoFishEnabled
	Net.FireServer(Net.ClientToServer.SetAutoFish, autoFishEnabled)
	notifyUiState()

	if autoFishEnabled and not isCastingOrWaiting and not MinigameBar.IsOpen() then
		Net.FireServer(Net.ClientToServer.FishingCast)
	end
end

function FishingController.Init(rootGui: ScreenGui)
	MinigameBar.Mount(rootGui, function(sessionId: string, passed: boolean)
		AnimationController.PlayReelPull()
		Net.FireServer(Net.ClientToServer.FishingMinigameResult, sessionId, passed)
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
		MinigameBar.Start({
			sessionId = tostring(payload.sessionId or ""),
			fishName = tostring(payload.fishName or "Rare Fish"),
			rarity = tostring(payload.rarity or "Rare"),
			mutation = tostring(payload.mutation or "None"),
			rounds = tonumber(payload.rounds) or 1,
			zoneWidth = tonumber(payload.zoneWidth) or 0.28,
			speed = tonumber(payload.speed) or 1.1,
		})
	end)

	Net.OnClientEvent(Net.ServerToClient.FishingCatchResult, function(payload: any)
		isCastingOrWaiting = false
		MinigameBar.ForceClose()
		AnimationController.PlayReelPull()
		notifyUiState()

		for _, cb in ipairs(catchListeners) do
			task.spawn(cb, payload)
		end

		if autoFishEnabled then
			task.delay(0.85, function()
				if autoFishEnabled and not isCastingOrWaiting and not MinigameBar.IsOpen() then
					Net.FireServer(Net.ClientToServer.FishingCast)
				end
			end)
		end
	end)

	Net.OnClientEvent(Net.ServerToClient.FishingStateReset, function(payload: any)
		isCastingOrWaiting = false
		MinigameBar.ForceClose()
		AnimationController.StopFishingHold()
		if type(payload) == "table" and (payload.bagFull or payload.tooFar) then
			autoFishEnabled = false
			Net.FireServer(Net.ClientToServer.SetAutoFish, false)
		end
		notifyUiState()
	end)
end

return FishingController
