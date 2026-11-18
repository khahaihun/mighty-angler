--!strict
-- Xac thuc ban goc truoc reconcile/claim/ghi; khong sua, khong loai vat pham loi.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local ProfileValidator = {}

local function number(value: any): boolean
	return type(value) == "number" and value == value and math.abs(value) < math.huge and value >= 0
end
local function text(value: any): boolean return type(value) == "string" and value ~= "" end
local function integer(value: any): boolean return number(value) and value % 1 == 0 end

local function tree(value: any, seen: { [any]: boolean }, depth: number): boolean
	local kind = type(value)
	if kind == "number" then return value == value and math.abs(value) < math.huge end
	if kind ~= "table" then return kind == "boolean" or kind == "string" or kind == "nil" end
	if seen[value] or depth > 16 then return false end
	seen[value] = true
	for key, child in pairs(value) do
		if not (type(key) == "string" or (integer(key) and key >= 1)) or not tree(child, seen, depth + 1) then return false end
	end
	seen[value] = nil
	return true
end

local function fields(raw: any, defaults: any, legacy: boolean, prefix: string): string?
	for key, fallback in pairs(defaults) do
		local value = raw[key]
		if value == nil then
			if not legacy then return prefix .. key .. ":Missing" end
		elseif type(value) ~= type(fallback) then return prefix .. key .. ":Type"
		elseif type(fallback) == "number" and not number(value) then return prefix .. key .. ":Number"
		elseif type(fallback) == "string" and not text(value) then return prefix .. key .. ":String" end
	end
	return nil
end

local function dictionary(raw: any, check: (any) -> boolean): boolean
	for key, value in pairs(raw) do if not text(key) or not check(value) then return false end end
	return true
end

local function dense(raw: any, check: (any) -> boolean): boolean
	local count, maximum = 0, 0
	for key, value in pairs(raw) do
		if not integer(key) or key < 1 or not check(value) then return false end
		count += 1; maximum = math.max(maximum, key)
	end
	return count == maximum
end

function ProfileValidator.Validate(raw: any): string?
	if raw == nil then return nil end
	if type(raw) ~= "table" then return "CorruptRootType" end
	local version = raw.dataVersion
	if version ~= nil and (not integer(version) or version < 1) then return "InvalidVersion" end
	if version and version > 2 then return "NewerSchemaVersion" end
	local legacy = version == nil or version == 1
	if not tree(raw, {}, 0) then return "UnserializableValue" end
	local defaults = GameConfig.CreateDefaultProfile()
	local reason = fields(raw, defaults, legacy, "")
	if reason then return reason end
	for _, key in ipairs({ "saveSeq", "lockTimestamp", "rebirths", "gymGearLevel", "dailyStreak", "lastDailyClaimDay", "questDay", "playtimeDay" }) do
		if raw[key] ~= nil and not integer(raw[key]) then return key .. ":Integer" end
	end
	if raw.currentIsland ~= nil and (not integer(raw.currentIsland) or raw.currentIsland < 1) then return "currentIsland:Range" end
	if raw.equippedHotbarSlot ~= nil and (not integer(raw.equippedHotbarSlot) or raw.equippedHotbarSlot < 0 or raw.equippedHotbarSlot > 5) then return "equippedHotbarSlot:Range" end
	for _, key in ipairs({ "activeSessionId", "activeBait", "lastWriteNonce" }) do
		if raw[key] ~= nil and not text(raw[key]) then return key .. ":String" end
	end
	if raw.stats then
		reason = fields(raw.stats, defaults.stats, legacy, "stats.")
		if reason then return reason end
	end
	local function checkMaps(names: { string }, check: (any) -> boolean): string?
		for _, key in ipairs(names) do
			if raw[key] ~= nil and not dictionary(raw[key], check) then return key .. ":Map" end
		end
		return nil
	end
	reason = checkMaps({ "ownedRods", "unlockedIslands", "claimedIndexRewards", "claimedAchievements", "playtimeClaimedToday" }, function(v) return type(v) == "boolean" end)
		or checkMaps({ "rodEnchants", "pinnedFishUids" }, text)
		or checkMaps({ "potions", "bait", "indexFish", "indexPets" }, number)
	if reason then return reason end
	local seenFish, seenPets = {}, {}
	if raw.fishBag and not dense(raw.fishBag, function(f: any): boolean
		if type(f) ~= "table" or not text(f.fishId) then return false end
		if not number(f.weight) or f.weight <= 0 or not number(f.sellValue) or not GameConfig.MutationRank[f.mutation] then return false end
		if f.uid ~= nil and (not text(f.uid) or seenFish[f.uid]) then return false end
		if not legacy and not text(f.uid) then return false end
		if f.uid then seenFish[f.uid] = true end
		local extras = { originalValue = 1, midasBonus = 1, locked = false, soulbound = false, sizeTier = "Normal" }
		if fields(f, extras, legacy, "fish.") then return false end
		if f.originalValue ~= nil and f.originalValue < 1 then return false end
		if f.midasBonus ~= nil and f.midasBonus < 1 then return false end
		if f.sizeTier ~= nil and not GameConfig.SizeTierRank[f.sizeTier] then return false end
		return true
	end) then return "fishBag:EntriesOrSparseArray" end
	if raw.pets and not dense(raw.pets, function(p: any): boolean
		if type(p) ~= "table" or not text(p.uid) or not text(p.petId) or seenPets[p.uid] then return false end
		seenPets[p.uid] = true; return true
	end) then return "pets:EntriesOrSparseArray" end
	if raw.equippedPetUids and not dense(raw.equippedPetUids, text) then return "equippedPetUids:SparseArray" end
	if raw.activePotions and not dictionary(raw.activePotions, function(p: any): boolean
		return type(p) == "table" and text(p.potionId) and integer(p.tier) and p.tier >= 1 and number(p.expiresAt)
	end) then return "activePotions:Entry" end
	if raw.dailyQuests and not dictionary(raw.dailyQuests, function(q: any): boolean
		return type(q) == "table" and text(q.id) and number(q.progress) and type(q.claimed) == "boolean"
	end) then return "dailyQuests:Entry" end
	if raw.lastReleaseReceipt ~= nil then
		local receipt = raw.lastReleaseReceipt
		if type(receipt) ~= "table" or not text(receipt.token) or not text(receipt.nonce) or not integer(receipt.saveSeq) then return "lastReleaseReceipt:Entry" end
	end
	return nil
end

return ProfileValidator
