--!strict
-- art_pipeline_and_terrain.luau: Kiem thu Luau VM cho O cam 3D (AssetRegistry, Sanitize Script an,
-- RootOnly NPC, Silhouette/Mutation tren MeshPart, Egg/Rod Preview override) va che do Manual Terrain IslandMarkers.

local function runSuite(mods: {
	AssetRegistry: any,
	FishModelBuilder: any,
	PetModelBuilder: any,
	RodAndWeightBuilder: any,
	ManualIslandAdapter: any,
	NpcBuilder: any,
	IslandScenery1_2: any,
	runTerrainDraft: () -> (),
}, env: any)
	local passed = 0
	local function check(name: string, cond: boolean, detail: string?)
		if not cond then
			error("FAIL [" .. name .. "]: " .. tostring(detail or "assertion failed"))
		end
		passed += 1
		print("PASS art_pipeline: " .. name)
	end

	-- 1. EnsureFolders tao du 9 thu muc gom Eggs, Npcs, Buildings
	local root = mods.AssetRegistry.EnsureFolders()
	for _, cat in ipairs({ "Trees", "Props", "Gym", "Rods", "Fish", "Pets", "Eggs", "Npcs", "Buildings" }) do
		local f = root:FindFirstChild(cat)
		check("category_folder_" .. cat, f ~= nil and f:IsA("Folder"), "missing folder " .. cat)
	end

	-- 2. SanitizeModel tu dong xoa sach Script / LocalScript / ModuleScript an trong model clone
	local fishFolder = root:FindFirstChild("Fish")
	local mockFish = env.makeInstance("Model", "sunny_sardine")
	local meshBody = env.makeInstance("MeshPart", "Body")
	meshBody.TextureID = "rbxassetid://999"
	meshBody.Parent = mockFish
	mockFish.PrimaryPart = meshBody
	local surf = env.makeInstance("SurfaceAppearance", "Surf")
	surf.Parent = meshBody
	local virusScript = env.makeInstance("Script", "HiddenBackdoor")
	virusScript.Parent = meshBody
	local virusLocal = env.makeInstance("LocalScript", "HiddenLocal")
	virusLocal.Parent = mockFish
	local virusMod = env.makeInstance("ModuleScript", "HiddenMod")
	virusMod.Parent = mockFish
	mockFish.Parent = fishFolder

	local clonedFish = mods.AssetRegistry.TryClone("Fish", "sunny_sardine", true)
	check("clone_returns_model", clonedFish ~= nil)
	local remainingScripts = 0
	for _, d in ipairs(clonedFish:GetDescendants()) do
		if d:IsA("LuaSourceContainer") then
			remainingScripts += 1
		end
	end
	check("sanitize_strips_all_hidden_scripts", remainingScripts == 0, "found " .. tostring(remainingScripts))

	-- 3. FishModelBuilder giu nguyen Silhouette & Mutation (Highlight + ClientBudgetManaged emitter) tren MeshPart override
	local fishDef = {
		id = "sunny_sardine",
		name = "Sunny Sardine",
		rarity = "Common",
		primaryColor = Color3.fromRGB(155, 206, 235),
		secondaryColor = Color3.fromRGB(235, 245, 255),
	}
	local silFish = mods.FishModelBuilder.BuildFish(fishDef, "None", true)
	local silBody = silFish:FindFirstChild("Body")
	check("fish_override_silhouette_color", silBody ~= nil and silBody.Color.R == 20 and silBody.TextureID == "")
	check("fish_override_silhouette_strips_surface", silBody:FindFirstChild("Surf") == nil)

	local cosmicFish = mods.FishModelBuilder.BuildFish(fishDef, "Cosmic", false)
	local hl = cosmicFish:FindFirstChild("MutationHighlight")
	local emitter = cosmicFish.PrimaryPart:FindFirstChild("MutationParticles")
	check("fish_override_mutation_highlight", hl ~= nil and hl:IsA("Highlight"))
	check("fish_override_mutation_budget_emitter", emitter ~= nil and emitter:GetAttribute("ClientBudgetManaged") == true)

	-- 4. PetModelBuilder override silhouette + BuildEggPreview override
	local petsFolder = root:FindFirstChild("Pets")
	local mockPet = env.makeInstance("Model", "pet_sand_crab")
	local petRoot = env.makeInstance("MeshPart", "PetBody")
	petRoot.Parent = mockPet
	mockPet.PrimaryPart = petRoot
	mockPet.Parent = petsFolder

	local petDef = { id = "pet_sand_crab", name = "Sand Crab", rarity = "Common", archetype = "Crab", primaryColor = Color3.fromRGB(255, 100, 80), secondaryColor = Color3.fromRGB(255, 200, 150) }
	local silPet = mods.PetModelBuilder.BuildPet(petDef, true, false)
	check("pet_override_silhouette", silPet.PrimaryPart.Color.R == 20)

	local eggsFolder = root:FindFirstChild("Eggs")
	local mockEgg = env.makeInstance("Model", "egg_sunny_gem")
	local eggPart = env.makeInstance("MeshPart", "EggShell")
	eggPart.Parent = mockEgg
	mockEgg.PrimaryPart = eggPart
	mockEgg.Parent = eggsFolder

	local eggPreview = mods.PetModelBuilder.BuildEggPreview({
		id = "egg_sunny_gem",
		eggColor = Color3.fromRGB(255, 200, 60),
		accentColor = Color3.fromRGB(214, 96, 255),
		isExclusive = true,
	})
	check("egg_preview_uses_override", eggPreview:FindFirstChild("EggShell") ~= nil)

	-- 5. RodAndWeightBuilder.BuildRodPreview dung override trong Assets/Rods
	local rodsFolder = root:FindFirstChild("Rods")
	local mockRod = env.makeInstance("Model", "Twig")
	local rodGrip = env.makeInstance("Part", "Grip")
	rodGrip.Parent = mockRod
	mockRod.PrimaryPart = rodGrip
	local customTip = env.makeInstance("MeshPart", "CustomTwigMesh")
	customTip.Parent = mockRod
	mockRod.Parent = rodsFolder

	local rodPreview = mods.RodAndWeightBuilder.BuildRodPreview({
		id = "Twig",
		order = 1,
		rodColor = Color3.fromRGB(160, 110, 60),
		accentColor = Color3.fromRGB(200, 180, 140),
	})
	check("rod_preview_uses_override", rodPreview:FindFirstChild("CustomTwigMesh") ~= nil)

	-- 6. NpcBuilder dung RootOnly cho NPC 3D (HumanoidRootPart Anchored=true, tay chan Anchored=false) + ton trong IslandMarkers
	local npcsFolder = root:FindFirstChild("Npcs")
	local mockNpc = env.makeInstance("Model", "Merchant")
	local npcHrp = env.makeInstance("Part", "HumanoidRootPart")
	npcHrp.Anchored = true
	npcHrp.Parent = mockNpc
	local npcArm = env.makeInstance("Part", "LeftUpperArm")
	npcArm.Anchored = true
	npcArm.Parent = mockNpc
	local npcHead = env.makeInstance("Part", "Head")
	npcHead.Anchored = true
	npcHead.Parent = mockNpc
	mockNpc.PrimaryPart = npcHrp
	mockNpc.Parent = npcsFolder

	local manualRoot = env.makeInstance("Folder", "MightyWorldManual")
	manualRoot.Parent = env.Workspace
	local manualI1 = env.makeInstance("Folder", "Island_1")
	manualI1.Parent = manualRoot
	local markers = env.makeInstance("Folder", "IslandMarkers")
	markers.Parent = manualI1

	local mMerchant = env.makeInstance("Part", "NpcMerchant")
	mMerchant.CFrame = CFrame.new(12, 10, 34)
	mMerchant.Transparency = 0.5
	mMerchant.CanQuery = true
	local guideBb = env.makeInstance("BillboardGui", "GuideLabel")
	guideBb.Enabled = true
	guideBb.Parent = mMerchant
	mMerchant.Parent = markers

	local mWater = env.makeInstance("Part", "FishingWater")
	mWater.Size = Vector3.new(200, 1.2, 110)
	mWater.CFrame = CFrame.new(0, 9.1, 112)
	mWater.Parent = markers

	local islandFolder = env.makeInstance("Folder", "Island_1")
	local foundManual = mods.ManualIslandAdapter.FindManualIsland(1)
	check("manual_island_detected", foundManual == manualI1)
	mods.ManualIslandAdapter.HideRuntimeMarkers(foundManual)
	check("manual_markers_hidden_at_runtime", mMerchant.Transparency == 1 and mMerchant.CanQuery == false and guideBb.Enabled == false)

	local fw = mods.ManualIslandAdapter.BuildFishingWaterBounds(islandFolder, {
		id = 1,
		theme = { waterColor = Color3.fromRGB(40, 180, 240) },
	}, foundManual)
	check("manual_fishing_water_bounds", fw ~= nil and fw.CanQuery == false and fw:GetAttribute("IsFishingWater") == true and fw:GetAttribute("IslandId") == 1)

	mods.NpcBuilder.BuildIslandNpcs(islandFolder, {
		id = 1,
		centerPosition = Vector3.new(0, 10, 0),
	}, foundManual)
	local spawnedNpcs = islandFolder:FindFirstChild("IslandNpcs")
	local spawnedMerchant = if spawnedNpcs then spawnedNpcs:FindFirstChild("Npc_Merchant") else nil
	check("npc_override_spawned", spawnedMerchant ~= nil)
	check("npc_tagged_for_client_animation", spawnedMerchant:GetAttribute("Tag_MightyAnimatedNpc") == true)
	local sHrp = spawnedMerchant:FindFirstChild("HumanoidRootPart")
	local sArm = spawnedMerchant:FindFirstChild("LeftUpperArm")
	check("npc_root_only_anchoring", sHrp.Anchored == true and sArm.Anchored == false, "NPC limbs must remain unanchored")
	check("npc_uses_manual_marker_pos", spawnedMerchant:GetPivot().Position.X == 12 and spawnedMerchant:GetPivot().Position.Z == 34)

	-- 7. PetModelBuilder: Pet hiem / Exclusive KHONG phu Neon toan than, chi gan Neon o chi tiet nho
	local rarePets = {
		{ id = "test_leg_dragon", name = "Sun Dragon", rarity = "Legendary", archetype = "Dragon", primaryColor = Color3.fromRGB(255, 180, 60), secondaryColor = Color3.fromRGB(110, 220, 255) },
		{ id = "test_myth_star", name = "Star Sprite", rarity = "Mythic", archetype = "Star", primaryColor = Color3.fromRGB(180, 90, 255), secondaryColor = Color3.fromRGB(255, 224, 92) },
		{ id = "test_excl_seraph", name = "Sovereign Seraph", rarity = "Mythic", archetype = "Bird", isExclusive = true, primaryColor = Color3.fromRGB(92, 200, 255), secondaryColor = Color3.fromRGB(255, 214, 72) },
	}
	local allowedNeonNames = {
		EyeSparkle = true, ClawTipGlow = true, CrestGem = true, HornTipGlow = true,
		WingTipGlow = true, StarHalo = true, FinTipGlow = true, SpiritOrb = true,
		ExclusiveHalo = true, CrownGem = true,
	}
	for _, pDef in ipairs(rarePets) do
		local petModel = mods.PetModelBuilder.BuildPet(pDef, false, false)
		check("pet_body_not_neon_" .. pDef.id, petModel.PrimaryPart ~= nil and petModel.PrimaryPart.Material == Enum.Material.SmoothPlastic, "Body must stay SmoothPlastic")
		local neonCount = 0
		local badNeon = nil
		for _, d in ipairs(petModel:GetDescendants()) do
			if d:IsA("BasePart") and d.Material == Enum.Material.Neon then
				neonCount += 1
				if not allowedNeonNames[d.Name] then
					badNeon = d.Name
				end
			end
		end
		check("pet_neon_accent_only_" .. pDef.id, neonCount > 0 and badNeon == nil, "unexpected neon part: " .. tostring(badNeon))
	end

	-- 8. IslandScenery1_2: Canh tri giau suc song & bo doi xung guong o Dao 1 va Dao 2
	local sunnyFolder = env.makeInstance("Folder", "ScenerySunny")
	mods.IslandScenery1_2.Populate(sunnyFolder, {
		id = 1,
		centerPosition = Vector3.new(0, 10, 0),
		theme = { sceneryStyle = "Sunny", cliffColor = Color3.fromRGB(148, 122, 98) },
	})
	check("scenery_sunny_has_bushes", sunnyFolder:FindFirstChild("TropicalBush") ~= nil)
	check("scenery_sunny_has_rowboat", sunnyFolder:FindFirstChild("BeachedRowboat") ~= nil)
	local umbrellaPositions = {}
	for _, ch in ipairs(sunnyFolder:GetChildren()) do
		if ch.Name == "BeachUmbrella" then
			local pole = ch:FindFirstChild("Pole")
			if pole then table.insert(umbrellaPositions, pole.CFrame.Position) end
		end
	end
	check("scenery_sunny_umbrellas_not_mirror", #umbrellaPositions == 2 and math.abs(umbrellaPositions[1].Z - umbrellaPositions[2].Z) > 1.0)

	local coralFolder = env.makeInstance("Folder", "SceneryCoral")
	mods.IslandScenery1_2.Populate(coralFolder, {
		id = 2,
		centerPosition = Vector3.new(0, 10, 0),
		theme = { sceneryStyle = "Coral", cliffColor = Color3.fromRGB(100, 110, 130) },
	})
	check("scenery_coral_has_anemone", coralFolder:FindFirstChild("SeaAnemone") ~= nil)
	check("scenery_coral_has_kelp", coralFolder:FindFirstChild("KelpCluster") ~= nil)
	local coralMirrorFound = false
	local coralCoords = {}
	for _, ch in ipairs(coralFolder:GetChildren()) do
		if ch.Name == "CoralFormation" then
			local bubble = ch:FindFirstChild("BubbleSource")
			if bubble then table.insert(coralCoords, bubble.CFrame.Position) end
		end
	end
	for i = 1, #coralCoords do
		for j = i + 1, #coralCoords do
			if math.abs(coralCoords[i].X + coralCoords[j].X) < 1 and math.abs(coralCoords[i].Z - coralCoords[j].Z) < 1 then
				coralMirrorFound = true
			end
		end
	end
	check("scenery_coral_not_mirror", #coralCoords >= 5 and not coralMirrorFound)

	-- 9. Terrain Draft Dao 1: Khop tuyet doi hop bien [-132..132, -100..196] Y=9.7 (0 ho vanh) + OceanHole + OceanBounds
	mods.runTerrainDraft()
	local hasFullWater = false
	local hasFullSand = false
	local airCutSafe = true
	for _, op in ipairs(env.terrainOps) do
		if op.kind == "Block" then
			local p, sz = op.cf.Position, op.size
			local x0, x1 = p.X - sz.X * 0.5, p.X + sz.X * 0.5
			local y0, y1 = p.Y - sz.Y * 0.5, p.Y + sz.Y * 0.5
			local z0, z1 = p.Z - sz.Z * 0.5, p.Z + sz.Z * 0.5
			if op.mat == Enum.Material.Water and x0 <= -132 and x1 >= 132 and z0 <= -100 and z1 >= 196 then
				if math.abs(y1 - 9.7) < 1e-4 and math.abs(y0 - 0.0) < 1e-4 then
					hasFullWater = true
				end
			elseif op.mat == Enum.Material.Sand and x0 <= -132 and x1 >= 132 and z0 <= -100 and z1 >= 196 and y1 >= 0 then
				hasFullSand = true
			elseif op.mat == Enum.Material.Air and sz.X < 200 then
				if y0 < 9.7 then
					airCutSafe = false
				end
			end
		end
	end
	check("draft_water_fills_full_manual_box_at_9_7", hasFullWater, "Water FillBlock must cover [-132..132, -100..196] up to Y=9.7")
	check("draft_sand_seabed_fills_full_manual_box", hasFullSand, "Sand seabed must cover [-132..132, -100..196]")
	check("draft_plaza_air_cut_above_water", airCutSafe, "Plaza Air cut must not carve below Y=9.7")

	local draftIsland = mods.ManualIslandAdapter.FindManualIsland(1)
	check("draft_creates_manual_island_1", draftIsland ~= nil)
	local requiredMarkers = {
		"OceanHole", "Spawn", "Dock", "FishingWater", "SellMarket", "RodShop",
		"NpcMerchant", "NpcShop", "NpcCollector", "NpcCoach",
		"Gym_1", "Gym_2", "Gym_3", "EggGold", "EggGem", "EnchantAltar", "PortalNext",
	}
	for _, mName in ipairs(requiredMarkers) do
		local mp = mods.ManualIslandAdapter.GetMarkerPart(draftIsland, mName)
		check("draft_marker_" .. mName, mp ~= nil, "missing marker " .. mName)
	end
	local holePart = mods.ManualIslandAdapter.GetMarkerPart(draftIsland, "OceanHole")
	check("draft_ocean_hole_matches_box", holePart ~= nil and holePart.Size.X == 264 and holePart.Size.Z == 296 and holePart.CFrame.Position.X == 0 and holePart.CFrame.Position.Z == 48)
	local fwMarker = mods.ManualIslandAdapter.GetMarkerPart(draftIsland, "FishingWater")
	local fwTopY = if fwMarker then (fwMarker.CFrame.Position.Y + fwMarker.Size.Y * 0.5) else 0
	check("draft_fishing_water_top_is_9_7", math.abs(fwTopY - 9.7) < 1e-4, "got " .. tostring(fwTopY))
	check("draft_has_manual_ocean_bounds", mods.ManualIslandAdapter.HasManualOceanBounds(draftIsland) == true)

	print(string.format("ART_PIPELINE_SUITE passed=%d failed=0", passed))
end

return runSuite
