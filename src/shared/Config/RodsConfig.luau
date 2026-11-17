--!strict
-- RodsConfig.luau: Cau hinh 6 Can cau khop voi lo trinh 5 Dao Launch

local Types = require(script.Parent.Parent.Types)

local RodsConfig = {}

RodsConfig.List = {
	{
		id = "Twig",
		order = 1,
		name = "Twig Rod",
		priceGold = 0,
		strengthReq = 0,
		power = 1,
		luckBonus = 0.00,
		controlBonus = 0.00,
		rodColor = Color3.fromRGB(158, 108, 66),
		accentColor = Color3.fromRGB(115, 200, 95),
		description = "A humble wooden branch to start your angler journey.",
	},
	{
		id = "Bamboo",
		order = 2,
		name = "Bamboo Rod",
		priceGold = 500,
		strengthReq = 1500,
		power = 2,
		luckBonus = 0.15,
		controlBonus = 0.05,
		rodColor = Color3.fromRGB(132, 204, 92),
		accentColor = Color3.fromRGB(245, 224, 122),
		description = "Flexible seasoned bamboo capable of reeling reef predators.",
	},
	{
		id = "Carbon",
		order = 3,
		name = "Carbon Fiber Rod",
		priceGold = 5000,
		strengthReq = 12000,
		power = 3,
		luckBonus = 0.35,
		controlBonus = 0.10,
		rodColor = Color3.fromRGB(48, 58, 76),
		accentColor = Color3.fromRGB(64, 218, 255),
		description = "Precision-engineered carbon shaft built for deep currents.",
	},
	{
		id = "MysticVine",
		order = 4,
		name = "Mystic Vine Rod",
		priceGold = 45000,
		strengthReq = 90000,
		power = 4,
		luckBonus = 0.65,
		controlBonus = 0.15,
		rodColor = Color3.fromRGB(118, 62, 184),
		accentColor = Color3.fromRGB(224, 128, 255),
		description = "Infused with glowing swamp Spores that attract elusive beasts.",
	},
	{
		id = "MagmaCore",
		order = 5,
		name = "Magma Core Rod",
		priceGold = 350000,
		strengthReq = 650000,
		power = 5,
		luckBonus = 1.10,
		controlBonus = 0.20,
		rodColor = Color3.fromRGB(96, 36, 36),
		accentColor = Color3.fromRGB(255, 118, 42),
		description = "Forged in volcanic obsidian to haul molten leviathans.",
	},
	{
		id = "Celestial",
		order = 6,
		name = "Celestial Starlight Rod",
		priceGold = 2500000,
		strengthReq = 4500000,
		power = 6,
		luckBonus = 1.80,
		controlBonus = 0.28,
		rodColor = Color3.fromRGB(238, 234, 255),
		accentColor = Color3.fromRGB(255, 108, 232),
		description = "Woven from cosmic starlight to conquer mythical titans.",
	},
} :: { Types.RodDef }

RodsConfig.ById = {} :: { [string]: Types.RodDef }
for _, rod in ipairs(RodsConfig.List) do
	RodsConfig.ById[rod.id] = rod
end

function RodsConfig.Get(rodId: string): Types.RodDef
	return RodsConfig.ById[rodId] or RodsConfig.List[1]
end

function RodsConfig.GetNextRod(currentRodId: string): Types.RodDef?
	local cur = RodsConfig.Get(currentRodId)
	for _, rod in ipairs(RodsConfig.List) do
		if rod.order == cur.order + 1 then
			return rod
		end
	end
	return nil
end

return RodsConfig
