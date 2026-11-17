--!strict
-- PotionsConfig.luau: 10 loai Thuoc Buff (5 nhom x 2 cap Small 5 phut / Large 10 phut)

local Types = require(script.Parent.Parent.Types)

local PotionsConfig = {}

PotionsConfig.List = {
	{
		id = "lucky_elixir_s",
		name = "Lucky Elixir (S)",
		kind = "Luck",
		tier = 1,
		bonus = 0.50,
		durationSec = 300,
		color = Color3.fromRGB(88, 232, 132),
		description = "+50% Luck for 5m",
	},
	{
		id = "lucky_elixir_l",
		name = "Lucky Elixir (L)",
		kind = "Luck",
		tier = 2,
		bonus = 1.00,
		durationSec = 600,
		color = Color3.fromRGB(56, 255, 152),
		description = "+100% Luck for 10m",
	},
	{
		id = "titan_brew_s",
		name = "Titan Brew (S)",
		kind = "Strength",
		tier = 1,
		bonus = 0.50,
		durationSec = 300,
		color = Color3.fromRGB(255, 122, 88),
		description = "+50% Strength Gain for 5m",
	},
	{
		id = "titan_brew_l",
		name = "Titan Brew (L)",
		kind = "Strength",
		tier = 2,
		bonus = 1.00,
		durationSec = 600,
		color = Color3.fromRGB(255, 86, 72),
		description = "+100% Strength Gain for 10m",
	},
	{
		id = "gold_draught_s",
		name = "Gold Draught (S)",
		kind = "Sell",
		tier = 1,
		bonus = 0.50,
		durationSec = 300,
		color = Color3.fromRGB(255, 212, 68),
		description = "+50% Fish Sell Gold for 5m",
	},
	{
		id = "gold_draught_l",
		name = "Gold Draught (L)",
		kind = "Sell",
		tier = 2,
		bonus = 1.00,
		durationSec = 600,
		color = Color3.fromRGB(255, 192, 42),
		description = "+100% Fish Sell Gold for 10m",
	},
	{
		id = "mutagen_vial_s",
		name = "Mutagen Vial (S)",
		kind = "Mutation",
		tier = 1,
		bonus = 1.00,
		durationSec = 300,
		color = Color3.fromRGB(218, 108, 255),
		description = "+100% Mutation Chance for 5m",
	},
	{
		id = "mutagen_vial_l",
		name = "Mutagen Vial (L)",
		kind = "Mutation",
		tier = 2,
		bonus = 3.00,
		durationSec = 600,
		color = Color3.fromRGB(242, 82, 255),
		description = "+300% Mutation Chance for 10m",
	},
	{
		id = "swift_tonic_s",
		name = "Swift Tonic (S)",
		kind = "Speed",
		tier = 1,
		bonus = 0.25,
		durationSec = 300,
		color = Color3.fromRGB(88, 218, 255),
		description = "+25% Faster Fish Bite for 5m",
	},
	{
		id = "swift_tonic_l",
		name = "Swift Tonic (L)",
		kind = "Speed",
		tier = 2,
		bonus = 0.50,
		durationSec = 600,
		color = Color3.fromRGB(56, 242, 255),
		description = "+50% Faster Fish Bite for 10m",
	},
} :: { Types.PotionDef }

PotionsConfig.ById = {} :: { [string]: Types.PotionDef }
PotionsConfig.SmallIds = {} :: { string }
PotionsConfig.LargeIds = {} :: { string }

for _, p in ipairs(PotionsConfig.List) do
	PotionsConfig.ById[p.id] = p
	if p.tier == 1 then
		table.insert(PotionsConfig.SmallIds, p.id)
	else
		table.insert(PotionsConfig.LargeIds, p.id)
	end
end

return PotionsConfig
