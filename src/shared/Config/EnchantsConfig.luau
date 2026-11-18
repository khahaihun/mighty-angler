--!strict
-- EnchantsConfig.luau: 6 Dong Phu Phep Co Dai danh rieng cho 3 Can Exclusive (cong khai % xac suat chuan Policy Roblox)

local Types = require(script.Parent.Parent.Types)
local Util = require(script.Parent.Parent.Util)

local EnchantsConfig = {}

EnchantsConfig.ROLL_REL_COST = 1
EnchantsConfig.ROLL_GEM_COST = 75

EnchantsConfig.List = {
	{
		id = "swift_caster",
		name = "Swift Caster",
		rarity = "Rare",
		chance = 0.28,
		color = Color3.fromRGB(74, 186, 255),
		lureBonus = 0.35,
		luckBonus = 0.00,
		controlBonus = 0.00,
		steadinessBonus = 0.00,
		mutationBonus = 0.00,
		titanWeightFactor = 1.00,
		midasSellBonus = 1.00,
		description = "+35% Lure Speed (fish bite significantly faster!)",
	},
	{
		id = "iron_control",
		name = "Iron Control",
		rarity = "Rare",
		chance = 0.26,
		color = Color3.fromRGB(92, 232, 152),
		lureBonus = 0.00,
		luckBonus = 0.00,
		controlBonus = 0.10,
		steadinessBonus = 0.20,
		mutationBonus = 0.00,
		titanWeightFactor = 1.00,
		midasSellBonus = 1.00,
		description = "+10% Catch Bar Width & +20% Steadiness (slower needle!)",
	},
	{
		id = "sea_fortune",
		name = "Sea Fortune",
		rarity = "Epic",
		chance = 0.20,
		color = Color3.fromRGB(196, 108, 255),
		lureBonus = 0.00,
		luckBonus = 0.65,
		controlBonus = 0.00,
		steadinessBonus = 0.00,
		mutationBonus = 0.00,
		titanWeightFactor = 1.00,
		midasSellBonus = 1.00,
		description = "+65% Rod Luck for rare, legendary & boss catches!",
	},
	{
		id = "titan_line",
		name = "Titan Line",
		rarity = "Legendary",
		chance = 0.13,
		color = Color3.fromRGB(255, 196, 56),
		lureBonus = 0.00,
		luckBonus = 0.00,
		controlBonus = 0.00,
		steadinessBonus = 0.00,
		mutationBonus = 0.00,
		titanWeightFactor = 1.45,
		midasSellBonus = 1.00,
		description = "2.5x Big/Giant/Titanic chance & 1.45x Catch Weight (up to 125% Rod Max Kg)!",
	},
	{
		id = "abyssal_mutagen",
		name = "Abyssal Mutagen",
		rarity = "Legendary",
		chance = 0.09,
		color = Color3.fromRGB(118, 248, 255),
		lureBonus = 0.00,
		luckBonus = 0.00,
		controlBonus = 0.00,
		steadinessBonus = 0.00,
		mutationBonus = 0.85,
		titanWeightFactor = 1.00,
		midasSellBonus = 1.00,
		description = "+85% Mutation Chance for Shiny, Golden & Cosmic catches!",
	},
	{
		id = "midas_sovereign",
		name = "Midas Sovereign",
		rarity = "Mythic",
		chance = 0.04,
		color = Color3.fromRGB(255, 86, 178),
		lureBonus = 0.00,
		luckBonus = 0.40,
		controlBonus = 0.00,
		steadinessBonus = 0.00,
		mutationBonus = 0.00,
		titanWeightFactor = 1.00,
		midasSellBonus = 1.30,
		description = "+40% Luck, 1.30x Fish Value & 20% chance to upgrade None/Shiny to Golden!",
	},
} :: { Types.EnchantDef }

EnchantsConfig.ById = {} :: { [string]: Types.EnchantDef }
for _, e in ipairs(EnchantsConfig.List) do
	EnchantsConfig.ById[e.id] = e
end

function EnchantsConfig.RollEnchant(excludeId: string?): Types.EnchantDef
	local pool: { Types.EnchantDef } = {}
	for _, e in ipairs(EnchantsConfig.List) do
		if e.id ~= excludeId then
			table.insert(pool, e)
		end
	end
	if #pool == 0 then
		pool = EnchantsConfig.List
	end
	return Util.PickWeighted(pool, function(item: Types.EnchantDef): number
		return item.chance
	end)
end

return EnchantsConfig
