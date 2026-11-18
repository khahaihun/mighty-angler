--!strict
-- Mot snapshot/nonce bat bien cho moi lan ghi; doi chieu phan hoi mat bang doc khong cache.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Util = require(Shared:WaitForChild("Util"))

local ProfileWriteHelper = {}
export type Operation = {
	target: Types.PlayerProfile, snapshot: any, token: string, nonce: string,
	expectedSeq: number, nextSeq: number, release: boolean, revision: number,
}

function ProfileWriteHelper.Create(profile: Types.PlayerProfile, token: string, release: boolean, revision: number): Operation
	return { target = profile, snapshot = Util.DeepCopy(profile), token = token, nonce = Util.NewUid(),
		expectedSeq = profile.saveSeq, nextSeq = profile.saveSeq + 1, release = release, revision = revision }
end

local function confirms(doc: any, op: Operation): boolean
	if type(doc) ~= "table" then return false end
	if op.release then
		local receipt = doc.lastReleaseReceipt
		return type(receipt) == "table" and receipt.token == op.token
			and receipt.nonce == op.nonce and receipt.saveSeq == op.nextSeq
	end
	return doc.activeSessionId == op.token and doc.lastWriteNonce == op.nonce and doc.saveSeq == op.nextSeq
end

function ProfileWriteHelper.Attempt(store: DataStore, key: string, op: Operation): (string, number)
	local ok, saved = pcall(function()
		return store:UpdateAsync(key, function(old: any, keyInfo: DataStoreKeyInfo?)
			if confirms(old, op) then return nil end -- Da ghi: khong ghi lai/khong keo dai lease.
			if type(old) ~= "table" or old.activeSessionId ~= op.token or old.saveSeq ~= op.expectedSeq then
				return nil
			end
			local candidate: any = Util.DeepCopy(op.snapshot)
			candidate.saveSeq = op.nextSeq
			candidate.lastWriteNonce = op.nonce
			candidate.activeSessionId = if op.release then nil else op.token
			candidate.lockTimestamp = if op.release then 0 else os.time()
			candidate.lastReleaseReceipt = if op.release
				then { token = op.token, nonce = op.nonce, saveSeq = op.nextSeq }
				else old.lastReleaseReceipt
			return candidate, if keyInfo then keyInfo:GetUserIds() else {}, if keyInfo then keyInfo:GetMetadata() else {}
		end)
	end)
	if ok and confirms(saved, op) then return "Saved", tonumber(saved.lockTimestamp) or 0 end

	local readOk, observed = pcall(function()
		local options = Instance.new("DataStoreGetOptions")
		options.UseCache = false
		return store:GetAsync(key, options)
	end)
	if not readOk then return "TransientError", 0 end
	if confirms(observed, op) then return "Saved", tonumber(observed.lockTimestamp) or 0 end
	if type(observed) ~= "table" or observed.activeSessionId ~= op.token or observed.saveSeq ~= op.expectedSeq then
		return "LostLock", 0
	end
	return "TransientError", 0
end

return ProfileWriteHelper
