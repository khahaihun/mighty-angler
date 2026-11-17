--!strict
-- GymGearConfig.luau: 4 cap Do tap Gym mua tuan tu bang Gold (nhan Strength vinh vien cho toi khi Rebirth)

local Types = require(script.Parent.Parent.Types)

local GymGearConfig = {}

GymGearConfig.List = {
	{
		level = 1,
		id = "wrist_straps",
		name = "Wrist Straps",
		priceGold = 2500,
		strengthBonus = 0.20,
		color = Color3.fromRGB(108, 226, 132),
		description = "+20% Gym & Fishing Strength Gain",
	},
	{
		level = 2,
		id = "lifting_gloves",
		name = "Pro Lifting Gloves",
		priceGold = 20000,
		strengthBonus = 0.40,
		color = Color3.fromRGB(78, 186, 255),
		description = "+40% Gym & Fishing Strength Gain",
	},
	{
		level = 3,
		id = "power_belt",
		name = "Champion Power Belt",
		priceGold = 150000,
		strengthBonus = 0.75,
		color = Color3.fromRGB(255, 172, 62),
		description = "+75% Gym & Fishing Strength Gain",
	},
	{
		level = 4,
		id = "titan_suit",
		name = "Titan Gravity Suit",
		priceGold = 1000000,
		strengthBonus = 1.20,
		color = Color3.fromRGB(224, 96, 255),
		description = "+120% Gym & Fishing Strength Gain",
	},
} :: { Types.GymGearDef }

GymGearConfig.ByLevel = {} :: { [number]: Types.GymGearDef }
for _, g in ipairs(GymGearConfig.List) do
	GymGearConfig.ByLevel[g.level] = g
end

return GymGearConfig
