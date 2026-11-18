--!strict
-- DataService.luau: Quan ly PlayerProfile v2 voi Session Lock doc quyen, saveInFlight tuan tu & UTC Playtime

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Util = require(Shared:WaitForChild("Util"))
local Net = require(Shared:WaitForChild("Net"))
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))

local ProfileMigrator = require(script.Parent.ProfileMigrator)

local DataService = {}

local SERVER_JOB_ID = if game.JobId ~= "" then game.JobId else ("Studio_" .. Util.NewUid())

local profiles: { [Player]: Types.PlayerProfile } = {}
local dirtyRevision: { [Player]: number } = {}
local savedRevision: { [Player]: number } = {}
local saveInFlight: { [Player]: boolean } = {}
local loadFailedPlayers: { [Player]: boolean } = {}
local profileLoadedCallbacks: { (Player, Types.PlayerProfile) -> () } = {}

local dataStore: DataStore? = nil
local studioMemoryFallback = false

local function tryGetDataStore(): DataStore?
	if studioMemoryFallback or game.PlaceId == 0 then
		if game.PlaceId == 0 then
			studioMemoryFallback = true
		end
		return nil
	end
	if dataStore then
		return dataStore
	end
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(GameConfig.DATASTORE_NAME)
	end)
	if ok and result then
		dataStore = result
		return dataStore
	end
	if RunService:IsStudio() then
		studioMemoryFallback = true
	end
	return nil
end

function DataService.SyncLeaderstats(player: Player)
	ProfileMigrator.SyncLeaderstats(player, profiles[player])
end

function DataService.IsTransactionLocked(player: Player, notifyToast: boolean?): boolean
	if loadFailedPlayers[player] then
		if notifyToast then
			Net.FireClient(player, Net.ServerToClient.Toast, {
				kind = "Error",
				text = "Profile is in Safe Read-Only Mode (session lock busy). Rejoin shortly to trade/rebirth!",
			})
		end
		return true
	end
	return false
end

local function acquireSessionAndLoad(player: Player)
	local key = "Player_" .. tostring(player.UserId)
	local store = tryGetDataStore()
	local loadedData: any = nil
	local lockFailed = false

	if store then
		local acquired = false
		for attempt = 1, 3 do
			local ok, updated = pcall(function()
				return store:UpdateAsync(key, function(oldData: any)
					local now = os.time()
					if type(oldData) ~= "table" then
						acquired = true
						local fresh = GameConfig.CreateDefaultProfile() :: any
						fresh.activeSessionId = SERVER_JOB_ID
						fresh.lockTimestamp = now
						fresh.saveSeq = 1
						return fresh
					end
					local holder = oldData.activeSessionId
					local lockAge = now - (tonumber(oldData.lockTimestamp) or 0)
					if holder == nil or holder == SERVER_JOB_ID or lockAge > GameConfig.SESSION_LOCK_EXPIRE_SEC then
						acquired = true
						oldData.activeSessionId = SERVER_JOB_ID
						oldData.lockTimestamp = now
						oldData.saveSeq = (tonumber(oldData.saveSeq) or 0)
						return oldData
					end
					acquired = false
					return nil
				end)
			end)
			if ok and acquired then
				loadedData = updated
				break
			end
			if attempt < 3 then
				task.wait(1.5)
			end
		end
		if not acquired then
			lockFailed = true
		end
	elseif game.PlaceId > 0 and not studioMemoryFallback then
		lockFailed = true
	end

	if not player:IsDescendantOf(Players) then
		return
	end

	local profile = ProfileMigrator.SanitizeLoadedProfile(loadedData)
	profile.activeSessionId = SERVER_JOB_ID
	profile.lockTimestamp = os.time()

	profiles[player] = profile
	dirtyRevision[player] = 0
	savedRevision[player] = 0
	if lockFailed then
		loadFailedPlayers[player] = true
		Net.FireClient(player, Net.ServerToClient.Toast, {
			kind = "Error",
			text = "DataStore session busy! Safe Temporary Mode enabled (progress won't overwrite your main save).",
		})
	end

	ProfileMigrator.SetupLeaderstats(player, profile)
	for _, cb in ipairs(profileLoadedCallbacks) do
		task.spawn(cb, player, profile)
	end
end

function DataService.SaveProfile(player: Player, releaseLock: boolean?)
	if loadFailedPlayers[player] then
		return
	end
	while saveInFlight[player] do
		task.wait(0.05)
	end
	local profile = profiles[player]
	local store = tryGetDataStore()
	if not profile or not store then
		return
	end

	saveInFlight[player] = true
	local revBefore = dirtyRevision[player] or 0
	local expectedSeq = profile.saveSeq
	local nextSeq = expectedSeq + 1
	local snapshot = Util.DeepCopy(profile)
	snapshot.saveSeq = nextSeq
	snapshot.activeSessionId = if releaseLock then nil else SERVER_JOB_ID
	snapshot.lockTimestamp = if releaseLock then 0 else os.time()

	local key = "Player_" .. tostring(player.UserId)
	local wrote = false
	local ok = pcall(function()
		store:UpdateAsync(key, function(oldData: any)
			if type(oldData) == "table" then
				if oldData.activeSessionId ~= SERVER_JOB_ID then
					return nil
				end
				if (tonumber(oldData.saveSeq) or 0) > expectedSeq then
					return nil
				end
			end
			wrote = true
			return snapshot
		end)
	end)

	if ok and wrote then
		profile.saveSeq = nextSeq
		profile.activeSessionId = snapshot.activeSessionId
		profile.lockTimestamp = snapshot.lockTimestamp
		if (dirtyRevision[player] or 0) == revBefore then
			savedRevision[player] = revBefore
		end
	end
	saveInFlight[player] = nil
end

function DataService.Get(player: Player): Types.PlayerProfile?
	return profiles[player]
end

function DataService.WaitForProfile(player: Player, timeoutSec: number?): Types.PlayerProfile?
	local deadline = os.clock() + (timeoutSec or 10)
	while player:IsDescendantOf(Players) and os.clock() < deadline do
		local p = profiles[player]
		if p then
			return p
		end
		task.wait(0.05)
	end
	return profiles[player]
end

function DataService.MarkDirty(player: Player)
	if profiles[player] then
		dirtyRevision[player] = (dirtyRevision[player] or 0) + 1
	end
end

function DataService.ResetProfileForDev(player: Player): Types.PlayerProfile?
	if not RunService:IsStudio() or not profiles[player] then
		return nil
	end
	local fresh = GameConfig.CreateDefaultProfile()
	fresh.activeSessionId = SERVER_JOB_ID
	profiles[player] = fresh
	DataService.MarkDirty(player)
	DataService.SyncLeaderstats(player)
	DataService.PushFullSnapshot(player)
	return fresh
end

function DataService.OnProfileLoaded(callback: (Player, Types.PlayerProfile) -> ())
	table.insert(profileLoadedCallbacks, callback)
	for player, profile in pairs(profiles) do
		task.spawn(callback, player, profile)
	end
end

function DataService.PushFullSnapshot(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	Net.FireClient(player, Net.ServerToClient.StateSnapshot, {
		profile = profile,
		serverNow = os.time(),
		studioFallback = studioMemoryFallback,
		safeReadOnly = loadFailedPlayers[player] == true,
	})
end

function DataService.Init()
	Net.OnServerEvent(Net.ClientToServer.RequestInitialState, function(player: Player)
		if DataService.WaitForProfile(player, 8) then
			DataService.PushFullSnapshot(player)
		end
	end)

	Players.PlayerAdded:Connect(acquireSessionAndLoad)
	for _, existingPlayer in ipairs(Players:GetPlayers()) do
		task.spawn(acquireSessionAndLoad, existingPlayer)
	end

	Players.PlayerRemoving:Connect(function(player: Player)
		DataService.SaveProfile(player, true)
		profiles[player] = nil
		dirtyRevision[player] = nil
		savedRevision[player] = nil
		loadFailedPlayers[player] = nil
	end)

	game:BindToClose(function()
		for player, _ in pairs(profiles) do
			DataService.SaveProfile(player, true)
		end
	end)

	task.spawn(function()
		local accSave = 0
		local accPush = 0
		while true do
			task.wait(1)
			accSave += 1
			accPush += 1
			local today = Util.GetUtcDayIndex()
			for player, profile in pairs(profiles) do
				profile.stats.playTimeSec += 1
				if profile.playtimeDay ~= today then
					profile.playtimeDay = today
					profile.playtimeTodaySec = 1
					profile.playtimeClaimedToday = {}
					DataService.MarkDirty(player)
				else
					profile.playtimeTodaySec += 1
				end
				if accPush >= 5 then
					Net.FireClient(player, Net.ServerToClient.PlaytimeUpdated, {
						playtimeTodaySec = profile.playtimeTodaySec,
						playtimeClaimedToday = profile.playtimeClaimedToday,
					})
				end
				if accSave >= GameConfig.AUTOSAVE_INTERVAL_SEC then
					task.spawn(DataService.SaveProfile, player, false)
				end
			end
			if accPush >= 5 then
				accPush = 0
			end
			if accSave >= GameConfig.AUTOSAVE_INTERVAL_SEC then
				accSave = 0
			end
		end
	end)
end

return DataService
