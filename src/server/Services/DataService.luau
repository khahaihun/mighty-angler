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
local pendingInitial: { [Player]: number } = {}
setmetatable(pendingInitial, { __mode = "k" })
local profileLoadedCallbacks: { (Player, Types.PlayerProfile) -> () } = {}
local serverShuttingDown = false

function DataService.Get(player: Player): Types.PlayerProfile?
	local s = Persistence.Find(player)
	return if s then s.profile else nil
end

function DataService.SyncLeaderstats(player: Player)
	ProfileMigrator.SyncLeaderstats(player, DataService.Get(player))
end

local function publishAccess(player: Player): (boolean, boolean, number)
	local s = Persistence.Find(player)
	local locked = Persistence.Locked(s)
	local loading = not s or s.loading or s.profile == nil
	if not s then return locked, loading, 0 end
	local retrying = loading and s.lockWaiting
	local outage = retrying and s.lockWaitLong
	local state = if outage then "Outage" elseif retrying then "Waiting" elseif loading then "Loading" elseif locked then "ReadOnly" else "Ready"
	if s.accessState ~= state then
		s.accessVersion += 1
		if player:IsDescendantOf(Players) then
			Net.FireClient(player, Net.ServerToClient.ProfileAccessChanged, {
				safeReadOnly = locked, loading = loading, accessVersion = s.accessVersion, retrying = retrying, outage = outage,
			})
		end
		s.accessState = state -- Chi cache sau khi gui thanh cong, de scheduler thu lai neu loi.
	end
	return locked, loading, s.accessVersion
end

local function flushInitial(player: Player)
	if not DataService.Get(player) then publishAccess(player); return end
	local count = pendingInitial[player] or 0
	pendingInitial[player] = nil
	for _ = 1, count do DataService.PushFullSnapshot(player) end
end

function DataService.IsTransactionLocked(player: Player, notifyToast: boolean?): boolean
	local locked = publishAccess(player)
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
	publishAccess(player)
	local key = "Player_" .. tostring(s.userId)
	local loadedData: any = nil
	local confirmedLock, lockFailed, confirmedAt = false, true, 0
	local profile: Types.PlayerProfile, quarantineReason: string? = nil :: any, nil
	local round, waitingSince = 0, nil :: number?
	while true do
		round += 1
		loadedData, confirmedLock, lockFailed, confirmedAt = nil, false, true, 0
		s.loading = true
		Lock.WithUserLock(s.userId, function()
			if s.closed or s.closing then return end
			local store = Lock.TryGetStore()
			if store then
				local okLock, data, claimMayBeOwned = Lock.AcquireLockWithRetries(player, store, key, myToken, if round == 1 then 3 else 1)
				confirmedLock, loadedData, lockFailed = okLock, data, not okLock
				-- Khoa da xac nhan: ket qua nha khoa loi cua vong truoc het hieu luc, khong duoc chan lan luu cuoi.
				if okLock then confirmedAt = tonumber(data.lockTimestamp) or 0; s.loadCloseResult = nil end
				if not okLock and claimMayBeOwned then s.loadCloseResult = Lock.ReleaseToken(store, key, myToken) end
			elseif Lock.IsStudioOfflineFallback() then lockFailed = false end
		end)
		if not player:IsDescendantOf(Players) or s.closing or s.closed then
			if confirmedLock then releaseLoadedToken(s, key) end
			s.loading = false
			return
		end
		profile, quarantineReason = ProfileMigrator.SanitizeLoadedProfile(loadedData)
		if quarantineReason ~= nil then
			if confirmedLock then releaseLoadedToken(s, key) end
			lockFailed = true
		end
		if not player:IsDescendantOf(Players) or s.closing or s.closed then s.loading = false; return end
		if not lockFailed or quarantineReason ~= nil then break end
		-- Khoa dang ban hoac kho loi: KHONG dua ho so trang cho nguoi choi; cho roi tu thu lai.
		-- loading=false trong luc cho de nguoi choi roi di duoc dong phien ngay, khong phai doi het vong cho.
		local firstWait = waitingSince or os.clock()
		waitingSince = firstWait
		s.loading, s.lockWaiting = false, true
		s.lockWaitLong = os.clock() - firstWait >= GameConfig.SESSION_LOCK_OUTAGE_NOTICE_SEC
		publishAccess(player)
		task.wait(if round <= GameConfig.SESSION_LOCK_FAST_RETRIES then GameConfig.SESSION_LOCK_RETRY_SEC else GameConfig.SESSION_LOCK_RETRY_SLOW_SEC)
		if not player:IsDescendantOf(Players) or s.closing or s.closed then return end
	end
	profile.activeSessionId = if lockFailed then nil else myToken
	profile.lockTimestamp = confirmedAt
	s.profile, s.confirmedAt, s.readOnly, s.loading, s.lockWaiting, s.lockWaitLong = profile, confirmedAt, lockFailed, false, false, false
	if lockFailed then
		Net.FireClient(player, Net.ServerToClient.Toast, {
			kind = "Error", text = "Your save could not be read safely. Safe Read-Only Mode is active to protect it.",
		})
	end
	ProfileMigrator.SetupLeaderstats(player, profile)
	publishAccess(player)
	flushInitial(player)
	for _, cb in ipairs(profileLoadedCallbacks) do task.spawn(cb, player, profile) end
end

function DataService.SaveProfile(player: Player, releaseLock: boolean?): string
	if releaseLock then return DataService.CloseProfile(player) end
	local s = Persistence.Find(player)
	if not s then return "Skipped" end
	local result = Persistence.Save(s, false)
	publishAccess(player)
	if result == "LostLock" and player:IsDescendantOf(Players) then
		Net.FireClient(player, Net.ServerToClient.Toast, {
			kind = "Error", text = "Session moved to another server — switched to Read-Only Mode!",
		})
	end
	return result
end

function DataService.CloseProfile(player: Player): string
	pendingInitial[player] = nil
	local s = Persistence.Find(player)
	if s then s.closing = true; publishAccess(player) end
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

function DataService.ResetProfileForDev(player: Player): (Types.PlayerProfile?, string)
	local s = Persistence.Find(player)
	if not RunService:IsStudio() or not s then return nil, "Unavailable" end
	local fresh, result = Persistence.Reset(s)
	if fresh then DataService.SyncLeaderstats(player); DataService.PushFullSnapshot(player) end
	return fresh, result
end

function DataService.OnProfileLoaded(callback: (Player, Types.PlayerProfile) -> ())
	table.insert(profileLoadedCallbacks, callback)
	for _, s in ipairs(Persistence.All()) do
		if s.player and s.profile then task.spawn(callback, s.player, s.profile) end
	end
end

function DataService.PushFullSnapshot(player: Player)
	local profile = DataService.Get(player)
	if not profile or not player:IsDescendantOf(Players) then return end
	local locked, loading, version = publishAccess(player)
	Net.FireClient(player, Net.ServerToClient.StateSnapshot, {
		profile = profile, serverNow = os.time(), studioFallback = Lock.IsStudioOfflineFallback(),
		safeReadOnly = locked, loading = loading, accessVersion = version,
	})
end

function DataService.Init()
	Net.OnServerEvent(Net.ClientToServer.RequestInitialState, function(player: Player)
		pendingInitial[player] = (pendingInitial[player] or 0) + 1
		flushInitial(player)
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
			local tickOk, tickErr = pcall(function(): boolean Persistence.Tick(); return true end)
			if not tickOk then warn("[DataService] Persistence tick error:", tostring(tickErr)) end
			accPush += 1
			for _, s in ipairs(Persistence.All()) do
				local profile, player = s.profile, s.player
				if player then
					local ok, err = pcall(function(): boolean
						publishAccess(player)
						if profile and not s.closing and not s.readOnly then
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
