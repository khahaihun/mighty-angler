--!strict
-- RanksConfig.luau: 10 Danh Hieu Overhead Rank Title & Cap Hào Quang (Aura) theo Strength & Rebirth

export type RankDef = {
	minStrength: number,
	title: string,
	color: Color3,
	auraRate: number,
}

local RanksConfig = {}

RanksConfig.List = {
	{ minStrength = 0, title = "⚓ Rookie Angler", color = Color3.fromRGB(186, 198, 216), auraRate = 0 },
	{ minStrength = 500, title = "🎣 Dock Striker", color = Color3.fromRGB(98, 224, 148), auraRate = 0 },
	{ minStrength = 2500, title = "🌊 Reef Challenger", color = Color3.fromRGB(78, 196, 255), auraRate = 6 },
	{ minStrength = 15000, title = "🦈 Deep Sea Hunter", color = Color3.fromRGB(118, 148, 255), auraRate = 10 },
	{ minStrength = 95000, title = "🔮 Swamp Mystic", color = Color3.fromRGB(196, 108, 255), auraRate = 14 },
	{ minStrength = 450000, title = "🔥 Obsidian Lifter", color = Color3.fromRGB(255, 136, 58), auraRate = 18 },
	{ minStrength = 1800000, title = "⚡ Magma Titan", color = Color3.fromRGB(255, 86, 68), auraRate = 24 },
	{ minStrength = 5000000, title = "🌟 Starlight Sovereign", color = Color3.fromRGB(255, 214, 68), auraRate = 30 },
	{ minStrength = 18000000, title = "👑 Astral Demigod", color = Color3.fromRGB(255, 102, 218), auraRate = 38 },
	{ minStrength = 60000000, title = "🐉 World Breaker", color = Color3.fromRGB(118, 252, 255), auraRate = 48 },
} :: { RankDef }

function RanksConfig.GetForStrength(strength: number): RankDef
	local best = RanksConfig.List[1]
	for _, r in ipairs(RanksConfig.List) do
		if strength >= r.minStrength then
			best = r
		end
	end
	return best
end

return RanksConfig
