--!strict
-- DataService.luau: Quan ly PlayerProfile v2 voi Per-Join Session Token, Read-Only Quarantine & Parallel BindToClose

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Util = require(Shared:WaitForChild("Util"))
local Net = require(Shared:WaitForChild("Net"))
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))

local ProfileMigrator = require(script.Parent.ProfileMigrator)
local DataStoreLockHelper = require(script.Parent.DataStoreLockHelper)

local DataService = {}

local SERVER_JOB_ID = if game.JobId ~= "" then game.JobId else ("Studio_" .. Util.NewUid())

local profiles: { [Player]: Types.PlayerProfile } = {}
local sessionTokens: { [Player]: string } = {}
local lastConfirmedRenewAt: { [Player]: number } = {}
local dirtyRevision: { [Player]: number } = {}
local savedRevision: { [Player]: number } = {}
local readOnlyPlayers: { [Player]: boolean } = {}
local closingPlayers: { [Player]: boolean } = {}
local clientRequestedInit: { [Player]: boolean } = {}
local profileLoadedCallbacks: { (Player, Types.PlayerProfile) -> () } = {}

local serverShuttingDown = false

function DataService.SyncLeaderstats(player: Player)
	ProfileMigrator.SyncLeaderstats(player, profiles[player])
end

function DataService.IsTransactionLocked(player: Player, notifyToast: boolean?): boolean
	local locked = profiles[player] == nil or serverShuttingDown or closingPlayers[player] == true or readOnlyPlayers[player] == true
	if not locked and not DataStoreLockHelper.IsStudioOfflineFallback() then
		local lastRenew = lastConfirmedRenewAt[player] or 0
		if (os.time() - lastRenew) > GameConfig.SESSION_LOCK_EXPIRE_SEC then
			readOnlyPlayers[player] = true
			locked = true
		end
	end
	if locked and notifyToast then
		Net.FireClient(player, Net.ServerToClient.Toast, {
			kind = "Error",
			text = "Profile is in Safe Read-Only Mode (session lock busy or closing). Rejoin shortly to trade/rebirth!",
		})
	end
	return locked
end

function DataService.CanWritePersistent(player: Player): boolean
	return profiles[player] ~= nil and not DataService.IsTransactionLocked(player, false)
end

local function releaseLoadedToken(userId: number, key: string, token: string)
	DataStoreLockHelper.WithUserLock(userId, function()
		local store = DataStoreLockHelper.TryGetStore()
		if store then DataStoreLockHelper.ReleaseToken(store, key, token) end
	end)
end

local function acquireSessionAndLoad(player: Player)
	readOnlyPlayers[player] = true
	local userId = player.UserId
	local key = "Player_" .. tostring(userId)
	local myToken = SERVER_JOB_ID .. "_" .. Util.NewUid()
	local loadedData: any = nil
	local confirmedLock = false
	local lockFailed = true -- Chi mo quyen khi nhan xac nhan, hoac Studio RAM-only.

	DataStoreLockHelper.WithUserLock(userId, function()
		local store = DataStoreLockHelper.TryGetStore()
		if store then
			local okLock, data, claimMayBeOwned = DataStoreLockHelper.AcquireLockWithRetries(player, store, key, myToken)
			confirmedLock = okLock
			loadedData = data
			lockFailed = not okLock
			if not okLock and claimMayBeOwned then
				-- Don claim chua chac ket qua ngay ca khi nguoi choi con online.
				DataStoreLockHelper.ReleaseToken(store, key, myToken)
			end
		elseif DataStoreLockHelper.IsStudioOfflineFallback() then
			lockFailed = false
		end
	end)

	if not player:IsDescendantOf(Players) or closingPlayers[player] then
		if confirmedLock then releaseLoadedToken(userId, key, myToken) end
		return
	end

	local profile, quarantineReason = ProfileMigrator.SanitizeLoadedProfile(loadedData)
	if quarantineReason ~= nil then
		if confirmedLock then
			releaseLoadedToken(userId, key, myToken)
		end
		lockFailed = true
	end
	-- Nhay lai sau khi nha kho (co the yield/retry), tranh nap lai nguoi da roi.
	if not player:IsDescendantOf(Players) or closingPlayers[player] then return end

	profile.activeSessionId = if lockFailed then nil else myToken
	profile.lockTimestamp = if confirmedLock then os.time() else 0

	profiles[player] = profile
	sessionTokens[player] = if lockFailed then nil else myToken
	if confirmedLock then
		lastConfirmedRenewAt[player] = os.time()
	end
	dirtyRevision[player] = 0
	savedRevision[player] = 0

	readOnlyPlayers[player] = lockFailed
	if lockFailed then
		Net.FireClient(player, Net.ServerToClient.Toast, {
			kind = "Error",
			text = "DataStore session busy or offline! Safe Read-Only Mode active to protect your main save.",
		})
	end

	ProfileMigrator.SetupLeaderstats(player, profile)
	if clientRequestedInit[player] then
		DataService.PushFullSnapshot(player)
	end
	for _, cb in ipairs(profileLoadedCallbacks) do
		task.spawn(cb, player, profile)
	end
end

function DataService.SaveProfile(player: Player, releaseLock: boolean?): string
	if readOnlyPlayers[player] then
		return "Skipped"
	end
	local userId = player.UserId
	local status = "Skipped"

	DataStoreLockHelper.WithUserLock(userId, function()
		local profile = profiles[player]
		local myToken = sessionTokens[player]
		local store = DataStoreLockHelper.TryGetStore()
		if not profile or not myToken or readOnlyPlayers[player] then
			return
		end
		if not store then
			if DataStoreLockHelper.IsStudioOfflineFallback() then
				lastConfirmedRenewAt[player] = os.time()
				status = "Saved"
			else
				status = "TransientError"
			end
			return
		end

		local revBefore = dirtyRevision[player] or 0
		local key = "Player_" .. tostring(userId)
		local res, nextSeq = DataStoreLockHelper.WriteSnapshotVerified(store, key, profile, myToken, releaseLock == true)
		status = res

		if res == "Saved" then
			profile.saveSeq = nextSeq
			profile.activeSessionId = if releaseLock then nil else myToken
			profile.lockTimestamp = if releaseLock then 0 else os.time()
			lastConfirmedRenewAt[player] = os.time()
			if (dirtyRevision[player] or 0) == revBefore then
				savedRevision[player] = revBefore
			end
		elseif res == "LostLock" then
			readOnlyPlayers[player] = true
			if player:IsDescendantOf(Players) then
				Net.FireClient(player, Net.ServerToClient.Toast, {
					kind = "Error",
					text = "Session moved to another server — switched to Read-Only Mode!",
				})
			end
		end
	end)

	return status
end

local function closePlayerSessionOnce(player: Player)
	if closingPlayers[player] then
		return
	end
	closingPlayers[player] = true

	if profiles[player] and not readOnlyPlayers[player] then
		local res = DataService.SaveProfile(player, true)
		if res == "TransientError" then
			task.wait(0.8)
			DataService.SaveProfile(player, true)
		end
	end

	profiles[player] = nil
	sessionTokens[player] = nil
	lastConfirmedRenewAt[player] = nil
	dirtyRevision[player] = nil
	savedRevision[player] = nil
	readOnlyPlayers[player] = nil
	clientRequestedInit[player] = nil
end

function DataService.Get(player: Player): Types.PlayerProfile?
	return profiles[player]
end

function DataService.WaitForProfile(player: Player, timeoutSec: number?): Types.PlayerProfile?
	local deadline = os.clock() + (timeoutSec or 10)
	while player:IsDescendantOf(Players) and os.clock() < deadline do
		if profiles[player] then
			return profiles[player]
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
	local cur = profiles[player]
	if not RunService:IsStudio() or not cur then
		return nil
	end
	local fresh = GameConfig.CreateDefaultProfile()
	fresh.saveSeq = cur.saveSeq
	fresh.activeSessionId = sessionTokens[player]
	fresh.lockTimestamp = os.time()
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
		studioFallback = DataStoreLockHelper.IsStudioOfflineFallback(),
		safeReadOnly = DataService.IsTransactionLocked(player, false),
	})
end

function DataService.Init()
	Net.OnServerEvent(Net.ClientToServer.RequestInitialState, function(player: Player)
		clientRequestedInit[player] = true
		if profiles[player] or DataService.WaitForProfile(player, 8) then
			DataService.PushFullSnapshot(player)
		end
	end)

	Players.PlayerAdded:Connect(acquireSessionAndLoad)
	for _, existingPlayer in ipairs(Players:GetPlayers()) do
		task.spawn(acquireSessionAndLoad, existingPlayer)
	end
	Players.PlayerRemoving:Connect(closePlayerSessionOnce)

	game:BindToClose(function()
		serverShuttingDown = true
		local pending = 0
		for player, _ in pairs(profiles) do
			pending += 1
			task.spawn(function()
				closePlayerSessionOnce(player)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.05)
		end
	end)

	task.spawn(function()
		local accSave, accPush = 0, 0
		while not serverShuttingDown do
			task.wait(1)
			accSave += 1
			accPush += 1
			for player, profile in pairs(profiles) do
				if not closingPlayers[player] then
					profile.stats.playTimeSec += 1
					if ProfileMigrator.RefreshUtcPlaytimeIfNewDay(profile) then
						profile.playtimeTodaySec = 1
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
			end
			if accPush >= 5 then accPush = 0 end
			if accSave >= GameConfig.AUTOSAVE_INTERVAL_SEC then accSave = 0 end
		end
	end)
end

return DataService
