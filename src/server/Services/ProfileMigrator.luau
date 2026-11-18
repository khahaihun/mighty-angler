--!strict
-- ProfileMigrator.luau: Nang cap PlayerProfile len v2 (Idempotent) & dong bo Leaderstats Roblox

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Util = require(Shared:WaitForChild("Util"))
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local IslandsRegistry = require(Shared:WaitForChild("Config"):WaitForChild("Islands"))

local ProfileMigrator = {}

local fishByIdCache: { [string]: Types.FishDef } = {}
for _, isl in ipairs(IslandsRegistry.List) do
	for _, f in ipairs(isl.fishPool) do
		fishByIdCache[f.id] = f
	end
end

function ProfileMigrator.GetFishDef(fishId: string): Types.FishDef?
	return fishByIdCache[fishId]
end

function ProfileMigrator.MigrateProfileToV2(merged: Types.PlayerProfile)
	merged.unlockedIslands["1"] = true
	merged.ownedRods["Twig"] = true
	if type(merged.pinnedFishUids) ~= "table" then
		merged.pinnedFishUids = {}
	end
	if type(merged.rodEnchants) ~= "table" then
		merged.rodEnchants = {}
	end
	if type(merged.playtimeClaimedToday) ~= "table" then
		merged.playtimeClaimedToday = {}
	end

	for _, entry in ipairs(merged.fishBag) do
		local rawEntry: any = entry
		rawEntry.originalValue = tonumber(rawEntry.originalValue) or math.max(1, tonumber(rawEntry.sellValue) or 1)
		rawEntry.sizeTier = if type(rawEntry.sizeTier) == "string" then rawEntry.sizeTier else "Normal"
		rawEntry.midasBonus = tonumber(rawEntry.midasBonus) or 1.0
		rawEntry.soulbound = (rawEntry.soulbound == true)
		if rawEntry.soulbound then
			rawEntry.sellValue = 0
		end
		if rawEntry.locked == nil then
			local def = fishByIdCache[entry.fishId]
			local isHighRarity = def ~= nil and (def.rarity == "Legendary" or def.rarity == "Boss")
			rawEntry.locked = isHighRarity or (entry.mutation ~= "None")
		else
			rawEntry.locked = (rawEntry.locked == true)
		end
	end

	local today = Util.GetUtcDayIndex()
	if merged.playtimeDay ~= today then
		merged.playtimeDay = today
		merged.playtimeTodaySec = 0
		merged.playtimeClaimedToday = {}
	end
	merged.dataVersion = 2
end

function ProfileMigrator.SanitizeLoadedProfile(raw: any): Types.PlayerProfile
	local defaults = GameConfig.CreateDefaultProfile()
	if type(raw) ~= "table" then
		ProfileMigrator.MigrateProfileToV2(defaults)
		return defaults
	end
	local merged = Util.Reconcile(raw, defaults :: any) :: Types.PlayerProfile
	ProfileMigrator.MigrateProfileToV2(merged)
	return merged
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
