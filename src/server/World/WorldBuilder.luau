--!strict
-- WorldBuilder.luau: Dieu phoi dung Lighting tuoi sang, dia hinh Low-Poly cac Dao va SpawnLocation

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local AssetRegistry = require(Shared:WaitForChild("AssetRegistry"))
local IslandsRegistry = require(Shared:WaitForChild("Config"):WaitForChild("Islands"))

local PartFactory = require(script.Parent.PartFactory)
local PropsBuilder = require(script.Parent.PropsBuilder)
local IslandScenery1_2 = require(script.Parent.IslandScenery1_2)
local TerrainWaterBuilder = require(script.Parent.TerrainWaterBuilder)
local NpcBuilder = require(script.Parent.NpcBuilder)
local ManualIslandAdapter = require(script.Parent.ManualIslandAdapter)

local WorldBuilder = {}

local WORLD_FOLDER_NAME = "MightyWorld"

function WorldBuilder.SetupLighting()
	Lighting.Brightness = 2.4
	Lighting.ClockTime = 14.2
	Lighting.OutdoorAmbient = Color3.fromRGB(138, 158, 182)
	Lighting.Ambient = Color3.fromRGB(96, 112, 134)
	Lighting.GlobalShadows = true

	if not Lighting:FindFirstChild("MightyAtmosphere") then
		local atmo = Instance.new("Atmosphere")
		atmo.Name = "MightyAtmosphere"
		atmo.Density = 0.26
		atmo.Offset = 0.15
		atmo.Color = Color3.fromRGB(196, 232, 255)
		atmo.Decay = Color3.fromRGB(132, 188, 245)
		atmo.Glare = 0.15
		atmo.Haze = 1.1
		atmo.Parent = Lighting
	end

	if not Lighting:FindFirstChild("MightyBloom") then
		local bloom = Instance.new("BloomEffect")
		bloom.Name = "MightyBloom"
		bloom.Intensity = 0.35
		bloom.Size = 22
		bloom.Threshold = 1.15
		bloom.Parent = Lighting
	end

	if not Lighting:FindFirstChild("MightyColor") then
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "MightyColor"
		cc.Brightness = 0.03
		cc.Contrast = 0.08
		cc.Saturation = 0.16
		cc.Parent = Lighting
	end
end

local function getDefaultEggCosts(islandId: number): (number, number)
	local goldCosts = { 350, 3500, 32000, 260000, 1800000 }
	local gemCosts = { 120, 160, 210, 270, 350 }
	return goldCosts[islandId] or 500, gemCosts[islandId] or 150
end

function WorldBuilder.BuildIsland(
	worldRoot: Folder,
	islandDef: Types.IslandDef,
	nextIsland: Types.IslandDef?,
	scenery35Module: any?
): Folder
	local islandFolder = Instance.new("Folder")
	islandFolder.Name = "Island_" .. tostring(islandDef.id)
	islandFolder:SetAttribute("IslandId", islandDef.id)
	islandFolder.Parent = worldRoot

	local c = islandDef.centerPosition
	local theme = islandDef.theme
	local manualIsland = ManualIslandAdapter.FindManualIsland(islandDef.id)
	if manualIsland then
		islandFolder:SetAttribute("IsManualTerrain", true)
		ManualIslandAdapter.HideRuntimeMarkers(manualIsland)
	end

	-- 1 & 2. Dia hinh dat + Ho Bien Phia Nam
	if manualIsland then
		local markerWater = ManualIslandAdapter.BuildFishingWaterBounds(islandFolder, islandDef, manualIsland)
		if not markerWater then
			TerrainWaterBuilder.BuildLagoonWater(islandFolder, islandDef)
		end
	else
		-- Chan da ngam & Bo cat & San co trung tam (Mat san chinh nam dung cao do c.Y = 10)
		PartFactory.Block(
			islandFolder,
			"CliffUnderBase",
			Vector3.new(138, 14, 132),
			CFrame.new(c + Vector3.new(0, -14.0, -4)),
			theme.cliffColor,
			Enum.Material.Slate
		)
		PartFactory.Block(
			islandFolder,
			"BeachRim",
			Vector3.new(158, 7.2, 148),
			CFrame.new(c + Vector3.new(0, -4.0, -2)),
			theme.sandColor,
			Enum.Material.SmoothPlastic
		)
		PartFactory.Block(
			islandFolder,
			"MainPlazaGrass",
			Vector3.new(142, 0.9, 130),
			CFrame.new(c + Vector3.new(0, -0.45, -4)),
			theme.grassColor,
			Enum.Material.SmoothPlastic
		)

		-- Duong lat da tu trung tam ra Cau go & Cong dao
		for step = -46, 52, 12 do
			PartFactory.Block(
				islandFolder,
				"PathStone",
				Vector3.new(11, 0.16, 8.5),
				CFrame.new(c + Vector3.new(0, 0.08, step)),
				Color3.fromRGB(228, 222, 208)
			)
		end

		local lagoonCenter = c + Vector3.new(0, 0, 114)
		PartFactory.Block(
			islandFolder,
			"LagoonSeabed",
			Vector3.new(210, 2.0, 124),
			CFrame.new(lagoonCenter + Vector3.new(0, -4.8, 0)),
			theme.sandColor
		)
		PartFactory.Wedge(
			islandFolder,
			"BeachSlope",
			Vector3.new(156, 3.8, 12),
			CFrame.new(c + Vector3.new(0, -1.9, 64)) * CFrame.Angles(0, math.rad(180), 0),
			theme.sandColor
		)
		TerrainWaterBuilder.BuildLagoonWater(islandFolder, islandDef)
	end

	-- Keep player collision; shared fishing filter explicitly excludes these boundaries.
	if not (manualIsland and ManualIslandAdapter.HasManualOceanBounds(manualIsland)) then
		local boundS = PartFactory.Block(islandFolder, "OceanBoundS", Vector3.new(214, 24, 2), CFrame.new(c + Vector3.new(0, 6, 174)), theme.waterColor, Enum.Material.SmoothPlastic, true, 1)
		local boundW = PartFactory.Block(islandFolder, "OceanBoundW", Vector3.new(2, 24, 256), CFrame.new(c + Vector3.new(-106, 6, 48)), theme.waterColor, Enum.Material.SmoothPlastic, true, 1)
		local boundE = PartFactory.Block(islandFolder, "OceanBoundE", Vector3.new(2, 24, 256), CFrame.new(c + Vector3.new(106, 6, 48)), theme.waterColor, Enum.Material.SmoothPlastic, true, 1)
		boundS:SetAttribute("FishingRayIgnore", true)
		boundW:SetAttribute("FishingRayIgnore", true)
		boundE:SetAttribute("FishingRayIgnore", true)
	end

	-- 3. Diem hoi sinh / Teleport Pad giua Dao
	local spawnCf = ManualIslandAdapter.GetMarkerCFrame(
		manualIsland,
		"Spawn",
		CFrame.new(c + Vector3.new(0, 0.25, 2)) * CFrame.Angles(0, math.rad(180), 0)
	)
	if islandDef.id == 1 then
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "IslandSpawn"
		spawn.Size = Vector3.new(10, 0.5, 10)
		spawn.CFrame = spawnCf
		spawn.Anchored = true
		spawn.Neutral = true
		spawn.Color = theme.accentColor
		spawn.Material = Enum.Material.Neon
		spawn.Transparency = 0.35
		spawn.TopSurface = Enum.SurfaceType.Smooth
		spawn.Parent = islandFolder
	else
		local arrivalPad = PartFactory.VerticalCylinder(
			islandFolder,
			"IslandSpawn",
			0.45,
			9.5,
			spawnCf,
			theme.accentColor,
			Enum.Material.Neon,
			true,
			0.3
		)
		arrivalPad:SetAttribute("IslandId", islandDef.id)
	end

	-- 4. Dung cac cong trinh tuong tac (ton trong IslandMarkers neu la dao Terrain dung tay)
	PropsBuilder.BuildWoodenDock(islandFolder, c, theme.accentColor, manualIsland)
	PropsBuilder.BuildMarketStalls(islandFolder, islandDef, manualIsland)
	PropsBuilder.BuildGymZone(islandFolder, islandDef, manualIsland)
	local goldEggCost, gemEggCost = getDefaultEggCosts(islandDef.id)
	PropsBuilder.BuildEggPedestals(islandFolder, islandDef, goldEggCost, gemEggCost, manualIsland)
	PropsBuilder.BuildPortals(islandFolder, islandDef, nextIsland, manualIsland)
	if manualIsland then
		TerrainWaterBuilder.BuildEnchantAltar(islandFolder, islandDef, manualIsland)
	else
		TerrainWaterBuilder.BuildMultiTierReliefAndProps(islandFolder, islandDef)
	end
	NpcBuilder.BuildIslandNpcs(islandFolder, islandDef, manualIsland)

	-- 5. Trang tri canh quan theo chu de Dao (chi chay khi dung dao thu tuc)
	if not manualIsland then
		local sceneryFolder = Instance.new("Folder")
		sceneryFolder.Name = "Scenery"
		sceneryFolder.Parent = islandFolder

		if theme.sceneryStyle == "Sunny" or theme.sceneryStyle == "Coral" then
			IslandScenery1_2.Populate(sceneryFolder, islandDef)
		elseif scenery35Module ~= nil then
			scenery35Module.Populate(sceneryFolder, islandDef)
		end
	end

	return islandFolder
end

function WorldBuilder.BuildAll(): Folder
	AssetRegistry.EnsureFolders()
	WorldBuilder.SetupLighting()
	TerrainWaterBuilder.ConfigureTerrainWater()

	local existing = Workspace:FindFirstChild(WORLD_FOLDER_NAME)
	if existing and existing:IsA("Folder") then
		existing:ClearAllChildren()
	end

	local worldRoot: Folder
	if existing and existing:IsA("Folder") then
		worldRoot = existing
	else
		worldRoot = Instance.new("Folder")
		worldRoot.Name = WORLD_FOLDER_NAME
		worldRoot.Parent = Workspace
	end

	-- Kiem tra module canh quan Dao 3-5 neu da co (se them o Chang 2)
	local scenery35Mod: any = nil
	local found35 = script.Parent:FindFirstChild("IslandScenery3_5")
	if found35 and found35:IsA("ModuleScript") then
		scenery35Mod = require(found35) :: any
	end

	local list = IslandsRegistry.List
	for idx, islandDef in ipairs(list) do
		local nextIsland = list[idx + 1]
		WorldBuilder.BuildIsland(worldRoot, islandDef, nextIsland, scenery35Mod)
	end

	return worldRoot
end

function WorldBuilder.GetIslandSpawnCFrame(islandId: number): CFrame
	local def = IslandsRegistry.Get(islandId)
	local defaultCf = CFrame.new(def.centerPosition + Vector3.new(0, 3.8, 2)) * CFrame.Angles(0, math.rad(180), 0)
	local manualIsland = ManualIslandAdapter.FindManualIsland(islandId)
	if manualIsland then
		local marker = ManualIslandAdapter.GetMarkerPart(manualIsland, "Spawn")
		if marker then
			return marker.CFrame * CFrame.new(0, 3.55, 0)
		end
	end
	return defaultCf
end

return WorldBuilder
