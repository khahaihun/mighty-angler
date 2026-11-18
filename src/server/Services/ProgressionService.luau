--!strict
-- ProgressionService.luau: Quan ly Rebirth (giu 12 Soulbound Trophies + Exclusive Rods), Index, Quests, Playtime Gifts & Settings

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local RodsConfig = require(Shared:WaitForChild("Config"):WaitForChild("RodsConfig"))
local RebirthConfig = require(Shared:WaitForChild("Config"):WaitForChild("RebirthConfig"))
local AchievementsConfig = require(Shared:WaitForChild("Config"):WaitForChild("AchievementsConfig"))
local PotionsConfig = require(Shared:WaitForChild("Config"):WaitForChild("PotionsConfig"))

local DataService = require(script.Parent.DataService)
local CurrencyService = require(script.Parent.CurrencyService)
local ShopAndItemsService = require(script.Parent.ShopAndItemsService)
local FishingService = require(script.Parent.FishingService)
local GymService = require(script.Parent.GymService)
local IslandService = require(script.Parent.IslandService)
local PetsService = require(script.Parent.PetsService)

local ProgressionService = {}

local function ensureDailyQuestsFresh(profile: Types.PlayerProfile)
	local today = Util.GetUtcDayIndex()
	if profile.questDay ~= today then
		profile.questDay = today
		profile.dailyQuests = {}
		for _, q in ipairs(AchievementsConfig.DailyQuests) do
			profile.dailyQuests[q.id] = { id = q.id, progress = 0, claimed = false }
		end
	else
		for _, q in ipairs(AchievementsConfig.DailyQuests) do
			if not profile.dailyQuests[q.id] then
				profile.dailyQuests[q.id] = { id = q.id, progress = 0, claimed = false }
			end
		end
	end
end

function ProgressionService.PushProgression(player: Player)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	ensureDailyQuestsFresh(profile)
	local today = Util.GetUtcDayIndex()

	Net.FireClient(player, Net.ServerToClient.ProgressionUpdated, {
		rebirths = profile.rebirths,
		indexFish = profile.indexFish,
		indexPets = profile.indexPets,
		claimedAchievements = profile.claimedAchievements,
		dailyQuests = profile.dailyQuests,
		dailyStreak = profile.dailyStreak,
		canClaimDaily = (profile.lastDailyClaimDay < today),
		playtimeTodaySec = profile.playtimeTodaySec,
		playtimeClaimedToday = profile.playtimeClaimedToday,
		stats = profile.stats,
	})
end

local function incrementDailyQuest(profile: Types.PlayerProfile, questId: string, delta: number)
	ensureDailyQuestsFresh(profile)
	local entry = profile.dailyQuests[questId]
	local qDef = AchievementsConfig.QuestsById[questId]
	if entry and qDef and not entry.claimed then
		entry.progress = math.min(qDef.target, entry.progress + delta)
	end
end

local function evaluateAchievements(player: Player, profile: Types.PlayerProfile)
	local unlockedAny = false
	for _, ach in ipairs(AchievementsConfig.List) do
		if not profile.claimedAchievements[ach.id] then
			local curVal = if ach.statKey == "rebirths" then profile.rebirths else ((profile.stats :: any)[ach.statKey] or 0)
			if curVal >= ach.target then
				profile.claimedAchievements[ach.id] = true
				unlockedAny = true
				CurrencyService.AddGems(player, ach.gemReward, true)
				if ach.potionReward then
					ShopAndItemsService.GrantPotion(player, ach.potionReward, 1, false)
				end
				Net.FireClient(player, Net.ServerToClient.Toast, {
					kind = "Success",
					text = string.format("🏆 Achievement: %s (+%d Gems)!", ach.title, ach.gemReward),
				})
			end
		end
	end
	if unlockedAny then
		DataService.MarkDirty(player)
	end
end

local function awardFirstDiscoveryIfNeeded(player: Player, profile: Types.PlayerProfile, key: string, displayName: string)
	if profile.claimedIndexRewards[key] then
		return
	end
	profile.claimedIndexRewards[key] = true
	local gems = AchievementsConfig.INDEX_DISCOVERY_GEMS
	CurrencyService.AddGems(player, gems, false)
	Net.FireClient(player, Net.ServerToClient.Toast, {
		kind = "Info",
		text = string.format("📖 New Index Discovery: %s (+%d Gems)!", displayName, gems),
	})
end

local function selectSoulboundTrophies(fishBag: { Types.CaughtFish }): ({ Types.CaughtFish }, { [string]: boolean })
	local lockedCandidates: { Types.CaughtFish } = {}
	for _, entry in ipairs(fishBag) do
		if entry.locked == true then
			table.insert(lockedCandidates, entry)
		end
	end
	table.sort(lockedCandidates, function(a: Types.CaughtFish, b: Types.CaughtFish)
		local oa = tonumber(a.originalValue) or a.sellValue
		local ob = tonumber(b.originalValue) or b.sellValue
		if oa ~= ob then
			return oa > ob
		end
		return a.weight > b.weight
	end)

	local kept: { Types.CaughtFish } = {}
	local keptUidSet: { [string]: boolean } = {}
	local limit = math.min(#lockedCandidates, GameConfig.MAX_SOULBOUND_TROPHIES)
	for i = 1, limit do
		local trophy = lockedCandidates[i]
		trophy.soulbound = true
		trophy.sellValue = 0
		table.insert(kept, trophy)
		keptUidSet[trophy.uid] = true
	end
	return kept, keptUidSet
end

local function handleDoRebirth(player: Player)
	local profile = DataService.Get(player)
	if not profile or DataService.IsTransactionLocked(player, true) then
		return
	end

	local reqStr = RebirthConfig.GetStrengthRequirement(profile.rebirths)
	if profile.strength < reqStr then
		Net.FireClient(player, Net.ServerToClient.Toast, {
			kind = "Error",
			text = string.format("Need %s Strength to Rebirth!", Util.FormatNumber(reqStr)),
		})
		return
	end

	local gemReward = RebirthConfig.GetGemReward(profile.rebirths)
	FishingService.CancelSession(player, false)

	-- Giu nguyen cac cay Can Exclusive trong ownedRods va toi da 12 con ca Locked (Soulbound Trophy)
	local nextOwnedRods: { [string]: boolean } = { Twig = true }
	for rId, isOwned in pairs(profile.ownedRods) do
		local def = RodsConfig.ById[rId]
		if isOwned and def and def.isExclusive then
			nextOwnedRods[rId] = true
		end
	end
	local curRodDef = RodsConfig.Get(profile.rodId)
	local nextEquippedRod = if curRodDef.isExclusive and nextOwnedRods[curRodDef.id] then curRodDef.id else "Twig"

	local keptTrophies, keptUidSet = selectSoulboundTrophies(profile.fishBag)
	for slotKey, pinnedUid in pairs(profile.pinnedFishUids) do
		if not keptUidSet[pinnedUid] then
			profile.pinnedFishUids[slotKey] = nil
		end
	end

	profile.gold = 0
	profile.strength = 0
	profile.rodId = nextEquippedRod
	profile.ownedRods = nextOwnedRods
	profile.equippedHotbarSlot = 1
	profile.unlockedIslands = { ["1"] = true }
	profile.currentIsland = 1
	profile.fishBag = keptTrophies
	table.clear(profile.bait)
	profile.activeBait = nil
	profile.gymGearLevel = 0
	profile.rebirths += 1

	CurrencyService.AddGems(player, gemReward, true)
	ShopAndItemsService.GrantPotion(player, "lucky_elixir_s", 1, false)
	ShopAndItemsService.GrantPotion(player, "titan_brew_s", 1, false)
	ShopAndItemsService.GrantPotion(player, "gold_draught_l", 1, false)

	IslandService.TeleportCharacterToIsland(player, 1)
	ShopAndItemsService.SyncCharacterHandVisuals(player)
	DataService.MarkDirty(player)

	CurrencyService.PushCurrencies(player)
	ShopAndItemsService.PushInventory(player)
	CurrencyService.NotifyBagAndHotbarChanged(player, profile)
	Net.FireClient(player, Net.ServerToClient.IslandChanged, {
		islandId = 1,
		unlockedIslands = profile.unlockedIslands,
	})

	evaluateAchievements(player, profile)
	ProgressionService.PushProgression(player)

	local newMult = RebirthConfig.GetPermanentMultiplier(profile.rebirths)
	Net.FireAllClients(Net.ServerToClient.Toast, {
		kind = "Epic",
		text = string.format("✨ %s Rebirthed to Rank %d (%.1fx Multiplier • %d Trophies kept)!", player.DisplayName, profile.rebirths, newMult, #keptTrophies),
	})
end

local function handleClaimDaily(player: Player)
	local profile = DataService.Get(player)
	if not profile or DataService.IsTransactionLocked(player, true) then
		return
	end
	local today = Util.GetUtcDayIndex()
	if profile.lastDailyClaimDay >= today then
		Net.FireClient(player, Net.ServerToClient.Toast, { kind = "Info", text = "Already claimed today's Login Reward!" })
		return
	end
	profile.dailyStreak = if profile.lastDailyClaimDay == today - 1 then (profile.dailyStreak + 1) else 1
	profile.lastDailyClaimDay = today

	local gemAmt = AchievementsConfig.GetDailyLoginGems(profile.dailyStreak)
	CurrencyService.AddGems(player, gemAmt, true)
	local randPot = PotionsConfig.SmallIds[math.random(1, #PotionsConfig.SmallIds)]
	ShopAndItemsService.GrantPotion(player, randPot, 1, false)

	DataService.MarkDirty(player)
	ProgressionService.PushProgression(player)
	Net.FireClient(player, Net.ServerToClient.Toast, { kind = "Success", text = string.format("🎁 Day %d Login Reward: +%d Gems + 1 Potion!", profile.dailyStreak, gemAmt) })
end

local function handleClaimQuest(player: Player, questId: string)
	local profile = DataService.Get(player)
	local qDef = AchievementsConfig.QuestsById[questId]
	if not profile or not qDef or DataService.IsTransactionLocked(player, true) then
		return
	end
	ensureDailyQuestsFresh(profile)
	local entry = profile.dailyQuests[questId]
	if not entry or entry.claimed or entry.progress < qDef.target then
		return
	end

	entry.claimed = true
	CurrencyService.AddGems(player, qDef.gemReward, true)
	ShopAndItemsService.GrantPotion(player, qDef.potionReward, 1, false)
	DataService.MarkDirty(player)
	ProgressionService.PushProgression(player)
	Net.FireClient(player, Net.ServerToClient.Toast, { kind = "Success", text = string.format("✅ Quest Claimed: +%d Gems + Potion!", qDef.gemReward) })
end

local function handleClaimPlaytimeGift(player: Player, slotIdx: number)
	local profile = DataService.Get(player)
	local gDef = GameConfig.PlaytimeGifts[slotIdx]
	if not profile or not gDef or DataService.IsTransactionLocked(player, true) then
		return
	end
	local key = tostring(gDef.slot)
	if profile.playtimeClaimedToday[key] or profile.playtimeTodaySec < gDef.reqSec then
		return
	end

	profile.playtimeClaimedToday[key] = true
	if gDef.rewardKind == "Gold" then CurrencyService.AddGold(player, gDef.amount, true)
	elseif gDef.rewardKind == "Gems" then CurrencyService.AddGems(player, gDef.amount, true)
	elseif gDef.rewardKind == "Potion" and gDef.itemId then ShopAndItemsService.GrantPotion(player, gDef.itemId, gDef.amount, false)
	elseif gDef.rewardKind == "Bait" and gDef.itemId then ShopAndItemsService.GrantBait(player, gDef.itemId, gDef.amount)
	elseif gDef.rewardKind == "Relic" then profile.enchantRelics += gDef.amount; ShopAndItemsService.PushInventory(player) end

	DataService.MarkDirty(player)
	Net.FireClient(player, Net.ServerToClient.PlaytimeUpdated, { playtimeTodaySec = profile.playtimeTodaySec, playtimeClaimedToday = profile.playtimeClaimedToday })
	Net.FireClient(player, Net.ServerToClient.Toast, { kind = "Success", text = "🎁 Playtime Gift Claimed: " .. gDef.label .. "!" })
end

local function handleUpdateSettings(player: Player, patch: any)
	local profile = DataService.Get(player)
	if not profile or type(patch) ~= "table" then return end
	if type(patch.autoLockRare) == "boolean" then profile.autoLockRare = patch.autoLockRare end
	if type(patch.autoLockMutated) == "boolean" then profile.autoLockMutated = patch.autoLockMutated end
	if type(patch.lowGfx) == "boolean" then profile.lowGfx = patch.lowGfx end
	if type(patch.muteSfx) == "boolean" then profile.muteSfx = patch.muteSfx end
	DataService.MarkDirty(player)
	Net.FireClient(player, Net.ServerToClient.SettingsUpdated, {
		autoLockRare = profile.autoLockRare, autoLockMutated = profile.autoLockMutated, lowGfx = profile.lowGfx, muteSfx = profile.muteSfx,
	})
end

function ProgressionService.Init()
	DataService.OnProfileLoaded(function(player: Player, profile: Types.PlayerProfile)
		ensureDailyQuestsFresh(profile)
		ProgressionService.PushProgression(player)
	end)

	Net.OnServerEvent(Net.ClientToServer.RequestInitialState, ProgressionService.PushProgression)

	FishingService.OnFishCaught(function(player: Player, fishDef: Types.FishDef)
		local profile = DataService.Get(player)
		if not profile then return end
		awardFirstDiscoveryIfNeeded(player, profile, "fish_" .. fishDef.id, fishDef.name)
		incrementDailyQuest(profile, "q_catch_20", 1)
		evaluateAchievements(player, profile)
		ProgressionService.PushProgression(player)
	end)

	GymService.OnGymRepCompleted(function(player: Player)
		local profile = DataService.Get(player)
		if not profile then return end
		incrementDailyQuest(profile, "q_gym_40", 1)
		evaluateAchievements(player, profile)
		if profile.stats.gymReps % 5 == 0 then ProgressionService.PushProgression(player) end
	end)

	PetsService.OnPetHatched(function(player: Player, petDef: Types.PetDef)
		local profile = DataService.Get(player)
		if not profile then return end
		awardFirstDiscoveryIfNeeded(player, profile, "pet_" .. petDef.id, petDef.name)
		incrementDailyQuest(profile, "q_hatch_2", 1)
		evaluateAchievements(player, profile)
		ProgressionService.PushProgression(player)
	end)

	Net.OnServerEvent(Net.ClientToServer.DoRebirth, handleDoRebirth)
	Net.OnServerEvent(Net.ClientToServer.ClaimDailyReward, handleClaimDaily)
	Net.OnServerEvent(Net.ClientToServer.ClaimQuest, function(p: Player, id: any) if type(id) == "string" then handleClaimQuest(p, id) end end)
	Net.OnServerEvent(Net.ClientToServer.ClaimPlaytimeGift, function(p: Player, s: any) local n = tonumber(s); if n then handleClaimPlaytimeGift(p, math.floor(n)) end end)
	Net.OnServerEvent(Net.ClientToServer.UpdateSettings, handleUpdateSettings)
end

return ProgressionService
