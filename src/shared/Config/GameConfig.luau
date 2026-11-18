--!strict
-- GameConfig.luau: Hang so gameplay chung, quyen loi Group/Studio va Profile mau

local Types = require(script.Parent.Parent.Types)

local GameConfig = {}

GameConfig.DATASTORE_NAME = "MightyAngler_Profile_v2"
GameConfig.AUTOSAVE_INTERVAL_SEC = 90
GameConfig.BAG_CAPACITY = 60
GameConfig.MAX_PET_INVENTORY = 80
GameConfig.BASE_PET_EQUIP_SLOTS = 2
GameConfig.BONUS_PET_EQUIP_SLOTS = 2

-- Cau hinh Group Roblox cho Auto-Train mien phi (dien Group ID that truoc khi Publish)
GameConfig.ROBLOX_GROUP_ID = 0
-- Trong Roblox Studio, bat san quyen Auto-Train va Auto-Fish de chu du an test nhanh
GameConfig.DEV_UNLOCK_PERKS_IN_STUDIO = true

-- Thong so cau ca & Minigame
GameConfig.BASE_BITE_MIN_SEC = 1.8
GameConfig.BASE_BITE_MAX_SEC = 4.0
GameConfig.FISHING_MAX_WATER_DIST = 68
GameConfig.STRENGTH_MAX_SPEED_BONUS = 0.20 -- Toi da +20% toc do can cau nho Strength
GameConfig.STRENGTH_MAX_BAR_BONUS = 0.25   -- Toi da +25% do rong thanh Minigame nho Strength

-- Thong so tap Gym
GameConfig.GYM_MANUAL_COOLDOWN_SEC = 0.42
GameConfig.GYM_AUTO_INTERVAL_SEC = 0.62
GameConfig.GYM_STATION_RADIUS = 11.5

-- Bang dot bien ca (Mutations)
GameConfig.Mutations = {
	Cosmic = { name = "Cosmic" :: Types.MutationName, chance = 0.005, multiplier = 12, color = Color3.fromRGB(235, 90, 255) },
	Golden = { name = "Golden" :: Types.MutationName, chance = 0.020, multiplier = 5, color = Color3.fromRGB(255, 208, 60) },
	Shiny = { name = "Shiny" :: Types.MutationName, chance = 0.050, multiplier = 2, color = Color3.fromRGB(110, 245, 255) },
}

GameConfig.RarityOrder = {
	Common = 1,
	Uncommon = 2,
	Rare = 3,
	Epic = 4,
	Legendary = 5,
	Mythic = 6,
	Boss = 7,
}

GameConfig.RarityColors = {
	Common = Color3.fromRGB(178, 188, 202),
	Uncommon = Color3.fromRGB(82, 224, 128),
	Rare = Color3.fromRGB(74, 168, 255),
	Epic = Color3.fromRGB(190, 102, 255),
	Legendary = Color3.fromRGB(255, 196, 56),
	Mythic = Color3.fromRGB(255, 82, 162),
	Boss = Color3.fromRGB(255, 76, 76),
}

function GameConfig.CreateDefaultProfile(): Types.PlayerProfile
	return {
		dataVersion = 1,
		gold = 0,
		gems = 0,
		strength = 0,
		totalStrength = 0,
		rebirths = 0,
		rodId = "Twig",
		ownedRods = { Twig = true },
		unlockedIslands = { ["1"] = true },
		currentIsland = 1,
		fishBag = {},
		potions = {},
		activePotions = {},
		bait = {},
		activeBait = nil,
		gymGearLevel = 0,
		pets = {},
		equippedPetUids = {},
		indexFish = {},
		indexPets = {},
		claimedIndexRewards = {},
		claimedAchievements = {},
		dailyStreak = 0,
		lastDailyClaimDay = 0,
		questDay = 0,
		dailyQuests = {},
		stats = {
			fishCaught = 0,
			rareCaught = 0,
			bossCaught = 0,
			mutationsCaught = 0,
			gymReps = 0,
			goldEarned = 0,
			eggsHatched = 0,
			eventsJoined = 0,
			playTimeSec = 0,
		},
	}
end

return GameConfig
