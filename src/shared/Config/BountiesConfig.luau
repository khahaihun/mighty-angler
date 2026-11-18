--!strict
-- BountiesConfig.luau: Hop dong Thu Thap Ca (Fish Bounties) tai Old Man Finn de doi Gems, Enchant Relics & Potions

local Types = require(script.Parent.Parent.Types)

local BountiesConfig = {}

BountiesConfig.RELIC_TRIDENT_GEM_COST = 800
BountiesConfig.RELIC_TRIDENT_MIN_BOSS_ISLAND = 3
BountiesConfig.VOID_SCYTHE_GEM_COST = 2200
BountiesConfig.VOID_SCYTHE_WHIRLPOOL_CHANCE = 0.002

BountiesConfig.List = {
	{
		id = "bounty_sunny_epic",
		title = "Harbor Specimen Request",
		islandReq = 1,
		rarityReq = "Epic",
		minWeight = 12,
		mutationReq = nil,
		gemReward = 45,
		relicReward = 1,
		potionReward = "lucky_elixir_s",
		description = "Turn in any Epic+ fish weighing at least 12.0 kg.",
	},
	{
		id = "bounty_mutated_rare",
		title = "Mutated Curiosity Study",
		islandReq = 2,
		rarityReq = "Rare",
		minWeight = 15,
		mutationReq = "AnyMutated",
		gemReward = 95,
		relicReward = 1,
		potionReward = "gold_draught_s",
		description = "Requires Island 2 unlocked: Turn in any Mutated (Shiny/Golden/Cosmic) Rare+ fish >= 15 kg.",
	},
	{
		id = "bounty_deep_boss",
		title = "Leviathan Trophy Commission",
		islandReq = 3,
		rarityReq = "Boss",
		minWeight = 500,
		mutationReq = nil,
		gemReward = 240,
		relicReward = 3,
		potionReward = "lucky_elixir_l",
		description = "Requires Island 3 unlocked: Turn in any Boss fish weighing at least 500.0 kg.",
	},
} :: { Types.BountyDef }

BountiesConfig.ById = {} :: { [string]: Types.BountyDef }
for _, b in ipairs(BountiesConfig.List) do
	BountiesConfig.ById[b.id] = b
end

return BountiesConfig
