--!strict
-- PetsConfig.luau: 10 Trung Pet (2 trung/dao x 5 dao) & 30 loai Pet doc dao co buff tang tien muot ma

local Types = require(script.Parent.Parent.Types)

local PetsConfig = {}

local function makeEgg(
	eggId: string,
	name: string,
	islandId: number,
	currency: "Gold" | "Gems",
	cost: number,
	eggCol: Color3,
	accCol: Color3,
	scaleMult: number,
	specs: { { id: string, name: string, rarity: string, arch: string, w: number, sell: number, str: number, luck: number, mut: number, c1: Color3, c2: Color3 } }
): Types.EggDef
	local pets: { Types.PetDef } = {}
	for _, s in ipairs(specs) do
		table.insert(pets, {
			id = s.id,
			name = s.name,
			eggId = eggId,
			islandId = islandId,
			rarity = s.rarity,
			archetype = s.arch,
			weightChance = s.w,
			sellBonus = math.floor(s.sell * scaleMult * 100 + 0.5) / 100,
			strengthBonus = math.floor(s.str * scaleMult * 100 + 0.5) / 100,
			luckBonus = math.floor(s.luck * scaleMult * 100 + 0.5) / 100,
			mutationBonus = s.mut,
			primaryColor = s.c1,
			secondaryColor = s.c2,
		})
	end
	return {
		id = eggId,
		name = name,
		islandId = islandId,
		currency = currency,
		cost = cost,
		eggColor = eggCol,
		accentColor = accCol,
		pets = pets,
	}
end

PetsConfig.Eggs = {
	-- ISLAND 1: SUNNY SHORES
	makeEgg("egg_sunny_gold", "Sunny Shell Egg", 1, "Gold", 350, Color3.fromRGB(255, 214, 78), Color3.fromRGB(255, 146, 58), 1.0, {
		{ id = "pet_sand_crab", name = "Sand Crab", rarity = "Common", arch = "Crab", w = 60, sell = 0.06, str = 0.06, luck = 0.00, mut = 0.00, c1 = Color3.fromRGB(255, 118, 76), c2 = Color3.fromRGB(255, 216, 152) },
		{ id = "pet_seagull", name = "Breeze Gull", rarity = "Uncommon", arch = "Bird", w = 30, sell = 0.10, str = 0.10, luck = 0.05, mut = 0.00, c1 = Color3.fromRGB(242, 248, 255), c2 = Color3.fromRGB(255, 192, 64) },
		{ id = "pet_sun_puffer", name = "Sunny Puffer", rarity = "Rare", arch = "Fish", w = 10, sell = 0.16, str = 0.16, luck = 0.10, mut = 0.05, c1 = Color3.fromRGB(255, 216, 62), c2 = Color3.fromRGB(82, 206, 255) },
	}),
	makeEgg("egg_sunny_gem", "Tropical Gem Egg", 1, "Gems", 120, Color3.fromRGB(88, 224, 255), Color3.fromRGB(255, 112, 214), 1.0, {
		{ id = "pet_tiki_spirit", name = "Tiki Spirit", rarity = "Epic", arch = "Spirit", w = 68, sell = 0.28, str = 0.28, luck = 0.15, mut = 0.10, c1 = Color3.fromRGB(112, 238, 152), c2 = Color3.fromRGB(255, 186, 62) },
		{ id = "pet_solar_drake", name = "Solar Sea Drake", rarity = "Legendary", arch = "Dragon", w = 28, sell = 0.45, str = 0.45, luck = 0.25, mut = 0.15, c1 = Color3.fromRGB(255, 196, 56), c2 = Color3.fromRGB(255, 92, 68) },
		{ id = "pet_dawn_star", name = "Dawn Starlight", rarity = "Mythic", arch = "Star", w = 4, sell = 0.70, str = 0.70, luck = 0.40, mut = 0.25, c1 = Color3.fromRGB(255, 118, 226), c2 = Color3.fromRGB(116, 246, 255) },
	}),

	-- ISLAND 2: CORAL DEPTHS
	makeEgg("egg_coral_gold", "Coral Pearl Egg", 2, "Gold", 3500, Color3.fromRGB(78, 226, 238), Color3.fromRGB(255, 126, 196), 1.65, {
		{ id = "pet_reef_shrimp", name = "Neon Shrimp", rarity = "Common", arch = "Crab", w = 60, sell = 0.07, str = 0.07, luck = 0.02, mut = 0.00, c1 = Color3.fromRGB(255, 116, 182), c2 = Color3.fromRGB(108, 245, 255) },
		{ id = "pet_bubble_seahorse", name = "Bubble Seahorse", rarity = "Uncommon", arch = "Fish", w = 30, sell = 0.11, str = 0.11, luck = 0.06, mut = 0.02, c1 = Color3.fromRGB(88, 218, 255), c2 = Color3.fromRGB(255, 226, 98) },
		{ id = "pet_prism_octo", name = "Prism Octopus", rarity = "Rare", arch = "Spirit", w = 10, sell = 0.17, str = 0.17, luck = 0.12, mut = 0.06, c1 = Color3.fromRGB(178, 108, 255), c2 = Color3.fromRGB(98, 252, 232) },
	}),
	makeEgg("egg_coral_gem", "Siren Gem Egg", 2, "Gems", 160, Color3.fromRGB(186, 104, 255), Color3.fromRGB(96, 250, 236), 1.45, {
		{ id = "pet_pearl_guardian", name = "Pearl Sprite", rarity = "Epic", arch = "Spirit", w = 68, sell = 0.28, str = 0.28, luck = 0.16, mut = 0.10, c1 = Color3.fromRGB(238, 246, 255), c2 = Color3.fromRGB(112, 236, 255) },
		{ id = "pet_tidal_wyrm", name = "Tidal Wyrmling", rarity = "Legendary", arch = "Dragon", w = 28, sell = 0.45, str = 0.45, luck = 0.28, mut = 0.18, c1 = Color3.fromRGB(64, 186, 255), c2 = Color3.fromRGB(255, 132, 216) },
		{ id = "pet_siren_crown", name = "Siren Seraph", rarity = "Mythic", arch = "Star", w = 4, sell = 0.72, str = 0.72, luck = 0.42, mut = 0.28, c1 = Color3.fromRGB(108, 255, 228), c2 = Color3.fromRGB(232, 112, 255) },
	}),

	-- ISLAND 3: MYSTIC SWAMP
	makeEgg("egg_swamp_gold", "Spore Pod Egg", 3, "Gold", 32000, Color3.fromRGB(162, 92, 248), Color3.fromRGB(118, 255, 186), 2.35, {
		{ id = "pet_glow_frog", name = "Glow Frog", rarity = "Common", arch = "Crab", w = 60, sell = 0.07, str = 0.07, luck = 0.03, mut = 0.02, c1 = Color3.fromRGB(112, 246, 172), c2 = Color3.fromRGB(178, 102, 255) },
		{ id = "pet_spore_owl", name = "Spore Owl", rarity = "Uncommon", arch = "Bird", w = 30, sell = 0.11, str = 0.11, luck = 0.07, mut = 0.04, c1 = Color3.fromRGB(168, 118, 248), c2 = Color3.fromRGB(255, 228, 108) },
		{ id = "pet_lantern_wisp", name = "Lantern Wisp", rarity = "Rare", arch = "Spirit", w = 10, sell = 0.18, str = 0.18, luck = 0.12, mut = 0.08, c1 = Color3.fromRGB(122, 255, 212), c2 = Color3.fromRGB(224, 112, 255) },
	}),
	makeEgg("egg_swamp_gem", "Runic Gem Egg", 3, "Gems", 210, Color3.fromRGB(118, 255, 192), Color3.fromRGB(196, 96, 255), 1.9, {
		{ id = "pet_witch_cat", name = "Mystic Familiar", rarity = "Epic", arch = "Spirit", w = 68, sell = 0.28, str = 0.28, luck = 0.18, mut = 0.12, c1 = Color3.fromRGB(142, 82, 238), c2 = Color3.fromRGB(118, 255, 192) },
		{ id = "pet_hydra_hatchling", name = "Bog Hydra Hatchling", rarity = "Legendary", arch = "Dragon", w = 28, sell = 0.46, str = 0.46, luck = 0.30, mut = 0.20, c1 = Color3.fromRGB(108, 242, 148), c2 = Color3.fromRGB(206, 98, 255) },
		{ id = "pet_elder_archon", name = "Elder Spore Archon", rarity = "Mythic", arch = "Star", w = 4, sell = 0.74, str = 0.74, luck = 0.45, mut = 0.30, c1 = Color3.fromRGB(224, 112, 255), c2 = Color3.fromRGB(124, 255, 198) },
	}),

	-- ISLAND 4: EMBER ISLE
	makeEgg("egg_ember_gold", "Magma Core Egg", 4, "Gold", 260000, Color3.fromRGB(255, 106, 42), Color3.fromRGB(255, 214, 72), 3.2, {
		{ id = "pet_lava_tortoise", name = "Cinder Tortoise", rarity = "Common", arch = "Crab", w = 60, sell = 0.08, str = 0.08, luck = 0.04, mut = 0.02, c1 = Color3.fromRGB(88, 68, 72), c2 = Color3.fromRGB(255, 118, 46) },
		{ id = "pet_ember_hawk", name = "Ember Hawk", rarity = "Uncommon", arch = "Bird", w = 30, sell = 0.12, str = 0.12, luck = 0.08, mut = 0.05, c1 = Color3.fromRGB(255, 108, 48), c2 = Color3.fromRGB(255, 218, 78) },
		{ id = "pet_pyre_elemental", name = "Pyre Elemental", rarity = "Rare", arch = "Spirit", w = 10, sell = 0.19, str = 0.19, luck = 0.14, mut = 0.10, c1 = Color3.fromRGB(255, 168, 52), c2 = Color3.fromRGB(255, 68, 48) },
	}),
	makeEgg("egg_ember_gem", "Inferno Gem Egg", 4, "Gems", 270, Color3.fromRGB(255, 76, 52), Color3.fromRGB(255, 226, 86), 2.4, {
		{ id = "pet_obsidian_golem", name = "Magma Core Sprite", rarity = "Epic", arch = "Spirit", w = 68, sell = 0.30, str = 0.30, luck = 0.20, mut = 0.14, c1 = Color3.fromRGB(72, 56, 66), c2 = Color3.fromRGB(255, 128, 42) },
		{ id = "pet_phoenix", name = "Caldera Phoenix", rarity = "Legendary", arch = "Bird", w = 28, sell = 0.48, str = 0.48, luck = 0.32, mut = 0.22, c1 = Color3.fromRGB(255, 198, 58), c2 = Color3.fromRGB(255, 72, 42) },
		{ id = "pet_vulcan_dragon", name = "Vulcan Sovereign", rarity = "Mythic", arch = "Dragon", w = 4, sell = 0.78, str = 0.78, luck = 0.50, mut = 0.35, c1 = Color3.fromRGB(255, 86, 38), c2 = Color3.fromRGB(255, 236, 108) },
	}),

	-- ISLAND 5: CELESTIAL DEEP
	makeEgg("egg_celestial_gold", "Starlight Egg", 5, "Gold", 1800000, Color3.fromRGB(118, 238, 255), Color3.fromRGB(255, 132, 238), 4.2, {
		{ id = "pet_comet_fin", name = "Comet Fin", rarity = "Common", arch = "Fish", w = 60, sell = 0.08, str = 0.08, luck = 0.05, mut = 0.04, c1 = Color3.fromRGB(118, 238, 255), c2 = Color3.fromRGB(255, 224, 108) },
		{ id = "pet_nebula_dove", name = "Nebula Dove", rarity = "Uncommon", arch = "Bird", w = 30, sell = 0.13, str = 0.13, luck = 0.09, mut = 0.06, c1 = Color3.fromRGB(226, 132, 255), c2 = Color3.fromRGB(128, 248, 255) },
		{ id = "pet_astral_fox", name = "Astral Wisp", rarity = "Rare", arch = "Spirit", w = 10, sell = 0.20, str = 0.20, luck = 0.15, mut = 0.12, c1 = Color3.fromRGB(246, 242, 255), c2 = Color3.fromRGB(255, 122, 232) },
	}),
	makeEgg("egg_celestial_gem", "Cosmic Relic Egg", 5, "Gems", 350, Color3.fromRGB(242, 112, 255), Color3.fromRGB(112, 250, 255), 3.0, {
		{ id = "pet_nova_valkyrie", name = "Nova Seraph", rarity = "Epic", arch = "Spirit", w = 68, sell = 0.32, str = 0.32, luck = 0.22, mut = 0.16, c1 = Color3.fromRGB(255, 142, 238), c2 = Color3.fromRGB(122, 248, 255) },
		{ id = "pet_galaxy_dragon", name = "Galaxy Leviathan", rarity = "Legendary", arch = "Dragon", w = 28, sell = 0.52, str = 0.52, luck = 0.35, mut = 0.25, c1 = Color3.fromRGB(142, 106, 255), c2 = Color3.fromRGB(112, 252, 255) },
		{ id = "pet_celestial_omega", name = "Celestial Singularity", rarity = "Mythic", arch = "Star", w = 4, sell = 0.85, str = 0.85, luck = 0.55, mut = 0.40, c1 = Color3.fromRGB(255, 236, 126), c2 = Color3.fromRGB(255, 106, 242) },
	}),
} :: { Types.EggDef }

PetsConfig.EggsById = {} :: { [string]: Types.EggDef }
PetsConfig.PetsById = {} :: { [string]: Types.PetDef }
PetsConfig.GemEggsByIsland = {} :: { [number]: Types.EggDef }

for _, egg in ipairs(PetsConfig.Eggs) do
	PetsConfig.EggsById[egg.id] = egg
	if egg.currency == "Gems" then
		PetsConfig.GemEggsByIsland[egg.islandId] = egg
	end
	for _, pet in ipairs(egg.pets) do
		PetsConfig.PetsById[pet.id] = pet
	end
end

function PetsConfig.GetPowerScore(pet: Types.PetDef): number
	return pet.sellBonus + pet.strengthBonus + pet.luckBonus * 0.8 + pet.mutationBonus * 0.5
end

return PetsConfig
