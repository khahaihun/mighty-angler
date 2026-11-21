--!strict
-- exclusive_pet_scaling.luau: Kiem thu Luau VM cho cau truc 6 Trung / 24 Pet & Exclusive Pet Scaling theo Pet thuong khoe nhat

local function runSuite(mods: {
	PetsConfig: any,
	Islands: any,
	OddsCalculator: any,
	PetsService: any,
	BuffAggregator: any,
}, env: any)
	local passed = 0
	local function check(name: string, cond: boolean, detail: string?)
		if not cond then
			error("FAIL [" .. name .. "]: " .. tostring(detail or "assertion failed"))
		end
		passed += 1
		print("PASS exclusive_pet: " .. name)
	end
	local function near(a: number, b: number, label: string)
		check(label, math.abs(a - b) < 1e-4, string.format("got %.4f expected %.4f", a, b))
	end

	local PetsConfig = mods.PetsConfig
	local Islands = mods.Islands

	-- 1. Dung 6 Trung (5 Gold + 1 Exclusive Gem o Dao 1) va 24 Pet hoat dong
	check("exactly_6_eggs", #PetsConfig.Eggs == 6, "got " .. tostring(#PetsConfig.Eggs))
	check("exactly_24_active_pets", PetsConfig.ActivePetCount == 24, "got " .. tostring(PetsConfig.ActivePetCount))

	local goldCount, gemCount = 0, 0
	for _, egg in ipairs(PetsConfig.Eggs) do
		check("egg_has_4_pets_" .. egg.id, #egg.pets == 4, "got " .. tostring(#egg.pets))
		local wSum = 0
		for _, p in ipairs(egg.pets) do
			wSum += p.weightChance
		end
		near(wSum, 100, "egg_weight_sum_100_" .. egg.id)
		if egg.currency == "Gold" then
			goldCount += 1
		else
			gemCount += 1
			check("only_island_1_has_gem_egg", egg.islandId == 1 and egg.isExclusive == true)
		end
	end
	check("5_gold_and_1_gem_egg", goldCount == 5 and gemCount == 1)

	-- 2. Dao 1 co gemEggId, Dao 2..5 khong co gemEggId, nhung Boss drop van hoat dong du 5 dao
	for _, isl in ipairs(Islands.List) do
		if isl.id == 1 then
			check("island_1_has_gem_egg_id", isl.gemEggId == "egg_sunny_gem")
		else
			check("island_" .. tostring(isl.id) .. "_has_no_gem_egg", isl.gemEggId == nil)
		end
		local dropPool = PetsConfig.GetBossDropPool(isl.id)
		check("boss_drop_pool_nonempty_island_" .. tostring(isl.id), #dropPool >= 2)
	end

	-- 3. Nguoi choi moi chi co Pet Exclusive (khong co Pet thuong) -> dung san toi thieu, khong scale vong tron
	local seraph = PetsConfig.PetsById["pet_excl_sovereign_seraph"]
	local angel = PetsConfig.PetsById["pet_excl_pearl_angel"]
	local dragon = PetsConfig.PetsById["pet_excl_tide_dragon"]
	local griffin = PetsConfig.PetsById["pet_excl_sun_griffin"]
	local onlyExclusiveOwned = {
		{ uid = "e1", petId = "pet_excl_sovereign_seraph" },
		{ uid = "e2", petId = "pet_excl_pearl_angel" },
	}
	check("no_circular_normal_pet", PetsConfig.GetBestOwnedNormalPet(onlyExclusiveOwned) == nil)
	local angelFloor = PetsConfig.GetEffectivePetStats(angel, onlyExclusiveOwned)
	near(angelFloor.sellBonus, 0.25, "angel_floor_sell_no_circular_scale")
	near(angelFloor.luckBonus, 0.15, "angel_floor_luck_no_circular_scale")
	check("angel_floor_no_source_name", angelFloor.scaledFromName == nil)

	-- 4. Khi so huu Pet thuong manh nhat Dao 5 (Nova Seraph: 1.26 sell / 1.26 str / 0.92 luck / 0.16 mut)
	local nova = PetsConfig.PetsById["pet_nova_valkyrie"]
	check("nova_base_sell_1_26", math.abs(nova.sellBonus - 1.26) < 1e-4)
	local endgameOwned = {
		{ uid = "n1", petId = "pet_sand_crab" },
		{ uid = "n5", petId = "pet_nova_valkyrie" },
		{ uid = "e1", petId = "pet_excl_sovereign_seraph" },
		{ uid = "e2", petId = "pet_excl_tide_dragon" },
		{ uid = "e3", petId = "pet_excl_sun_griffin" },
		{ uid = "e4", petId = "pet_excl_pearl_angel" },
	}
	local bestNormal = PetsConfig.GetBestOwnedNormalPet(endgameOwned)
	check("best_normal_is_nova", bestNormal ~= nil and bestNormal.id == "pet_nova_valkyrie")

	local seraphScaled = PetsConfig.GetEffectivePetStats(seraph, endgameOwned)
	near(seraphScaled.sellBonus, 1.89, "seraph_150_sell")
	near(seraphScaled.strengthBonus, 1.89, "seraph_150_str")
	near(seraphScaled.luckBonus, 1.38, "seraph_150_luck")
	near(seraphScaled.mutationBonus, 0.25, "seraph_150_mut_respects_floor")
	check("seraph_scaled_from_nova", seraphScaled.scaledFromName == "Nova Seraph")

	local dragonScaled = PetsConfig.GetEffectivePetStats(dragon, endgameOwned)
	near(dragonScaled.sellBonus, 1.64, "dragon_130_sell")
	near(dragonScaled.luckBonus, 1.20, "dragon_130_luck")
	near(dragonScaled.mutationBonus, 0.21, "dragon_130_mut")

	local griffinScaled = PetsConfig.GetEffectivePetStats(griffin, endgameOwned)
	near(griffinScaled.sellBonus, 1.45, "griffin_115_sell")

	local angelScaled = PetsConfig.GetEffectivePetStats(angel, endgameOwned)
	near(angelScaled.sellBonus, 1.26, "angel_100_sell")

	-- 5. Tuong thich nguoc ho so cu (pet_celestial_omega -> pet_excl_sovereign_seraph)
	local legacyDef = PetsConfig.PetsById["pet_celestial_omega"]
	check("legacy_pet_id_resolves", legacyDef ~= nil and legacyDef.id == "pet_excl_sovereign_seraph")

	-- 6. Server BuffAggregator, EquipBest & OddsCalculator khop nhau 100%
	env.setProfile({
		rodId = "Twig",
		strength = 0,
		ownedRods = { Twig = true },
		rodEnchants = {},
		rebirths = 0,
		activeBait = nil,
		bait = {},
		gymGearLevel = 0,
		activePotions = {},
		pets = endgameOwned,
		equippedPetUids = {},
	})
	env.equipBest()
	local prof = env.getProfile()
	check("equip_best_picks_top_2_scaled_exclusives", #prof.equippedPetUids == 2 and prof.equippedPetUids[1] == "e1" and prof.equippedPetUids[2] == "e2")

	local serverMults = mods.BuffAggregator.GetMultipliers(env.player, 0, 0)
	local expectedPetLuck = seraphScaled.luckBonus + dragonScaled.luckBonus
	local expectedPetMut = seraphScaled.mutationBonus + dragonScaled.mutationBonus
	near(serverMults.luckMult, 1 + expectedPetLuck, "server_buff_matches_scaled_pet_luck")
	near(serverMults.mutationMult, 1 + expectedPetMut, "server_buff_matches_scaled_pet_mut")

	local liveOdds = mods.OddsCalculator.ComputeLiveOdds(
		1, "Twig", { Twig = true }, {}, nil, {}, {}, prof.pets, prof.equippedPetUids, 0, nil, 10000
	)
	local expectedShiny = math.min(0.45, 0.05 * (1 + expectedPetMut)) * 100
	local expectedTag = string.format("Shiny %.1f%%", expectedShiny)
	check("odds_calculator_matches_server_scaled_mut", string.find(liveOdds.mutationSummary, expectedTag, 1, true) ~= nil, liveOdds.mutationSummary .. " vs " .. expectedTag)

	print(string.format("EXCLUSIVE_PET_SUITE passed=%d failed=0", passed))
end

return runSuite
