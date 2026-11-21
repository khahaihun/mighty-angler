--!strict
-- PetsConfig.luau: 6 Trung (5 Trung Gold theo Dao x 4 Pet + 1 Trung Gem Exclusive duy nhat o Dao 1 x 4 Pet scale theo Pet khoe nhat) = 24 Pet

local Types = require(script.Parent.Parent.Types)

local PetsConfig = {}

type PetSpec = {
	id: string,
	name: string,
	rarity: string,
	arch: string,
	w: number,
	sell: number,
	str: number,
	luck: number,
	mut: number,
	c1: Color3,
	c2: Color3,
	isExclusive: boolean?,
	scaleFactor: number?,
}

local function round2(v: number): number
	return math.floor(v * 100 + 0.5) / 100
end

local function makeEgg(
	eggId: string,
	name: string,
	islandId: number,
	currency: "Gold" | "Gems",
	cost: number,
	eggCol: Color3,
	accCol: Color3,
	scaleMult: number,
	specs: { PetSpec },
	isExclusiveEgg: boolean?
): Types.EggDef
	local pets: { Types.PetDef } = {}
	for _, s in ipairs(specs) do
		local isExcl = (s.isExclusive == true) or (isExclusiveEgg == true)
		table.insert(pets, {
			id = s.id,
			name = s.name,
			eggId = eggId,
			islandId = islandId,
			rarity = s.rarity,
			archetype = s.arch,
			weightChance = s.w,
			sellBonus = round2(s.sell * scaleMult),
			strengthBonus = round2(s.str * scaleMult),
			luckBonus = round2(s.luck * scaleMult),
			mutationBonus = round2(s.mut),
			primaryColor = s.c1,
			secondaryColor = s.c2,
			isExclusive = isExcl,
			scaleFactor = if isExcl then (s.scaleFactor or 1.0) else nil,
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
		isExclusive = isExclusiveEgg == true,
	}
end

PetsConfig.Eggs = {
	-- ISLAND 1: SUNNY SHORES (1 Trung Gold + 1 Trung Gem Exclusive duy nhat toan game)
	makeEgg("egg_sunny_gold", "Sunny Shell Egg", 1, "Gold", 350, Color3.fromRGB(255, 214, 78), Color3.fromRGB(255, 146, 58), 1.0, {
		{ id = "pet_sand_crab", name = "Sand Crab", rarity = "Common", arch = "Crab", w = 55, sell = 0.06, str = 0.06, luck = 0.00, mut = 0.00, c1 = Color3.fromRGB(255, 118, 76), c2 = Color3.fromRGB(255, 216, 152) },
		{ id = "pet_seagull", name = "Breeze Gull", rarity = "Uncommon", arch = "Bird", w = 28, sell = 0.10, str = 0.10, luck = 0.05, mut = 0.02, c1 = Color3.fromRGB(242, 248, 255), c2 = Color3.fromRGB(255, 192, 64) },
		{ id = "pet_sun_puffer", name = "Sunny Puffer", rarity = "Rare", arch = "Fish", w = 13, sell = 0.16, str = 0.16, luck = 0.10, mut = 0.05, c1 = Color3.fromRGB(255, 216, 62), c2 = Color3.fromRGB(82, 206, 255) },
		{ id = "pet_tiki_spirit", name = "Tiki Spirit", rarity = "Epic", arch = "Spirit", w = 4, sell = 0.24, str = 0.24, luck = 0.15, mut = 0.10, c1 = Color3.fromRGB(112, 238, 152), c2 = Color3.fromRGB(255, 186, 62) },
	}, false),

	makeEgg("egg_sunny_gem", "Sovereign Exclusive Egg", 1, "Gems", 250, Color3.fromRGB(214, 96, 255), Color3.fromRGB(255, 218, 72), 1.0, {
		{ id = "pet_excl_pearl_angel", name = "Pearl Halo Angel", rarity = "Epic", arch = "Spirit", w = 60, sell = 0.25, str = 0.25, luck = 0.15, mut = 0.08, c1 = Color3.fromRGB(122, 244, 255), c2 = Color3.fromRGB(255, 224, 118), isExclusive = true, scaleFactor = 1.00 },
		{ id = "pet_excl_sun_griffin", name = "Solar Wing Griffin", rarity = "Legendary", arch = "Bird", w = 27, sell = 0.38, str = 0.38, luck = 0.22, mut = 0.12, c1 = Color3.fromRGB(255, 196, 56), c2 = Color3.fromRGB(255, 98, 72), isExclusive = true, scaleFactor = 1.15 },
		{ id = "pet_excl_tide_dragon", name = "Tide Crown Dragon", rarity = "Mythic", arch = "Dragon", w = 10, sell = 0.55, str = 0.55, luck = 0.32, mut = 0.18, c1 = Color3.fromRGB(168, 92, 255), c2 = Color3.fromRGB(98, 248, 255), isExclusive = true, scaleFactor = 1.30 },
		{ id = "pet_excl_sovereign_seraph", name = "Sovereign Seraph", rarity = "Mythic", arch = "Star", w = 3, sell = 0.80, str = 0.80, luck = 0.45, mut = 0.25, c1 = Color3.fromRGB(255, 228, 96), c2 = Color3.fromRGB(255, 108, 232), isExclusive = true, scaleFactor = 1.50 },
	}, true),

	-- ISLAND 2: CORAL DEPTHS (1 Trung Gold x 4 Pet)
	makeEgg("egg_coral_gold", "Coral Pearl Egg", 2, "Gold", 3500, Color3.fromRGB(78, 226, 238), Color3.fromRGB(255, 126, 196), 1.65, {
		{ id = "pet_reef_shrimp", name = "Neon Shrimp", rarity = "Common", arch = "Crab", w = 55, sell = 0.07, str = 0.07, luck = 0.02, mut = 0.00, c1 = Color3.fromRGB(255, 116, 182), c2 = Color3.fromRGB(108, 245, 255) },
		{ id = "pet_bubble_seahorse", name = "Bubble Seahorse", rarity = "Uncommon", arch = "Fish", w = 28, sell = 0.11, str = 0.11, luck = 0.06, mut = 0.02, c1 = Color3.fromRGB(88, 218, 255), c2 = Color3.fromRGB(255, 226, 98) },
		{ id = "pet_prism_octo", name = "Prism Octopus", rarity = "Rare", arch = "Spirit", w = 13, sell = 0.17, str = 0.17, luck = 0.12, mut = 0.06, c1 = Color3.fromRGB(178, 108, 255), c2 = Color3.fromRGB(98, 252, 232) },
		{ id = "pet_pearl_guardian", name = "Pearl Sprite", rarity = "Epic", arch = "Spirit", w = 4, sell = 0.25, str = 0.25, luck = 0.16, mut = 0.10, c1 = Color3.fromRGB(238, 246, 255), c2 = Color3.fromRGB(112, 236, 255) },
	}, false),

	-- ISLAND 3: MYSTIC SWAMP (1 Trung Gold x 4 Pet)
	makeEgg("egg_swamp_gold", "Spore Pod Egg", 3, "Gold", 32000, Color3.fromRGB(162, 92, 248), Color3.fromRGB(118, 255, 186), 2.35, {
		{ id = "pet_glow_frog", name = "Glow Frog", rarity = "Common", arch = "Crab", w = 55, sell = 0.07, str = 0.07, luck = 0.03, mut = 0.02, c1 = Color3.fromRGB(112, 246, 172), c2 = Color3.fromRGB(178, 102, 255) },
		{ id = "pet_spore_owl", name = "Spore Owl", rarity = "Uncommon", arch = "Bird", w = 28, sell = 0.11, str = 0.11, luck = 0.07, mut = 0.04, c1 = Color3.fromRGB(168, 118, 248), c2 = Color3.fromRGB(255, 228, 108) },
		{ id = "pet_lantern_wisp", name = "Lantern Wisp", rarity = "Rare", arch = "Spirit", w = 13, sell = 0.18, str = 0.18, luck = 0.12, mut = 0.08, c1 = Color3.fromRGB(122, 255, 212), c2 = Color3.fromRGB(224, 112, 255) },
		{ id = "pet_witch_cat", name = "Mystic Familiar", rarity = "Epic", arch = "Spirit", w = 4, sell = 0.26, str = 0.26, luck = 0.18, mut = 0.12, c1 = Color3.fromRGB(142, 82, 238), c2 = Color3.fromRGB(118, 255, 192) },
	}, false),

	-- ISLAND 4: EMBER ISLE (1 Trung Gold x 4 Pet)
	makeEgg("egg_ember_gold", "Magma Core Egg", 4, "Gold", 260000, Color3.fromRGB(255, 106, 42), Color3.fromRGB(255, 214, 72), 3.2, {
		{ id = "pet_lava_tortoise", name = "Cinder Tortoise", rarity = "Common", arch = "Crab", w = 55, sell = 0.08, str = 0.08, luck = 0.04, mut = 0.02, c1 = Color3.fromRGB(88, 68, 72), c2 = Color3.fromRGB(255, 118, 46) },
		{ id = "pet_ember_hawk", name = "Ember Hawk", rarity = "Uncommon", arch = "Bird", w = 28, sell = 0.12, str = 0.12, luck = 0.08, mut = 0.05, c1 = Color3.fromRGB(255, 108, 48), c2 = Color3.fromRGB(255, 218, 78) },
		{ id = "pet_pyre_elemental", name = "Pyre Elemental", rarity = "Rare", arch = "Spirit", w = 13, sell = 0.19, str = 0.19, luck = 0.14, mut = 0.10, c1 = Color3.fromRGB(255, 168, 52), c2 = Color3.fromRGB(255, 68, 48) },
		{ id = "pet_obsidian_golem", name = "Magma Core Sprite", rarity = "Epic", arch = "Spirit", w = 4, sell = 0.28, str = 0.28, luck = 0.20, mut = 0.14, c1 = Color3.fromRGB(72, 56, 66), c2 = Color3.fromRGB(255, 128, 42) },
	}, false),

	-- ISLAND 5: CELESTIAL DEEP (1 Trung Gold x 4 Pet)
	makeEgg("egg_celestial_gold", "Starlight Egg", 5, "Gold", 1800000, Color3.fromRGB(118, 238, 255), Color3.fromRGB(255, 132, 238), 4.2, {
		{ id = "pet_comet_fin", name = "Comet Fin", rarity = "Common", arch = "Fish", w = 55, sell = 0.08, str = 0.08, luck = 0.05, mut = 0.04, c1 = Color3.fromRGB(118, 238, 255), c2 = Color3.fromRGB(255, 224, 108) },
		{ id = "pet_nebula_dove", name = "Nebula Dove", rarity = "Uncommon", arch = "Bird", w = 28, sell = 0.13, str = 0.13, luck = 0.09, mut = 0.06, c1 = Color3.fromRGB(226, 132, 255), c2 = Color3.fromRGB(128, 248, 255) },
		{ id = "pet_astral_fox", name = "Astral Wisp", rarity = "Rare", arch = "Spirit", w = 13, sell = 0.20, str = 0.20, luck = 0.15, mut = 0.12, c1 = Color3.fromRGB(246, 242, 255), c2 = Color3.fromRGB(255, 122, 232) },
		{ id = "pet_nova_valkyrie", name = "Nova Seraph", rarity = "Epic", arch = "Spirit", w = 4, sell = 0.30, str = 0.30, luck = 0.22, mut = 0.16, c1 = Color3.fromRGB(255, 142, 238), c2 = Color3.fromRGB(122, 248, 255) },
	}, false),
} :: { Types.EggDef }

PetsConfig.EggsById = {} :: { [string]: Types.EggDef }
PetsConfig.PetsById = {} :: { [string]: Types.PetDef }
PetsConfig.GoldEggsByIsland = {} :: { [number]: Types.EggDef }
PetsConfig.GemEggsByIsland = {} :: { [number]: Types.EggDef }
PetsConfig.ExclusiveEgg = nil :: Types.EggDef?
PetsConfig.ActivePetCount = 0

for _, egg in ipairs(PetsConfig.Eggs) do
	PetsConfig.EggsById[egg.id] = egg
	if egg.currency == "Gems" then
		PetsConfig.GemEggsByIsland[egg.islandId] = egg
		if egg.isExclusive then
			PetsConfig.ExclusiveEgg = egg
		end
	else
		PetsConfig.GoldEggsByIsland[egg.islandId] = egg
	end
	for _, pet in ipairs(egg.pets) do
		PetsConfig.PetsById[pet.id] = pet
		PetsConfig.ActivePetCount += 1
	end
end

-- Tuong thich nguoc cho ho so cu tung so huu Pet Gem cua dao 1-5 truoc khi gop ve 1 Trung Exclusive
local LEGACY_PET_ALIASES: { [string]: string } = {
	pet_solar_drake = "pet_excl_sun_griffin",
	pet_dawn_star = "pet_excl_sovereign_seraph",
	pet_tidal_wyrm = "pet_excl_sun_griffin",
	pet_siren_crown = "pet_excl_tide_dragon",
	pet_hydra_hatchling = "pet_excl_tide_dragon",
	pet_elder_archon = "pet_excl_sovereign_seraph",
	pet_phoenix = "pet_excl_sun_griffin",
	pet_vulcan_dragon = "pet_excl_tide_dragon",
	pet_galaxy_dragon = "pet_excl_tide_dragon",
	pet_celestial_omega = "pet_excl_sovereign_seraph",
}
for legacyId, targetId in pairs(LEGACY_PET_ALIASES) do
	local mapped = PetsConfig.PetsById[targetId]
	if mapped and not PetsConfig.PetsById[legacyId] then
		PetsConfig.PetsById[legacyId] = mapped
	end
end

function PetsConfig.GetPowerScore(pet: Types.PetDef): number
	return pet.sellBonus + pet.strengthBonus + pet.luckBonus * 0.8 + pet.mutationBonus * 0.5
end

function PetsConfig.GetBestOwnedNormalPet(ownedPets: { any }?): Types.PetDef?
	if type(ownedPets) ~= "table" then
		return nil
	end
	local best: Types.PetDef? = nil
	local bestScore = -1
	for _, inst in ipairs(ownedPets) do
		if type(inst) == "table" and type(inst.petId) == "string" then
			local def = PetsConfig.PetsById[inst.petId]
			if def and def.isExclusive ~= true then
				local score = PetsConfig.GetPowerScore(def)
				if score > bestScore then
					bestScore = score
					best = def
				end
			end
		end
	end
	return best
end

function PetsConfig.GetEffectivePetStats(petDef: Types.PetDef, ownedPets: { any }?): Types.EffectivePetStats
	if petDef.isExclusive ~= true then
		return {
			sellBonus = petDef.sellBonus,
			strengthBonus = petDef.strengthBonus,
			luckBonus = petDef.luckBonus,
			mutationBonus = petDef.mutationBonus,
			isExclusive = false,
			scaleFactor = 1.0,
			scaledFromName = nil,
		}
	end

	local factor = petDef.scaleFactor or 1.0
	local bestNormal = PetsConfig.GetBestOwnedNormalPet(ownedPets)
	if not bestNormal then
		return {
			sellBonus = petDef.sellBonus,
			strengthBonus = petDef.strengthBonus,
			luckBonus = petDef.luckBonus,
			mutationBonus = petDef.mutationBonus,
			isExclusive = true,
			scaleFactor = factor,
			scaledFromName = nil,
		}
	end

	return {
		sellBonus = math.max(petDef.sellBonus, round2(bestNormal.sellBonus * factor)),
		strengthBonus = math.max(petDef.strengthBonus, round2(bestNormal.strengthBonus * factor)),
		luckBonus = math.max(petDef.luckBonus, round2(bestNormal.luckBonus * factor)),
		mutationBonus = math.max(petDef.mutationBonus, round2(bestNormal.mutationBonus * factor)),
		isExclusive = true,
		scaleFactor = factor,
		scaledFromName = bestNormal.name,
	}
end

function PetsConfig.GetEffectivePowerScore(petDef: Types.PetDef, ownedPets: { any }?): number
	local eff = PetsConfig.GetEffectivePetStats(petDef, ownedPets)
	return eff.sellBonus + eff.strengthBonus + eff.luckBonus * 0.8 + eff.mutationBonus * 0.5
end

function PetsConfig.GetBossDropPool(islandId: number): { Types.PetDef }
	local goldEgg = PetsConfig.GoldEggsByIsland[islandId]
	if goldEgg and #goldEgg.pets > 0 then
		local rarePool: { Types.PetDef } = {}
		for _, p in ipairs(goldEgg.pets) do
			if p.rarity == "Rare" or p.rarity == "Epic" or p.rarity == "Legendary" or p.rarity == "Mythic" then
				table.insert(rarePool, p)
			end
		end
		if #rarePool > 0 then
			return rarePool
		end
		return goldEgg.pets
	end
	if PetsConfig.ExclusiveEgg then
		return PetsConfig.ExclusiveEgg.pets
	end
	return {}
end

return PetsConfig
