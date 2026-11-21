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
	local sHrp = spawnedMerchant:FindFirstChild("HumanoidRootPart")
	local sArm = spawnedMerchant:FindFirstChild("LeftUpperArm")
	check("npc_root_only_anchoring", sHrp.Anchored == true and sArm.Anchored == false, "NPC limbs must remain unanchored")
	check("npc_uses_manual_marker_pos", spawnedMerchant:GetPivot().Position.X == 12 and spawnedMerchant:GetPivot().Position.Z == 34)

	print(string.format("ART_PIPELINE_SUITE passed=%d failed=0", passed))
end

return runSuite
