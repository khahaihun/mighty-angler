--!strict
-- BaitConfig.luau: 4 loai Moi cau mua bang Gold (tieu hao 1 vien moi lan cau ca thanh cong)

local Types = require(script.Parent.Parent.Types)

local BaitConfig = {}

BaitConfig.List = {
	{
		id = "worm_bait",
		order = 1,
		name = "Worm Bait",
		priceGold = 125, -- Goi 5 vien (25 Gold / vien)
		packSize = 5,
		luckBonus = 0.25,
		bossChanceMult = 1.0,
		mutationBonus = 0.0,
		color = Color3.fromRGB(132, 224, 98),
		description = "+25% Luck per cast",
	},
	{
		id = "shiny_bait",
		order = 2,
		name = "Shiny Bait",
		priceGold = 1000, -- Goi 5 vien (200 Gold / vien)
		packSize = 5,
		luckBonus = 0.60,
		bossChanceMult = 1.0,
		mutationBonus = 0.15,
		color = Color3.fromRGB(86, 224, 255),
		description = "+60% Luck, +15% Mutation",
	},
	{
		id = "boss_bait",
		order = 3,
		name = "Boss Bait",
		priceGold = 7500, -- Goi 5 vien (1,500 Gold / vien)
		packSize = 5,
		luckBonus = 0.40,
		bossChanceMult = 3.0,
		mutationBonus = 0.0,
		color = Color3.fromRGB(255, 92, 86),
		description = "+40% Luck, 3x Boss Chance!",
	},
	{
		id = "cosmic_bait",
		order = 4,
		name = "Cosmic Bait",
		priceGold = 40000, -- Goi 5 vien (8,000 Gold / vien)
		packSize = 5,
		luckBonus = 1.20,
		bossChanceMult = 1.5,
		mutationBonus = 0.50,
		color = Color3.fromRGB(228, 108, 255),
		description = "+120% Luck, +50% Mutation, 1.5x Boss",
	},
} :: { Types.BaitDef }

BaitConfig.ById = {} :: { [string]: Types.BaitDef }
for _, b in ipairs(BaitConfig.List) do
	BaitConfig.ById[b.id] = b
end

return BaitConfig
