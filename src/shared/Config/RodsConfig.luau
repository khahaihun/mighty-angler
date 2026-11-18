--!strict
-- RodsConfig.luau: 6 Can thuong (5 chi so) + 3 Can Exclusive (115% / 122% / 130% scaling theo Best-Owned Normal Rod)

local Types = require(script.Parent.Parent.Types)

local RodsConfig = {}

RodsConfig.NormalList = {
	{
		id = "Twig",
		order = 1,
		name = "Twig Rod",
		priceGold = 0,
		strengthReq = 0,
		power = 1,
		maxWeight = 15,
		lureSpeed = 0.00,
		luckBonus = 0.00,
		controlBonus = 0.00,
		steadiness = 0.00,
		rodColor = Color3.fromRGB(158, 108, 66),
		accentColor = Color3.fromRGB(115, 200, 95),
		description = "A humble wooden branch to start your angler journey.",
		isExclusive = false,
	},
	{
		id = "Bamboo",
		order = 2,
		name = "Bamboo Rod",
		priceGold = 500,
		strengthReq = 1500,
		power = 2,
		maxWeight = 65,
		lureSpeed = 0.10,
		luckBonus = 0.15,
		controlBonus = 0.04,
		steadiness = 0.05,
		rodColor = Color3.fromRGB(132, 204, 92),
		accentColor = Color3.fromRGB(245, 224, 122),
		description = "Flexible seasoned bamboo capable of reeling reef sharks.",
		isExclusive = false,
	},
	{
		id = "Carbon",
		order = 3,
		name = "Carbon Fiber Rod",
		priceGold = 5000,
		strengthReq = 12000,
		power = 3,
		maxWeight = 220,
		lureSpeed = 0.22,
		luckBonus = 0.35,
		controlBonus = 0.08,
		steadiness = 0.12,
		rodColor = Color3.fromRGB(48, 58, 76),
		accentColor = Color3.fromRGB(64, 218, 255),
		description = "Precision-engineered carbon shaft built for deep currents.",
		isExclusive = false,
	},
	{
		id = "MysticVine",
		order = 4,
		name = "Mystic Vine Rod",
		priceGold = 45000,
		strengthReq = 90000,
		power = 4,
		maxWeight = 650,
		lureSpeed = 0.35,
		luckBonus = 0.65,
		controlBonus = 0.13,
		steadiness = 0.20,
		rodColor = Color3.fromRGB(118, 62, 184),
		accentColor = Color3.fromRGB(224, 128, 255),
		description = "Infused with glowing swamp spores that attract bog hydras.",
		isExclusive = false,
	},
	{
		id = "MagmaCore",
		order = 5,
		name = "Magma Core Rod",
		priceGold = 350000,
		strengthReq = 650000,
		power = 5,
		maxWeight = 1600,
		lureSpeed = 0.50,
		luckBonus = 1.10,
		controlBonus = 0.18,
		steadiness = 0.30,
		rodColor = Color3.fromRGB(96, 36, 36),
		accentColor = Color3.fromRGB(255, 118, 42),
		description = "Forged in volcanic obsidian to haul molten behemoths.",
		isExclusive = false,
	},
	{
		id = "Celestial",
		order = 6,
		name = "Celestial Starlight Rod",
		priceGold = 2500000,
		strengthReq = 4500000,
		power = 6,
		maxWeight = 5000,
		lureSpeed = 0.70,
		luckBonus = 1.80,
		controlBonus = 0.25,
		steadiness = 0.42,
		rodColor = Color3.fromRGB(238, 234, 255),
		accentColor = Color3.fromRGB(255, 108, 232),
		description = "Woven from cosmic starlight to conquer mythical world serpents.",
		isExclusive = false,
	},
} :: { Types.RodDef }

RodsConfig.ExclusiveList = {
	{
		id = "RelicTrident",
		order = 101,
		name = "Abyssal Relic Trident",
		priceGold = 0,
		strengthReq = 0,
		power = 1,
		maxWeight = 18,
		lureSpeed = 0.05,
		luckBonus = 0.15,
		controlBonus = 0.02,
		steadiness = 0.05,
		rodColor = Color3.fromRGB(36, 128, 168),
		accentColor = Color3.fromRGB(98, 248, 255),
		description = "115% Scaling Exclusive Rod + Ancient Enchant Slot!",
		isExclusive = true,
		scaleFactor = 1.15,
		flatLure = 0.05,
		flatLuck = 0.15,
		flatControl = 0.02,
		flatSteadiness = 0.05,
		unlockHint = "Collector Exchange: 800 Gems + 1 Boss Fish (Island 3+)",
	},
	{
		id = "VoidScythe",
		order = 102,
		name = "Void Reaper Rod",
		priceGold = 0,
		strengthReq = 0,
		power = 1,
		maxWeight = 19,
		lureSpeed = 0.08,
		luckBonus = 0.25,
		controlBonus = 0.04,
		steadiness = 0.08,
		rodColor = Color3.fromRGB(48, 28, 86),
		accentColor = Color3.fromRGB(204, 96, 255),
		description = "122% Scaling Exclusive Rod + Ancient Enchant Slot!",
		isExclusive = true,
		scaleFactor = 1.22,
		flatLure = 0.08,
		flatLuck = 0.25,
		flatControl = 0.04,
		flatSteadiness = 0.08,
		unlockHint = "Exclusive Shop: 2,200 Gems (or 0.2% Whirlpool Drop on Island 4–5)",
	},
	{
		id = "SeraphimDragon",
		order = 103,
		name = "Seraphim Sovereign Rod",
		priceGold = 0,
		strengthReq = 0,
		power = 1,
		maxWeight = 20,
		lureSpeed = 0.12,
		luckBonus = 0.40,
		controlBonus = 0.06,
		steadiness = 0.12,
		rodColor = Color3.fromRGB(255, 224, 152),
		accentColor = Color3.fromRGB(255, 88, 206),
		description = "130% Scaling Ultimate Exclusive Rod + Ancient Enchant Slot!",
		isExclusive = true,
		scaleFactor = 1.30,
		flatLure = 0.12,
		flatLuck = 0.40,
		flatControl = 0.06,
		flatSteadiness = 0.12,
		unlockHint = "Gamepass: Seraphim Dragon Rod",
	},
} :: { Types.RodDef }

-- Giu RodsConfig.List tro vao NormalList de Shop Gold khong bao gio ban nham Exclusive Rod
RodsConfig.List = RodsConfig.NormalList

RodsConfig.ById = {} :: { [string]: Types.RodDef }
for _, rod in ipairs(RodsConfig.NormalList) do
	RodsConfig.ById[rod.id] = rod
end
for _, rod in ipairs(RodsConfig.ExclusiveList) do
	RodsConfig.ById[rod.id] = rod
end

function RodsConfig.Get(rodId: string): Types.RodDef
	return RodsConfig.ById[rodId] or RodsConfig.NormalList[1]
end

function RodsConfig.GetBestNormalRod(ownedRods: { [string]: boolean }?): Types.RodDef
	local best = RodsConfig.NormalList[1]
	if type(ownedRods) ~= "table" then
		return best
	end
	for _, rod in ipairs(RodsConfig.NormalList) do
		if ownedRods[rod.id] and rod.order > best.order then
			best = rod
		end
	end
	return best
end

function RodsConfig.GetNextRod(currentRodId: string, ownedRods: { [string]: boolean }?): Types.RodDef?
	local cur = RodsConfig.Get(currentRodId)
	local baseOrder = if cur.isExclusive then RodsConfig.GetBestNormalRod(ownedRods).order else cur.order
	for _, rod in ipairs(RodsConfig.NormalList) do
		if rod.order == baseOrder + 1 then
			return rod
		end
	end
	return nil
end

function RodsConfig.GetEffectiveStats(
	rodId: string,
	ownedRods: { [string]: boolean }?,
	rodEnchants: { [string]: string }?
): Types.EffectiveRodStats
	local def = RodsConfig.Get(rodId)
	if not def.isExclusive then
		return {
			id = def.id,
			name = def.name,
			power = def.power,
			equipStrengthReq = def.strengthReq,
			masteryBaselineStrength = def.strengthReq,
			maxWeight = def.maxWeight,
			lureSpeed = def.lureSpeed,
			luckBonus = def.luckBonus,
			controlBonus = def.controlBonus,
			steadiness = def.steadiness,
			isExclusive = false,
			enchantId = nil,
			sourceBaseRodName = nil,
		}
	end

	local baseRod = RodsConfig.GetBestNormalRod(ownedRods)
	local sf = def.scaleFactor or 1.15
	local enchantId = if type(rodEnchants) == "table" then rodEnchants[def.id] else nil

	return {
		id = def.id,
		name = def.name,
		power = baseRod.power,
		equipStrengthReq = 0,
		masteryBaselineStrength = baseRod.strengthReq,
		maxWeight = math.max(1, math.floor(baseRod.maxWeight * sf)),
		lureSpeed = baseRod.lureSpeed * sf + (def.flatLure or 0),
		luckBonus = baseRod.luckBonus * sf + (def.flatLuck or 0),
		controlBonus = baseRod.controlBonus + (def.flatControl or 0),
		steadiness = math.min(0.65, baseRod.steadiness + (def.flatSteadiness or 0)),
		isExclusive = true,
		enchantId = enchantId,
		sourceBaseRodName = baseRod.name,
	}
end

return RodsConfig
