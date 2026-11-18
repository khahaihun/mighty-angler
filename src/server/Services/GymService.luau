--!strict
-- GymService.luau: Tap Gym Click chuot & Auto-Train (Join Group mien phi) Server-Authoritative

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local IslandsRegistry = require(Shared:WaitForChild("Config"):WaitForChild("Islands"))

local DataService = require(script.Parent.DataService)
local PerkService = require(script.Parent.PerkService)
local CurrencyService = require(script.Parent.CurrencyService)

local GymService = {}

local lastManualRepAt: { [Player]: number } = {}
local lastReqToastAt: { [Player]: number } = {}
local autoTrainActive: { [Player]: boolean } = {}
local repCompletedHooks: { (Player, number) -> () } = {}

function GymService.OnGymRepCompleted(callback: (Player, number) -> ())
	table.insert(repCompletedHooks, callback)
end

local function findNearbyStation(player: Player, islandDef: Types.IslandDef): (Types.GymStationDef?, number)
	local char = player.Character
	local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
	if not (root and root:IsA("BasePart")) then
		return nil, 0
	end

	local pPos = root.Position
	local bestStation: Types.GymStationDef? = nil
	local bestIdx = 0
	local bestDist = GameConfig.GYM_STATION_RADIUS

	for idx, st in ipairs(islandDef.gymStations) do
		local stPos = islandDef.centerPosition + st.offset
		local horizDist = Vector3.new(pPos.X - stPos.X, 0, pPos.Z - stPos.Z).Magnitude
		local vertDiff = math.abs(pPos.Y - stPos.Y)
		if horizDist <= bestDist and vertDiff <= 10 then
			bestDist = horizDist
			bestStation = st
			bestIdx = idx
		end
	end

	return bestStation, bestIdx
end

local function performStationRep(player: Player, isAuto: boolean): boolean
	local profile = DataService.Get(player)
	if not profile then
		return false
	end

	local islandDef = IslandsRegistry.Get(profile.currentIsland)
	local station, _ = findNearbyStation(player, islandDef)
	if not station then
		if not isAuto then
			Net.FireClient(player, Net.ServerToClient.Toast, {
				kind = "Info",
				text = "Stand on a glowing Gym Station pad to train Strength!",
			})
		end
		return false
	end

	if profile.strength < station.minStrength then
		local now = os.clock()
		local prevToast = lastReqToastAt[player] or 0
		if now - prevToast > 2.2 then
			lastReqToastAt[player] = now
			Net.FireClient(player, Net.ServerToClient.Toast, {
				kind = "Error",
				text = string.format("Need %s Strength to use %s!", Util.FormatNumber(station.minStrength), station.name),
			})
		end
		return false
	end

	local baseGain = islandDef.baseGymGain * station.multiplier
	local gained = CurrencyService.AddStrength(player, baseGain, true, false)
	profile.stats.gymReps += 1
	DataService.MarkDirty(player)

	Net.FireClient(player, Net.ServerToClient.GymRepFeedback, {
		stationType = station.stationType,
		stationName = station.name,
		gained = gained,
		totalStrength = profile.strength,
	})

	for _, cb in ipairs(repCompletedHooks) do
		task.spawn(cb, player, gained)
	end

	return true
end

local function movePlayerToBestGymStation(player: Player, profile: Types.PlayerProfile)
	local char = player.Character
	if not char then
		return
	end
	local islandDef = IslandsRegistry.Get(profile.currentIsland)
	local chosen = islandDef.gymStations[1]
	for _, st in ipairs(islandDef.gymStations) do
		if profile.strength >= st.minStrength then
			chosen = st
		end
	end
	if chosen then
		local padPos = islandDef.centerPosition + chosen.offset + Vector3.new(0, 3.8, 1.8)
		char:PivotTo(CFrame.new(padPos))
	end
end

function GymService.Init()
	Net.OnServerEvent(Net.ClientToServer.GymRep, function(player: Player)
		local now = os.clock()
		local last = lastManualRepAt[player] or 0
		if now - last < GameConfig.GYM_MANUAL_COOLDOWN_SEC then
			return
		end
		lastManualRepAt[player] = now
		performStationRep(player, false)
	end)

	Net.OnServerEvent(Net.ClientToServer.SetAutoTrain, function(player: Player, rawEnable: any)
		local want = (rawEnable == true)
		if want and not PerkService.CanAutoTrain(player) then
			autoTrainActive[player] = false
			Net.FireClient(player, Net.ServerToClient.Toast, {
				kind = "Info",
				text = "Join our Official Roblox Group for FREE Auto-Train!",
			})
			PerkService.PushPerks(player)
			return
		end
		autoTrainActive[player] = want
		if want then
			local profile = DataService.Get(player)
			if profile then
				local islandDef = IslandsRegistry.Get(profile.currentIsland)
				local st, _ = findNearbyStation(player, islandDef)
				if not st then
					movePlayerToBestGymStation(player, profile)
				end
				performStationRep(player, true)
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		lastManualRepAt[player] = nil
		lastReqToastAt[player] = nil
		autoTrainActive[player] = nil
	end)

	-- Vong lap Auto-Train tren Server (tu tap khi dung tren may Gym)
	task.spawn(function()
		while true do
			task.wait(GameConfig.GYM_AUTO_INTERVAL_SEC)
			for player, enabled in pairs(autoTrainActive) do
				if enabled and PerkService.CanAutoTrain(player) then
					performStationRep(player, true)
				elseif enabled then
					autoTrainActive[player] = false
				end
			end
		end
	end)
end

return GymService
