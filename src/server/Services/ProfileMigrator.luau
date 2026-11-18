--!strict
-- ProfileMigrator.luau: Kiem tra Schema/Version an toan, Migration v2 Idempotent & dong bo Leaderstats

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Util = require(Shared:WaitForChild("Util"))
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local IslandsRegistry = require(Shared:WaitForChild("Config"):WaitForChild("Islands"))

local ProfileMigrator = {}

local CURRENT_SCHEMA_VERSION = 2

local fishByIdCache: { [string]: Types.FishDef } = {}
for _, isl in ipairs(IslandsRegistry.List) do
	for _, f in ipairs(isl.fishPool) do
		fishByIdCache[f.id] = f
	end
end

function ProfileMigrator.GetFishDef(fishId: string): Types.FishDef?
	return fishByIdCache[fishId]
end

local function ensureTableField(parent: { [string]: any }, key: string, fallback: { [any]: any })
	if type(parent[key]) ~= "table" then
		parent[key] = Util.DeepCopy(fallback)
	end
end

function ProfileMigrator.RefreshUtcPlaytimeIfNewDay(profile: Types.PlayerProfile): boolean
	local today = Util.GetUtcDayIndex()
	if profile.playtimeDay ~= today then
		profile.playtimeDay = today
		profile.playtimeTodaySec = 0
		profile.playtimeClaimedToday = {}
		return true
	end
	return false
end

function ProfileMigrator.MigrateProfileToV2(merged: Types.PlayerProfile)
	local rawTbl: { [string]: any } = merged :: any
	ensureTableField(rawTbl, "ownedRods", { Twig = true })
	ensureTableField(rawTbl, "unlockedIslands", { ["1"] = true })
	ensureTableField(rawTbl, "fishBag", {})
	ensureTableField(rawTbl, "potions", {})
	ensureTableField(rawTbl, "activePotions", {})
	ensureTableField(rawTbl, "bait", {})
	ensureTableField(rawTbl, "pets", {})
	ensureTableField(rawTbl, "equippedPetUids", {})
	ensureTableField(rawTbl, "pinnedFishUids", {})
	ensureTableField(rawTbl, "rodEnchants", {})
	ensureTableField(rawTbl, "indexFish", {})
	ensureTableField(rawTbl, "indexPets", {})
	ensureTableField(rawTbl, "claimedIndexRewards", {})
	ensureTableField(rawTbl, "claimedAchievements", {})
	ensureTableField(rawTbl, "dailyQuests", {})
	ensureTableField(rawTbl, "playtimeClaimedToday", {})
	ensureTableField(rawTbl, "stats", GameConfig.CreateDefaultProfile().stats :: any)

	merged.unlockedIslands["1"] = true
	merged.ownedRods["Twig"] = true

	local cleanBag: { Types.CaughtFish } = {}
	for _, entry in ipairs(merged.fishBag) do
		if type(entry) == "table" and type(entry.fishId) == "string" then
			local rawEntry: any = entry
			rawEntry.uid = if type(rawEntry.uid) == "string" and rawEntry.uid ~= "" then rawEntry.uid else Util.NewUid()
			rawEntry.weight = math.max(0.1, tonumber(rawEntry.weight) or 1.0)
			rawEntry.sellValue = math.max(0, tonumber(rawEntry.sellValue) or 1)
			rawEntry.originalValue = math.max(1, tonumber(rawEntry.originalValue) or math.max(1, rawEntry.sellValue))
			rawEntry.sizeTier = if type(rawEntry.sizeTier) == "string" and GameConfig.SizeTierRank[rawEntry.sizeTier] then rawEntry.sizeTier else "Normal"
			rawEntry.mutation = if type(rawEntry.mutation) == "string" and GameConfig.MutationRank[rawEntry.mutation] then rawEntry.mutation else "None"
			rawEntry.midasBonus = math.max(1.0, tonumber(rawEntry.midasBonus) or 1.0)
			rawEntry.soulbound = (rawEntry.soulbound == true)

			if rawEntry.soulbound then
				rawEntry.sellValue = 0
				rawEntry.locked = true
			elseif rawEntry.locked == nil then
				local def = fishByIdCache[entry.fishId]
				local isHighRarity = def ~= nil and (def.rarity == "Legendary" or def.rarity == "Boss")
				rawEntry.locked = isHighRarity or (rawEntry.mutation ~= "None")
			else
				rawEntry.locked = (rawEntry.locked == true)
			end
			table.insert(cleanBag, rawEntry :: Types.CaughtFish)
		end
	end
	merged.fishBag = cleanBag

	if (tonumber(merged.dataVersion) or 1) < CURRENT_SCHEMA_VERSION then
		merged.dataVersion = CURRENT_SCHEMA_VERSION
	end
	ProfileMigrator.RefreshUtcPlaytimeIfNewDay(merged)
end

-- Tra ve (profile, quarantineReason): neu quarantineReason ~= nil thi DataService bat che do Read-Only de bao ve du lieu goc!
function ProfileMigrator.SanitizeLoadedProfile(raw: any): (Types.PlayerProfile, string?)
	local defaults = GameConfig.CreateDefaultProfile()
	if raw == nil then
		ProfileMigrator.MigrateProfileToV2(defaults)
		return defaults, nil
	end
	if type(raw) ~= "table" then
		ProfileMigrator.MigrateProfileToV2(defaults)
		return defaults, "CorruptRootType"
	end
	local ver = tonumber(raw.dataVersion) or 1
	if ver > CURRENT_SCHEMA_VERSION then
		ProfileMigrator.MigrateProfileToV2(defaults)
		return defaults, "NewerSchemaVersion"
	end

	local copyRaw = Util.DeepCopy(raw)
	local merged = Util.Reconcile(copyRaw, defaults :: any) :: Types.PlayerProfile
	local ok = pcall(function()
		ProfileMigrator.MigrateProfileToV2(merged)
	end)
	if not ok then
		ProfileMigrator.MigrateProfileToV2(defaults)
		return defaults, "MigrationException"
	end
	return merged, nil
end

function ProfileMigrator.SetupLeaderstats(player: Player, profile: Types.PlayerProfile)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	ls.Parent = player

	local strVal = Instance.new("StringValue")
	strVal.Name = "Strength"
	strVal.Value = Util.FormatNumber(profile.strength)
	strVal.Parent = ls

	local goldVal = Instance.new("StringValue")
	goldVal.Name = "Gold"
	goldVal.Value = Util.FormatNumber(profile.gold)
	goldVal.Parent = ls

	local rebVal = Instance.new("IntValue")
	rebVal.Name = "Rebirths"
	rebVal.Value = profile.rebirths
	rebVal.Parent = ls
end

function ProfileMigrator.SyncLeaderstats(player: Player, profile: Types.PlayerProfile?)
	local ls = if profile then player:FindFirstChild("leaderstats") else nil
	if not profile or not ls then
		return
	end
	local strVal = ls:FindFirstChild("Strength")
	if strVal and strVal:IsA("StringValue") then
		strVal.Value = Util.FormatNumber(profile.strength)
	end
	local goldVal = ls:FindFirstChild("Gold")
	if goldVal and goldVal:IsA("StringValue") then
		goldVal.Value = Util.FormatNumber(profile.gold)
	end
	local rebVal = ls:FindFirstChild("Rebirths")
	if rebVal and rebVal:IsA("IntValue") then
		rebVal.Value = profile.rebirths
	end
end

return ProfileMigrator
