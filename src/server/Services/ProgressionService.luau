--!strict
-- ProgressionService.luau: Quan ly Rebirth, So Index (Fish & Pet), Achievements, Qua Hang Ngay & Nhiem Vu Ngay

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))
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
local RodVisuals = require(script.Parent.Parent.World.RodVisuals)

local ProgressionService = {}

local function ensureDailyQuestsFresh(profile: Types.PlayerProfile)
	local today = Util.GetUtcDayIndex()
	if profile.questDay ~= today then
		profile.questDay = today
		profile.dailyQuests = {}
		for _, q in ipairs(AchievementsConfig.DailyQuests) do
			profile.dailyQuests[q.id] = {
				id = q.id,
				progress = 0,
				claimed = false,
			}
		end
	else
		for _, q in ipairs(AchievementsConfig.DailyQuests) do
			if not profile.dailyQuests[q.id] then
				profile.dailyQuests[q.id] = {
					id = q.id,
					progress = 0,
					claimed = false,
				}
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
			local curVal = 0
			if ach.statKey == "rebirths" then
				curVal = profile.rebirths
			else
				curVal = (profile.stats :: any)[ach.statKey] or 0
			end
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

local function handleDoRebirth(player: Player)
	local profile = DataService.Get(player)
	if not profile then
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
	FishingService.CancelSession(player, true)

	-- Reset tien trinh Gold/Strength/Rod/Map/Bait/Gear; GIU Gems, Pets, Potions, Index, Achievements
	profile.gold = 0
	profile.strength = 0
	profile.rodId = "Twig"
	profile.ownedRods = { Twig = true }
	profile.unlockedIslands = { ["1"] = true }
	profile.currentIsland = 1
	table.clear(profile.fishBag)
	table.clear(profile.bait)
	profile.activeBait = nil
	profile.gymGearLevel = 0
	profile.rebirths += 1

	CurrencyService.AddGems(player, gemReward, true)
	ShopAndItemsService.GrantPotion(player, "lucky_elixir_s", 1, false)
	ShopAndItemsService.GrantPotion(player, "titan_brew_s", 1, false)
	ShopAndItemsService.GrantPotion(player, "gold_draught_l", 1, false)

	IslandService.TeleportCharacterToIsland(player, 1)
	RodVisuals.EquipRodOnCharacter(player, "Twig")
	DataService.MarkDirty(player)

	CurrencyService.PushCurrencies(player)
	ShopAndItemsService.PushInventory(player)
	Net.FireClient(player, Net.ServerToClient.BagUpdated, { fishBag = profile.fishBag })
	Net.FireClient(player, Net.ServerToClient.IslandChanged, {
		islandId = 1,
		unlockedIslands = profile.unlockedIslands,
	})

	evaluateAchievements(player, profile)
	ProgressionService.PushProgression(player)

	local newMult = RebirthConfig.GetPermanentMultiplier(profile.rebirths)
	Net.FireAllClients(Net.ServerToClient.Toast, {
		kind = "Epic",
		text = string.format("✨ %s Rebirthed to Rank %d (%.1fx Multiplier)!", player.DisplayName, profile.rebirths, newMult),
	})
end

local function handleClaimDaily(player: Player)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	local today = Util.GetUtcDayIndex()
	if profile.lastDailyClaimDay >= today then
		Net.FireClient(player, Net.ServerToClient.Toast, {
			kind = "Info",
			text = "Already claimed today's Login Reward! Come back tomorrow.",
		})
		return
	end

	if profile.lastDailyClaimDay == today - 1 then
		profile.dailyStreak += 1
	else
		profile.dailyStreak = 1
	end
	profile.lastDailyClaimDay = today

	local gemAmt = AchievementsConfig.GetDailyLoginGems(profile.dailyStreak)
	CurrencyService.AddGems(player, gemAmt, true)
	local randPot = PotionsConfig.SmallIds[math.random(1, #PotionsConfig.SmallIds)]
	ShopAndItemsService.GrantPotion(player, randPot, 1, false)

	DataService.MarkDirty(player)
	ProgressionService.PushProgression(player)

	Net.FireClient(player, Net.ServerToClient.Toast, {
		kind = "Success",
		text = string.format("🎁 Day %d Login Reward: +%d Gems + 1 Potion!", profile.dailyStreak, gemAmt),
	})
end

local function handleClaimQuest(player: Player, questId: string)
	local profile = DataService.Get(player)
	local qDef = AchievementsConfig.QuestsById[questId]
	if not profile or not qDef then
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

	Net.FireClient(player, Net.ServerToClient.Toast, {
		kind = "Success",
		text = string.format("✅ Quest Claimed: +%d Gems + Potion!", qDef.gemReward),
	})
end

function ProgressionService.Init()
	DataService.OnProfileLoaded(function(player: Player, profile: Types.PlayerProfile)
		ensureDailyQuestsFresh(profile)
		ProgressionService.PushProgression(player)
	end)

	Net.OnServerEvent(Net.ClientToServer.RequestInitialState, function(player: Player)
		ProgressionService.PushProgression(player)
	end)

	FishingService.OnFishCaught(function(player: Player, fishDef: Types.FishDef, _mut: Types.MutationName)
		local profile = DataService.Get(player)
		if not profile then
			return
		end
		awardFirstDiscoveryIfNeeded(player, profile, "fish_" .. fishDef.id, fishDef.name)
		incrementDailyQuest(profile, "q_catch_20", 1)
		evaluateAchievements(player, profile)
		ProgressionService.PushProgression(player)
	end)

	GymService.OnGymRepCompleted(function(player: Player, _gained: number)
		local profile = DataService.Get(player)
		if not profile then
			return
		end
		incrementDailyQuest(profile, "q_gym_40", 1)
		evaluateAchievements(player, profile)
		if profile.stats.gymReps % 5 == 0 then
			ProgressionService.PushProgression(player)
		end
	end)

	PetsService.OnPetHatched(function(player: Player, petDef: Types.PetDef)
		local profile = DataService.Get(player)
		if not profile then
			return
		end
		awardFirstDiscoveryIfNeeded(player, profile, "pet_" .. petDef.id, petDef.name)
		incrementDailyQuest(profile, "q_hatch_2", 1)
		evaluateAchievements(player, profile)
		ProgressionService.PushProgression(player)
	end)

	Net.OnServerEvent(Net.ClientToServer.DoRebirth, handleDoRebirth)
	Net.OnServerEvent(Net.ClientToServer.ClaimDailyReward, handleClaimDaily)
	Net.OnServerEvent(Net.ClientToServer.ClaimQuest, function(player: Player, rawId: any)
		if type(rawId) == "string" then
			handleClaimQuest(player, rawId)
		end
	end)
end

return ProgressionService
