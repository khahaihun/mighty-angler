--!strict
-- DataStoreLockHelper.luau: Quan ly hang cho tuan tu theo UserId & xac thuc Nonce cho UpdateAsync Session Lock

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Util = require(Shared:WaitForChild("Util"))
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local Validator = require(script.Parent.ProfileValidator)

local DataStoreLockHelper = {}

local userBusy: { [number]: boolean } = {}
local dataStore: DataStore? = nil
local studioOfflineFallback = (game.PlaceId == 0)

function DataStoreLockHelper.IsStudioOfflineFallback(): boolean
	return studioOfflineFallback
end

function DataStoreLockHelper.GetActiveStoreLabel(): string
	if studioOfflineFallback then
		return "RAM-Only Fallback"
	end
	if RunService:IsStudio() then
		return GameConfig.DATASTORE_NAME .. "_StudioDev"
	end
	return GameConfig.DATASTORE_NAME
end

function DataStoreLockHelper.TryGetStore(): DataStore?
	if game.PlaceId == 0 then
		studioOfflineFallback = true
		return nil
	end
	if dataStore then
		return dataStore
	end
	-- Khi test tren Place da publish trong Studio, dung kho StudioDev rieng de khong anh huong du lieu nguoi choi that
	local storeName = if RunService:IsStudio()
		then (GameConfig.DATASTORE_NAME .. "_StudioDev")
		else GameConfig.DATASTORE_NAME
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(storeName)
	end)
	if ok and result then
		dataStore = result
		return dataStore
	end
	return nil
end

function DataStoreLockHelper.WithUserLock(userId: number, fn: () -> ())
	while userBusy[userId] do
		task.wait(0.05)
	end
	userBusy[userId] = true
	local ok, err = pcall(function(): any
		fn()
		return true
	end)
	userBusy[userId] = nil
	if not ok then
		warn("[DataStoreLockHelper] Queue error:", err)
	end
end

-- Nil thanh cong la callback da huy vi token khong con so huu; khong ghi len chu moi.
function DataStoreLockHelper.ReleaseToken(store: DataStore, key: string, token: string): string
	for attempt = 1, 3 do
		local ok, updated = pcall(function()
			return store:UpdateAsync(key, function(oldData: any)
				if type(oldData) == "table" and oldData.activeSessionId == token then
					oldData.activeSessionId = nil
					oldData.lockTimestamp = 0
					return oldData
				end
				return nil
			end)
		end)
		if ok and type(updated) == "table" and updated.activeSessionId == nil then
			return "Released"
		elseif ok and updated == nil then
			return "NotOwner"
		end
		if attempt < 3 then task.wait(0.5) end
	end
	warn("[DataStoreLockHelper] Release unconfirmed after 3 attempts:", key, token)
	return "TransientError"
end

-- Tra ve (confirmedLock, loadedRawData, claimMayBeOwned): loi phan hoi co the da ghi claim.
function DataStoreLockHelper.AcquireLockWithRetries(player: Player, store: DataStore, key: string, myToken: string): (boolean, any, boolean)
	local claimMayBeOwned = false
	for attempt = 1, 3 do
		if not player:IsDescendantOf(Players) then
			return false, nil, claimMayBeOwned
		end
		local nonceOk, claimNonce = pcall(Util.NewUid)
		if not nonceOk then
			warn("[DataStoreLockHelper] Claim setup error:", tostring(claimNonce))
			break
		end
		local rejected: any = nil
		local ok, updated = pcall(function()
			return store:UpdateAsync(key, function(oldData: any)
				local now = os.time()
				if oldData == nil then
					local fresh = GameConfig.CreateDefaultProfile() :: any
					fresh.activeSessionId = myToken
					fresh.lockTimestamp = now
					fresh.saveSeq = 1
					fresh.lastWriteNonce = claimNonce
					return fresh
				end
				if Validator.Validate(oldData) ~= nil then
					rejected = Util.DeepCopy(oldData)
					return nil
				end
				local holder = oldData.activeSessionId
				local lockAge = now - (tonumber(oldData.lockTimestamp) or 0)
				if holder == nil or holder == myToken or lockAge > GameConfig.SESSION_LOCK_EXPIRE_SEC then
					oldData.activeSessionId = myToken
					oldData.lockTimestamp = now
					oldData.saveSeq = tonumber(oldData.saveSeq) or 0
					oldData.lastWriteNonce = claimNonce
					return oldData
				end
				return nil
			end)
		end)
		claimMayBeOwned = not ok or (type(updated) == "table" and updated.activeSessionId == myToken)
		if ok and updated == nil and rejected ~= nil then return false, rejected, false end
		if ok and type(updated) == "table" and updated.activeSessionId == myToken and updated.lastWriteNonce == claimNonce then
			return true, updated, true
		end
		if attempt < 3 then
			task.wait(1.5)
		end
	end
	return false, nil, claimMayBeOwned
end

return DataStoreLockHelper
