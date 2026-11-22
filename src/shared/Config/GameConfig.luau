--!strict
-- GameConfig.luau: Hang so gameplay chung, SizeTier, Playtime Gifts UTC va Profile v2 mau

local Types = require(script.Parent.Parent.Types)
local Util = require(script.Parent.Parent.Util)

export type PlaytimeGiftDef = {
	slot: number,
	reqSec: number,
	label: string,
	rewardKind: "Gold" | "Gems" | "Potion" | "Bait" | "Relic",
	amount: number,
	itemId: string?,
}

local GameConfig = {}

GameConfig.DATASTORE_NAME = "MightyAngler_Profile_v2"
GameConfig.AUTOSAVE_INTERVAL_SEC = 60
GameConfig.SESSION_LOCK_EXPIRE_SEC = 120
-- Khoa ho so dang ban: thu lai moi 5 giay trong 12 vong dau (1 phut), sau do moi 10 giay.
GameConfig.SESSION_LOCK_RETRY_SEC = 5
GameConfig.SESSION_LOCK_RETRY_SLOW_SEC = 10
GameConfig.SESSION_LOCK_FAST_RETRIES = 12
GameConfig.BAG_CAPACITY = 60
GameConfig.MAX_SOULBOUND_TROPHIES = 12
GameConfig.MAX_PET_INVENTORY = 80
GameConfig.BASE_PET_EQUIP_SLOTS = 2
GameConfig.BONUS_PET_EQUIP_SLOTS = 2

-- Cau hinh Group Roblox cho Auto-Train mien phi (dien Group ID that truoc khi Publish)
GameConfig.ROBLOX_GROUP_ID = 0
GameConfig.DEV_UNLOCK_PERKS_IN_STUDIO = true

-- Thong so cau ca, Perfect Cast & Minigame
GameConfig.BASE_BITE_MIN_SEC = 1.8
GameConfig.BASE_BITE_MAX_SEC = 4.0
GameConfig.MIN_BITE_FLOOR_SEC = 0.55
GameConfig.FISHING_MAX_WATER_DIST = 82
GameConfig.PERFECT_HOLD_MIN = 0.78
GameConfig.PERFECT_HOLD_MAX = 0.95
GameConfig.PERFECT_CAST_LUCK_ADD = 0.25
GameConfig.PERFECT_CAST_LURE_ADD = 0.15
GameConfig.AUTO_FISH_FREE_RECAST_SEC = 1.10
GameConfig.AUTO_FISH_PRO_RECAST_SEC = 0.45
GameConfig.STRENGTH_MAX_SPEED_BONUS = 0.20
GameConfig.STRENGTH_MAX_BAR_BONUS = 0.25
GameConfig.MINIGAME_MAX_WIDTH = 0.68

-- Thong so tap Gym
GameConfig.GYM_MANUAL_COOLDOWN_SEC = 0.42
GameConfig.GYM_AUTO_INTERVAL_SEC = 0.62
GameConfig.GYM_STATION_RADIUS = 11.5

-- Bang 4 bac kich thuoc ca (SizeTiers) de cam tren tay khoe & dinh gia
GameConfig.SizeTiers = {
	{ name = "Titanic", rank = 4, chance = 0.015, weightMult = 2.60, valueMult = 3.00, scaleMult = 2.15, color = Color3.fromRGB(255, 82, 168) },
	{ name = "Giant", rank = 3, chance = 0.065, weightMult = 1.85, valueMult = 1.90, scaleMult = 1.62, color = Color3.fromRGB(255, 196, 56) },
	{ name = "Big", rank = 2, chance = 0.170, weightMult = 1.35, valueMult = 1.35, scaleMult = 1.28, color = Color3.fromRGB(88, 226, 255) },
	{ name = "Normal", rank = 1, chance = 0.750, weightMult = 1.00, valueMult = 1.00, scaleMult = 1.00, color = Color3.fromRGB(196, 206, 222) },
}

GameConfig.SizeTierRank = {
	Normal = 1,
	Big = 2,
	Giant = 3,
	Titanic = 4,
}

-- Bang dot bien ca (Mutations)
GameConfig.Mutations = {
	Cosmic = { name = "Cosmic" :: Types.MutationName, rank = 4, chance = 0.005, multiplier = 12, color = Color3.fromRGB(235, 90, 255) },
	Golden = { name = "Golden" :: Types.MutationName, rank = 3, chance = 0.020, multiplier = 5, color = Color3.fromRGB(255, 208, 60) },
	Shiny = { name = "Shiny" :: Types.MutationName, rank = 2, chance = 0.050, multiplier = 2, color = Color3.fromRGB(110, 245, 255) },
}

GameConfig.MutationRank = {
	None = 1,
	Shiny = 2,
	Golden = 3,
	Cosmic = 4,
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

-- 9 moc Qua Online cong don theo ngay UTC
GameConfig.PlaytimeGifts = {
	{ slot = 1, reqSec = 120, label = "+350 Gold", rewardKind = "Gold", amount = 350 },
	{ slot = 2, reqSec = 300, label = "+15 Glow Worms", rewardKind = "Bait", amount = 15, itemId = "glow_worm" },
	{ slot = 3, reqSec = 600, label = "+25 Gems", rewardKind = "Gems", amount = 25 },
	{ slot = 4, reqSec = 900, label = "1x Lucky Elixir", rewardKind = "Potion", amount = 1, itemId = "lucky_elixir_s" },
	{ slot = 5, reqSec = 1200, label = "+45 Gems", rewardKind = "Gems", amount = 45 },
	{ slot = 6, reqSec = 1800, label = "+15 Coral Shrimp", rewardKind = "Bait", amount = 15, itemId = "coral_shrimp" },
	{ slot = 7, reqSec = 2700, label = "1x Titan Brew", rewardKind = "Potion", amount = 1, itemId = "titan_brew_l" },
	{ slot = 8, reqSec = 3600, label = "+90 Gems", rewardKind = "Gems", amount = 90 },
	{ slot = 9, reqSec = 5400, label = "1x Enchant Relic", rewardKind = "Relic", amount = 1 },
} :: { PlaytimeGiftDef }

function GameConfig.CreateDefaultProfile(): Types.PlayerProfile
	return {
		dataVersion = 2,
		activeSessionId = nil,
		lockTimestamp = 0,
		saveSeq = 0,
		gold = 0,
		gems = 0,
		strength = 0,
		totalStrength = 0,
		rebirths = 0,
		rodId = "Twig",
		ownedRods = { Twig = true },
		rodEnchants = {},
		enchantRelics = 1, -- Tang san 1 vien Relic khoi dau de nguoi choi trai nghiem som khi co Exclusive Rod
		equippedHotbarSlot = 1,
		pinnedFishUids = {},
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
		playtimeDay = Util.GetUtcDayIndex(),
		playtimeTodaySec = 0,
		playtimeClaimedToday = {},
		autoLockRare = true,
		autoLockMutated = true,
		lowGfx = false,
		muteSfx = false,
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
