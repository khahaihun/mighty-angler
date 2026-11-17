--!strict
-- AchievementsConfig.luau: Thanh tuu tu dong thuong Gems/Potions, Nhiem vu hang ngay & Qua diem danh

export type AchievementDef = {
	id: string,
	title: string,
	statKey: "fishCaught" | "rareCaught" | "bossCaught" | "eggsHatched" | "gymReps" | "rebirths",
	target: number,
	gemReward: number,
	potionReward: string?,
}

export type DailyQuestDef = {
	id: string,
	title: string,
	target: number,
	gemReward: number,
	potionReward: string,
}

local AchievementsConfig = {}

AchievementsConfig.INDEX_DISCOVERY_GEMS = 15

AchievementsConfig.List = {
	{ id = "ach_fish_15", title = "First Angler: Catch 15 Fish", statKey = "fishCaught", target = 15, gemReward = 30, potionReward = "lucky_elixir_s" },
	{ id = "ach_fish_100", title = "Seasoned Fisher: Catch 100 Fish", statKey = "fishCaught", target = 100, gemReward = 80, potionReward = "gold_draught_s" },
	{ id = "ach_fish_500", title = "Master Angler: Catch 500 Fish", statKey = "fishCaught", target = 500, gemReward = 220, potionReward = "lucky_elixir_l" },

	{ id = "ach_rare_5", title = "Rare Hunter: Catch 5 Rare+ Fish", statKey = "rareCaught", target = 5, gemReward = 45, potionReward = "mutagen_vial_s" },
	{ id = "ach_rare_35", title = "Deep Tracker: Catch 35 Rare+ Fish", statKey = "rareCaught", target = 35, gemReward = 140, potionReward = "mutagen_vial_l" },

	{ id = "ach_boss_1", title = "Boss Slayer: Catch 1 Island Boss", statKey = "bossCaught", target = 1, gemReward = 100, potionReward = "titan_brew_l" },
	{ id = "ach_boss_10", title = "Leviathan Tamer: Catch 10 Bosses", statKey = "bossCaught", target = 10, gemReward = 300, potionReward = "gold_draught_l" },

	{ id = "ach_gym_50", title = "Warmup Set: Complete 50 Gym Reps", statKey = "gymReps", target = 50, gemReward = 30, potionReward = "titan_brew_s" },
	{ id = "ach_gym_300", title = "Iron Athlete: Complete 300 Gym Reps", statKey = "gymReps", target = 300, gemReward = 95, potionReward = "swift_tonic_s" },
	{ id = "ach_gym_1500", title = "Gym Legend: Complete 1,500 Gym Reps", statKey = "gymReps", target = 1500, gemReward = 250, potionReward = "titan_brew_l" },

	{ id = "ach_egg_1", title = "Pet Pal: Hatch 1 Egg", statKey = "eggsHatched", target = 1, gemReward = 35, potionReward = nil },
	{ id = "ach_egg_15", title = "Collector: Hatch 15 Eggs", statKey = "eggsHatched", target = 15, gemReward = 120, potionReward = "lucky_elixir_s" },
	{ id = "ach_egg_50", title = "Breeder Supreme: Hatch 50 Eggs", statKey = "eggsHatched", target = 50, gemReward = 320, potionReward = "lucky_elixir_l" },

	{ id = "ach_rebirth_1", title = "Ascended I: Rebirth 1 Time", statKey = "rebirths", target = 1, gemReward = 150, potionReward = "gold_draught_l" },
	{ id = "ach_rebirth_5", title = "Ascended V: Rebirth 5 Times", statKey = "rebirths", target = 5, gemReward = 450, potionReward = "mutagen_vial_l" },
} :: { AchievementDef }

AchievementsConfig.DailyQuests = {
	{ id = "q_catch_20", title = "Catch 20 Fish Today", target = 20, gemReward = 45, potionReward = "lucky_elixir_s" },
	{ id = "q_gym_40", title = "Complete 40 Gym Reps Today", target = 40, gemReward = 45, potionReward = "titan_brew_s" },
	{ id = "q_hatch_2", title = "Hatch 2 Pet Eggs Today", target = 2, gemReward = 60, potionReward = "gold_draught_s" },
} :: { DailyQuestDef }

AchievementsConfig.QuestsById = {} :: { [string]: DailyQuestDef }
for _, q in ipairs(AchievementsConfig.DailyQuests) do
	AchievementsConfig.QuestsById[q.id] = q
end

function AchievementsConfig.GetDailyLoginGems(streak: number): number
	return math.min(350, 50 * math.max(1, streak))
end

return AchievementsConfig
