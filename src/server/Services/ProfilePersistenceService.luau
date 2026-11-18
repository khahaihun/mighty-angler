--!strict
-- Lease, hang doi ghi bat bien va mot tac vu dong chung theo token, gioi han 25 giay.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local Lock = require(script.Parent.DataStoreLockHelper)
local Writer = require(script.Parent.ProfileWriteHelper)
local Validator = require(script.Parent.ProfileValidator)

export type Session = {
	player: Player?, userId: number, token: string, profile: Types.PlayerProfile?,
	loading: boolean, readOnly: boolean, closed: boolean, closing: boolean, closeStarted: boolean,
	closeDeadline: number, closeResult: string?, loadCloseResult: string?, failure: string?,
	confirmedAt: number, revision: number, savedRevision: number, nextSaveAt: number,
	saveQueued: boolean, pending: Writer.Operation?,
}
local ProfilePersistenceService = {}
local sessions: { [Player]: Session } = {}
local shuttingDown = false

function ProfilePersistenceService.Find(player: Player): Session?
	return sessions[player]
end

function ProfilePersistenceService.All(): { Session }
	local result = {}
	for _, s in pairs(sessions) do table.insert(result, s) end
	return result
end

function ProfilePersistenceService.Count(): number
	local count = 0
	for _ in pairs(sessions) do count += 1 end
	return count
end

function ProfilePersistenceService.Begin(player: Player, token: string): Session
	local interval = GameConfig.AUTOSAVE_INTERVAL_SEC
	local nextAt = math.floor(os.clock() / interval) * interval + player.UserId % interval
	if nextAt <= os.clock() then nextAt += interval end
	local s: Session = { player = player, userId = player.UserId, token = token,
		loading = true, readOnly = true, closed = false, closing = shuttingDown, closeStarted = false,
		closeDeadline = math.huge, confirmedAt = 0, revision = 0, savedRevision = 0,
		nextSaveAt = nextAt, saveQueued = false }
	sessions[player] = s
	return s
end

function ProfilePersistenceService.Locked(s: Session?): boolean
	if not s or not s.profile or s.loading or s.readOnly or s.closing or s.closed or shuttingDown then return true end
	return not Lock.IsStudioOfflineFallback() and os.time() >= s.confirmedAt + GameConfig.SESSION_LOCK_EXPIRE_SEC
end

function ProfilePersistenceService.Quarantine(s: Session, reason: string)
	if not s.readOnly then warn(string.format("[ProfilePersistence] Quarantine user=%d token=%s reason=%s", s.userId, s.token, reason)) end
	s.readOnly = true
	s.failure = "InvalidProfile:" .. reason
end

local function applyPending(s: Session, store: DataStore): string
	local op = s.pending
	if not op then return "Skipped" end
	local result, writtenAt = Writer.Attempt(store, "Player_" .. tostring(s.userId), op)
	if s.closed then return "Unconfirmed" end -- Phan hoi sau deadline khong nap lai RAM.
	if result == "Saved" then
		op.target.saveSeq = op.nextSeq
		op.target.activeSessionId = if op.release then nil else s.token
		op.target.lockTimestamp = writtenAt
		if not op.release then s.confirmedAt = writtenAt end
		s.savedRevision = math.max(s.savedRevision, op.revision)
		s.pending = nil
	elseif result == "LostLock" then
		s.readOnly = true
		s.failure = result
	end
	return result
end

function ProfilePersistenceService.Save(s: Session, release: boolean): string
	if s.closed or not s.profile then return "Skipped" end
	if s.readOnly then return s.failure or "Skipped" end
	if s.closing and not release then return "Skipped" end
	local status = "TransientError"
	Lock.WithUserLock(s.userId, function()
		if s.closed or not s.profile or (s.closing and not release) then status = "Skipped"; return end
		if s.readOnly then status = s.failure or "Skipped"; return end
		local invalid = Validator.Validate(s.profile)
		if invalid then ProfilePersistenceService.Quarantine(s, invalid); status = "InvalidProfile"; return end
		local store = Lock.TryGetStore()
		if not store then
			status = if Lock.IsStudioOfflineFallback() then "Saved" else "TransientError"
			return
		end
		local pending = s.pending
		if pending then
			status = applyPending(s, store)
			if status ~= "Saved" or pending.release or (not release and pending.revision == s.revision) then return end
		end
		local profile = s.profile
		if not profile then status = "Skipped"; return end
		s.pending = Writer.Create(profile, s.token, release, s.revision)
		status = applyPending(s, store)
	end)
	return status
end

local function finishClose(s: Session, result: string)
	if s.closed then return end
	s.closed = true
	s.closeResult = result
	if result == "Unconfirmed" then
		warn(string.format("[ProfilePersistence] Final save unconfirmed user=%d token=%s seq=%s nonce=%s reason=%s",
			s.userId, s.token, tostring(s.profile and s.profile.saveSeq),
			tostring(s.pending and s.pending.nonce), tostring(s.failure or s.loadCloseResult or "Deadline")))
	end
	local player = s.player
	if player and sessions[player] == s then sessions[player] = nil end
	s.player, s.profile, s.pending = nil, nil, nil
end

local function requestClose(s: Session, deadline: number)
	if s.closed then return end
	s.closing = true -- Dong giao dich truoc khi worker chup snapshot cuoi.
	s.closeDeadline = math.min(s.closeDeadline, deadline)
	if s.closeStarted then return end
	s.closeStarted = true
	task.spawn(function()
		local ok, err = pcall(function(): boolean
			while s.loading and not s.closed and os.clock() < s.closeDeadline do task.wait(0.05) end
			while not s.closed and os.clock() < s.closeDeadline do
				if s.loadCloseResult == "TransientError" then finishClose(s, "Unconfirmed"); return true end
				local result = ProfilePersistenceService.Save(s, true)
				if s.closed then return true end
				if os.clock() >= s.closeDeadline then break end
				if result == "Saved" or result == "Skipped" then
					finishClose(s, if Lock.IsStudioOfflineFallback() then "RAMOnly" else result)
					return true
				end
				if result ~= "TransientError" then s.failure = result; break end
				task.wait(math.min(0.8, math.max(0, s.closeDeadline - os.clock())))
			end
			return true
		end)
		if not ok then s.failure = tostring(err) end
		if not s.closed then finishClose(s, "Unconfirmed") end
	end)
end

function ProfilePersistenceService.Close(player: Player): string
	local s = sessions[player]
	if not s then return "Skipped" end
	requestClose(s, os.clock() + 25)
	while not s.closed do
		if os.clock() >= s.closeDeadline then finishClose(s, "Unconfirmed"); break end
		task.wait(0.05)
	end
	return s.closeResult or "Unconfirmed"
end

function ProfilePersistenceService.Shutdown(): { [string]: string }
	shuttingDown = true
	local deadline = os.clock() + 25
	local tracked: { [string]: Session } = {}
	while ProfilePersistenceService.Count() > 0 and os.clock() < deadline do
		for _, s in ipairs(ProfilePersistenceService.All()) do
			s.closing = true
			tracked[s.token] = s
		end
		for _, s in ipairs(ProfilePersistenceService.All()) do requestClose(s, deadline) end
		if ProfilePersistenceService.Count() > 0 then task.wait(0.05) end
	end
	for _, s in ipairs(ProfilePersistenceService.All()) do finishClose(s, "Unconfirmed") end
	local results: { [string]: string } = {}
	for token, s in pairs(tracked) do results[token] = s.closeResult or "Unconfirmed" end
	return results
end

function ProfilePersistenceService.Tick()
	local now = os.clock()
	for _, s in ipairs(ProfilePersistenceService.All()) do
		if not shuttingDown and not s.loading and not s.closing and not s.readOnly and not s.saveQueued and now >= s.nextSaveAt then
			s.nextSaveAt += GameConfig.AUTOSAVE_INTERVAL_SEC
			if s.nextSaveAt <= now then s.nextSaveAt = now + GameConfig.AUTOSAVE_INTERVAL_SEC end
			s.saveQueued = true
			task.spawn(function()
				local result = ProfilePersistenceService.Save(s, false)
				s.saveQueued = false
				if result == "TransientError" then s.nextSaveAt = math.min(s.nextSaveAt, os.clock() + 3 + s.userId % 3) end
			end)
		end
	end
end

return ProfilePersistenceService
