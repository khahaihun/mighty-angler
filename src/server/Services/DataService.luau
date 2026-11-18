--!strict
-- DataService: nap ho so, diem vao gameplay; Persistence quan ly lease/ghi/dong phien.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Util = require(Shared:WaitForChild("Util"))
local Net = require(Shared:WaitForChild("Net"))
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local ProfileMigrator = require(script.Parent.ProfileMigrator)
local Lock = require(script.Parent.DataStoreLockHelper)
local Persistence = require(script.Parent.ProfilePersistenceService)
local DataService = {}
local SERVER_JOB_ID = if game.JobId ~= "" then game.JobId else ("Studio_" .. Util.NewUid())
local clientRequestedInit: { [Player]: boolean } = {}
setmetatable(clientRequestedInit, { __mode = "k" })
local profileLoadedCallbacks: { (Player, Types.PlayerProfile) -> () } = {}
local serverShuttingDown = false

function DataService.Get(player: Player): Types.PlayerProfile?
	local s = Persistence.Find(player)
	return if s then s.profile else nil
end

function DataService.SyncLeaderstats(player: Player)
	ProfileMigrator.SyncLeaderstats(player, DataService.Get(player))
end

function DataService.IsTransactionLocked(player: Player, notifyToast: boolean?): boolean
	local locked = Persistence.Locked(Persistence.Find(player))
	if locked and notifyToast then
		Net.FireClient(player, Net.ServerToClient.Toast, {
			kind = "Error", text = "Profile is in Safe Read-Only Mode (session lock busy or closing). Rejoin shortly to trade/rebirth!",
		})
	end
	return locked
end

function DataService.CanWritePersistent(player: Player): boolean
	return not DataService.IsTransactionLocked(player, false)
end

local function releaseLoadedToken(s: Persistence.Session, key: string)
	Lock.WithUserLock(s.userId, function()
		local store = Lock.TryGetStore()
		if store then s.loadCloseResult = Lock.ReleaseToken(store, key, s.token) end
	end)
end

local function acquireSessionAndLoad(player: Player)
	local myToken = SERVER_JOB_ID .. "_" .. Util.NewUid()
	local s = Persistence.Begin(player, myToken)
	local key = "Player_" .. tostring(s.userId)
	local loadedData: any = nil
	local confirmedLock, lockFailed, confirmedAt = false, true, 0
	Lock.WithUserLock(s.userId, function()
		if s.closed or s.closing then return end
		local store = Lock.TryGetStore()
		if store then
			local okLock, data, claimMayBeOwned = Lock.AcquireLockWithRetries(player, store, key, myToken)
			confirmedLock, loadedData, lockFailed = okLock, data, not okLock
			if okLock then confirmedAt = tonumber(data.lockTimestamp) or 0 end
			if not okLock and claimMayBeOwned then s.loadCloseResult = Lock.ReleaseToken(store, key, myToken) end
		elseif Lock.IsStudioOfflineFallback() then lockFailed = false end
	end)
	if not player:IsDescendantOf(Players) or s.closing or s.closed then
		if confirmedLock then releaseLoadedToken(s, key) end
		s.loading = false
		return
	end
	local profile, quarantineReason = ProfileMigrator.SanitizeLoadedProfile(loadedData)
	if quarantineReason ~= nil then
		if confirmedLock then releaseLoadedToken(s, key) end
		lockFailed = true
	end
	if not player:IsDescendantOf(Players) or s.closing or s.closed then s.loading = false; return end
	profile.activeSessionId = if lockFailed then nil else myToken
	profile.lockTimestamp = confirmedAt
	s.profile, s.confirmedAt, s.readOnly, s.loading = profile, confirmedAt, lockFailed, false
	if lockFailed then
		Net.FireClient(player, Net.ServerToClient.Toast, {
			kind = "Error", text = "DataStore session busy or offline! Safe Read-Only Mode active to protect your main save.",
		})
	end
	ProfileMigrator.SetupLeaderstats(player, profile)
	if clientRequestedInit[player] then DataService.PushFullSnapshot(player) end
	for _, cb in ipairs(profileLoadedCallbacks) do task.spawn(cb, player, profile) end
end

function DataService.SaveProfile(player: Player, releaseLock: boolean?): string
	if releaseLock then return DataService.CloseProfile(player) end
	local s = Persistence.Find(player)
	if not s then return "Skipped" end
	local result = Persistence.Save(s, false)
	if result == "LostLock" and player:IsDescendantOf(Players) then
		Net.FireClient(player, Net.ServerToClient.Toast, {
			kind = "Error", text = "Session moved to another server — switched to Read-Only Mode!",
		})
	end
	return result
end

function DataService.CloseProfile(player: Player): string
	clientRequestedInit[player] = nil
	return Persistence.Close(player)
end

function DataService.WaitForProfile(player: Player, timeoutSec: number?): Types.PlayerProfile?
	local deadline = os.clock() + (timeoutSec or 10)
	while player:IsDescendantOf(Players) and os.clock() < deadline do
		local profile = DataService.Get(player)
		if profile then return profile end
		task.wait(0.05)
	end
	return DataService.Get(player)
end

function DataService.MarkDirty(player: Player)
	local s = Persistence.Find(player)
	if s and s.profile then s.revision += 1 end
end

function DataService.ResetProfileForDev(player: Player): Types.PlayerProfile?
	local s = Persistence.Find(player)
	local cur = if s then s.profile else nil
	if not RunService:IsStudio() or not s or not cur then return nil end
	local fresh = GameConfig.CreateDefaultProfile()
	fresh.saveSeq, fresh.activeSessionId, fresh.lockTimestamp = cur.saveSeq, s.token, cur.lockTimestamp
	s.profile = fresh
	DataService.MarkDirty(player)
	DataService.SyncLeaderstats(player)
	DataService.PushFullSnapshot(player)
	return fresh
end

function DataService.OnProfileLoaded(callback: (Player, Types.PlayerProfile) -> ())
	table.insert(profileLoadedCallbacks, callback)
	for _, s in ipairs(Persistence.All()) do
		if s.player and s.profile then task.spawn(callback, s.player, s.profile) end
	end
end

function DataService.PushFullSnapshot(player: Player)
	local profile = DataService.Get(player)
	if not profile then return end
	Net.FireClient(player, Net.ServerToClient.StateSnapshot, {
		profile = profile, serverNow = os.time(), studioFallback = Lock.IsStudioOfflineFallback(),
		safeReadOnly = DataService.IsTransactionLocked(player, false),
	})
end

function DataService.Init()
	Net.OnServerEvent(Net.ClientToServer.RequestInitialState, function(player: Player)
		clientRequestedInit[player] = true
		if DataService.Get(player) or DataService.WaitForProfile(player, 8) then DataService.PushFullSnapshot(player) end
	end)
	Players.PlayerAdded:Connect(acquireSessionAndLoad)
	for _, player in ipairs(Players:GetPlayers()) do task.spawn(acquireSessionAndLoad, player) end
	Players.PlayerRemoving:Connect(DataService.CloseProfile)
	game:BindToClose(function()
		serverShuttingDown = true
		return Persistence.Shutdown()
	end)
	task.spawn(function()
		local accPush = 0
		while not serverShuttingDown do
			task.wait(1)
			Persistence.Tick()
			accPush += 1
			for _, s in ipairs(Persistence.All()) do
				local profile, player = s.profile, s.player
				if profile and player and not s.closing and not s.readOnly then
					local ok, err = pcall(function(): boolean
					profile.stats.playTimeSec += 1
					if ProfileMigrator.RefreshUtcPlaytimeIfNewDay(profile) then
						profile.playtimeTodaySec = 1
						DataService.MarkDirty(player)
					else profile.playtimeTodaySec += 1 end
					if accPush >= 5 then
						Net.FireClient(player, Net.ServerToClient.PlaytimeUpdated, {
							playtimeTodaySec = profile.playtimeTodaySec, playtimeClaimedToday = profile.playtimeClaimedToday,
						})
					end
					return true
					end)
					if not ok then Persistence.Quarantine(s, "RuntimeTick:" .. tostring(err)) end
				end
			end
			if accPush >= 5 then accPush = 0 end
		end
	end)
end

return DataService
