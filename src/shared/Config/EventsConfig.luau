--!strict
-- EventsConfig.luau: 5 Su kien toan Server moi 30 phut (keo dai 5 phut, tang 1 thuoc Small cho nguoi online)

export type ServerEventDef = {
	id: string,
	name: string,
	description: string,
	giftPotionId: string,
	luckAdd: number,
	mutationAdd: number,
	strengthAdd: number,
	sellAdd: number,
	biteSpeedAdd: number,
}

local EventsConfig = {}

EventsConfig.CYCLE_INTERVAL_SEC = 1800 -- 30 phut
EventsConfig.ACTIVE_DURATION_SEC = 300 -- 5 phut

EventsConfig.List = {
	{
		id = "lucky_tide",
		name = "🌊 Lucky Tide",
		description = "2x Rare Fish Luck Server-Wide!",
		giftPotionId = "lucky_elixir_s",
		luckAdd = 1.0,
		mutationAdd = 0,
		strengthAdd = 0,
		sellAdd = 0,
		biteSpeedAdd = 0,
	},
	{
		id = "mutation_surge",
		name = "🔮 Mutation Surge",
		description = "3x Fish Mutation Chance!",
		giftPotionId = "mutagen_vial_s",
		luckAdd = 0,
		mutationAdd = 2.0,
		strengthAdd = 0,
		sellAdd = 0,
		biteSpeedAdd = 0,
	},
	{
		id = "iron_will",
		name = "🔥 Iron Will",
		description = "2x Gym & Fishing Strength!",
		giftPotionId = "titan_brew_s",
		luckAdd = 0,
		mutationAdd = 0,
		strengthAdd = 1.0,
		sellAdd = 0,
		biteSpeedAdd = 0,
	},
	{
		id = "golden_shoal",
		name = "🪙 Golden Shoal",
		description = "2x Gold From Fish Sales!",
		giftPotionId = "gold_draught_s",
		luckAdd = 0,
		mutationAdd = 0,
		strengthAdd = 0,
		sellAdd = 1.0,
		biteSpeedAdd = 0,
	},
	{
		id = "rapid_waters",
		name = "⚡ Rapid Waters",
		description = "2x Faster Fish Bite Speed!",
		giftPotionId = "swift_tonic_s",
		luckAdd = 0,
		mutationAdd = 0,
		strengthAdd = 0,
		sellAdd = 0,
		biteSpeedAdd = 1.0,
	},
} :: { ServerEventDef }

return EventsConfig
