--!strict
-- TerrainWaterBuilder.luau: Do nuoc bien song that (Terrain:FillBlock cuc bo) & dung dia hinh da tang + tieu canh song dong

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))

local PartFactory = require(script.Parent.PartFactory)

local TerrainWaterBuilder = {}

function TerrainWaterBuilder.ConfigureTerrainWater()
	local terrain = Workspace.Terrain
	terrain.WaterColor = Color3.fromRGB(26, 168, 224)
	terrain.WaterReflectance = 0.62
	terrain.WaterTransparency = 0.28
	terrain.WaterWaveSize = 0.14
	terrain.WaterWaveSpeed = 13
end

function TerrainWaterBuilder.BuildLagoonWater(islandFolder: Folder, islandDef: Types.IslandDef): Part
	local terrain = Workspace.Terrain
	local c = islandDef.centerPosition
	local lagoonCenter = c + Vector3.new(0, 0, 114)
	local waterBoxCf = CFrame.new(lagoonCenter + Vector3.new(0, -2.5, 0))
	local waterBoxSize = Vector3.new(206, 4.4, 118)

	-- Chi don cuc bo vung ho bien cua dao nay, TUYET DOI KHONG goi Terrain:Clear() toan map
	terrain:FillBlock(waterBoxCf, waterBoxSize + Vector3.new(0, 2, 0), Enum.Material.Air)
	terrain:FillBlock(waterBoxCf, waterBoxSize, Enum.Material.Water)

	-- Hop neo vo hinh giu tuong thich 100% voi FishingRoller & gioi han vung nuoc hop le cua dao
	-- Mat tren cua hop nam dung cao do mat nuoc c.Y - 0.3 (8.7 -> 9.7), CanQuery = false de khong chan Raycast!
	local waterBounds = PartFactory.Block(
		islandFolder,
		"FishingWater",
		Vector3.new(206, 1.2, 118),
		CFrame.new(lagoonCenter + Vector3.new(0, -0.9, 0)),
		islandDef.theme.waterColor,
		Enum.Material.SmoothPlastic,
		false,
		1.0
	)
	waterBounds.CanQuery = false
	waterBounds.CastShadow = false
	waterBounds:SetAttribute("IsFishingWater", true)
	waterBounds:SetAttribute("IslandId", islandDef.id)
	return waterBounds
end

local function buildRopeFenceSegment(parent: Instance, p1: Vector3, p2: Vector3)
	PartFactory.VerticalCylinder(parent, "FencePost", 3.2, 0.55, CFrame.new(p1 + Vector3.new(0, 1.6, 0)), Color3.fromRGB(122, 82, 48), Enum.Material.Wood)
	PartFactory.VerticalCylinder(parent, "FencePost", 3.2, 0.55, CFrame.new(p2 + Vector3.new(0, 1.6, 0)), Color3.fromRGB(122, 82, 48), Enum.Material.Wood)
	local mid = (p1 + p2) * 0.5 + Vector3.new(0, 2.3, 0)
	local dist = (p2 - p1).Magnitude
	local ropeCf = CFrame.lookAt(mid, p2 + Vector3.new(0, 2.3, 0))
	PartFactory.Block(parent, "RopeSpan", Vector3.new(0.22, 0.22, dist), ropeCf, Color3.fromRGB(218, 188, 134), Enum.Material.Fabric, false)
end

local function buildCrateAndBarrelCluster(parent: Instance, basePos: Vector3, accent: Color3)
	PartFactory.Block(parent, "WoodCrate", Vector3.new(2.8, 2.8, 2.8), CFrame.new(basePos + Vector3.new(0, 1.4, 0)) * CFrame.Angles(0, math.rad(18), 0), Color3.fromRGB(174, 122, 74), Enum.Material.WoodPlanks)
	PartFactory.VerticalCylinder(parent, "Barrel", 3.1, 2.2, CFrame.new(basePos + Vector3.new(2.6, 1.55, 0.8)), Color3.fromRGB(138, 88, 52), Enum.Material.Wood)
	PartFactory.VerticalCylinder(parent, "BarrelBand", 0.3, 2.32, CFrame.new(basePos + Vector3.new(2.6, 2.1, 0.8)), Color3.fromRGB(58, 64, 76), Enum.Material.Metal)
	PartFactory.VerticalCylinder(parent, "LifeBuoy", 0.45, 2.4, CFrame.new(basePos + Vector3.new(-1.8, 0.3, 1.6)), accent)
end

local function buildCampfire(parent: Instance, pos: Vector3)
	for i = 0, 3 do
		local ang = math.rad(i * 45)
		PartFactory.Block(parent, "FireLog", Vector3.new(0.65, 0.65, 3.6), CFrame.new(pos + Vector3.new(0, 0.35, 0)) * CFrame.Angles(0, ang, 0), Color3.fromRGB(108, 68, 38), Enum.Material.Wood)
	end
	local flame = PartFactory.Ball(parent, "CampfireFlame", 2.1, pos + Vector3.new(0, 1.3, 0), Color3.fromRGB(255, 148, 42), Enum.Material.Neon, false, 0.15)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 168, 72)
	light.Range = 22
	light.Brightness = 1.4
	light.Parent = flame

	local sparks = Instance.new("ParticleEmitter")
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 196, 78), Color3.fromRGB(255, 82, 36))
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
	sparks.Lifetime = NumberRange.new(1.0, 1.8)
	sparks.Rate = 10
	sparks.Speed = NumberRange.new(3, 6)
	sparks.Parent = flame
end

local function buildLighthouse(parent: Instance, basePos: Vector3)
	local m = Instance.new("Model")
	m.Name = "SeasideLighthouse"
	m.Parent = parent

	local colors = {
		Color3.fromRGB(244, 246, 252),
		Color3.fromRGB(238, 78, 72),
		Color3.fromRGB(244, 246, 252),
		Color3.fromRGB(238, 78, 72),
	}
	local curY = 0
	for tier = 1, 4 do
		local h = 6.2
		local diam = 10.5 - tier * 1.15
		PartFactory.VerticalCylinder(m, "Tower_" .. tostring(tier), h, diam, CFrame.new(basePos + Vector3.new(0, curY + h * 0.5, 0)), colors[tier])
		curY += h
	end
	PartFactory.VerticalCylinder(m, "GalleryDeck", 0.8, 8.2, CFrame.new(basePos + Vector3.new(0, curY + 0.4, 0)), Color3.fromRGB(54, 64, 86), Enum.Material.Metal)
	local beacon = PartFactory.VerticalCylinder(m, "BeaconGlass", 4.2, 5.2, CFrame.new(basePos + Vector3.new(0, curY + 2.8, 0)), Color3.fromRGB(255, 236, 128), Enum.Material.Neon, false, 0.12)
	PartFactory.VerticalCylinder(m, "RoofDome", 2.4, 6.2, CFrame.new(basePos + Vector3.new(0, curY + 5.8, 0)), Color3.fromRGB(238, 78, 72))

	local pLight = Instance.new("PointLight")
	pLight.Color = Color3.fromRGB(255, 236, 148)
	pLight.Range = 46
	pLight.Brightness = 2.0
	pLight.Parent = beacon
end

function TerrainWaterBuilder.BuildEnchantAltar(islandFolder: Folder, islandDef: Types.IslandDef)
	local altarModel = Instance.new("Model")
	altarModel.Name = "EnchantAltar"
	altarModel.Parent = islandFolder

	local pos = islandDef.centerPosition + Vector3.new(42, 0, -36)
	PartFactory.VerticalCylinder(altarModel, "AltarStep1", 0.8, 11.5, CFrame.new(pos + Vector3.new(0, 0.4, 0)), Color3.fromRGB(62, 56, 88), Enum.Material.Slate)
	local ped = PartFactory.VerticalCylinder(altarModel, "AltarPedestal", 3.2, 5.4, CFrame.new(pos + Vector3.new(0, 2.2, 0)), Color3.fromRGB(84, 72, 122), Enum.Material.Slate)
	PartFactory.VerticalCylinder(altarModel, "RuneRing", 0.35, 9.6, CFrame.new(pos + Vector3.new(0, 0.85, 0)), Color3.fromRGB(196, 108, 255), Enum.Material.Neon, false, 0.22)

	local relic = PartFactory.Block(
		altarModel,
		"FloatingRelicCrystal",
		Vector3.new(2.1, 3.4, 2.1),
		CFrame.new(pos + Vector3.new(0, 6.2, 0)) * CFrame.Angles(math.rad(18), math.rad(35), math.rad(18)),
		Color3.fromRGB(118, 242, 255),
		Enum.Material.Neon,
		false,
		0.1
	)
	for _, xP in ipairs({ -4.2, 4.2 }) do
		PartFactory.Block(altarModel, "Obelisk", Vector3.new(1.4, 7.6, 1.4), CFrame.new(pos + Vector3.new(xP, 3.8, -2.2)) * CFrame.Angles(0, 0, math.rad(xP > 0 and -8 or 8)), Color3.fromRGB(58, 52, 84), Enum.Material.Slate)
	end

	PartFactory.AddBillboard(relic, "🔮 ENCHANT ALTAR", "Roll Exclusive Rod Enchants!", Color3.fromRGB(216, 132, 255), 3.6)
	PartFactory.AddPrompt(ped, "Enchant Exclusive Rod", "Ancient Altar", 14, "OpenEnchantAltar", {
		IslandId = islandDef.id,
	})
end

function TerrainWaterBuilder.BuildMultiTierReliefAndProps(islandFolder: Folder, islandDef: Types.IslandDef)
	local relief = Instance.new("Model")
	relief.Name = "NaturalReliefAndProps"
	relief.Parent = islandFolder

	local c = islandDef.centerPosition
	local theme = islandDef.theme

	-- Doi co & vach da da tang phia Dong-Bac va Tay-Bac tao chieu sau tu nhien
	PartFactory.Block(relief, "HillWestLower", Vector3.new(34, 4.2, 38), CFrame.new(c + Vector3.new(-58, 2.1, -48)) * CFrame.Angles(0, math.rad(12), 0), theme.cliffColor, Enum.Material.Slate)
	PartFactory.Block(relief, "HillWestTop", Vector3.new(30, 1.2, 34), CFrame.new(c + Vector3.new(-58, 4.6, -48)) * CFrame.Angles(0, math.rad(12), 0), theme.grassColor)

	PartFactory.Block(relief, "HillEastLower", Vector3.new(32, 5.4, 34), CFrame.new(c + Vector3.new(60, 2.7, -48)) * CFrame.Angles(0, math.rad(-14), 0), theme.cliffColor, Enum.Material.Slate)
	PartFactory.Block(relief, "HillEastTop", Vector3.new(28, 1.2, 30), CFrame.new(c + Vector3.new(60, 5.8, -48)) * CFrame.Angles(0, math.rad(-14), 0), theme.grassColor)

	-- Hang rao day thung ven bo bien & thung go doi song
	buildRopeFenceSegment(relief, c + Vector3.new(-44, 0, 56), c + Vector3.new(-16, 0, 56))
	buildRopeFenceSegment(relief, c + Vector3.new(16, 0, 56), c + Vector3.new(44, 0, 56))
	buildCrateAndBarrelCluster(relief, c + Vector3.new(-16, 0, 48), theme.accentColor)
	buildCrateAndBarrelCluster(relief, c + Vector3.new(16, 0, 48), theme.accentColor)
	buildCampfire(relief, c + Vector3.new(20, 0, 14))

	if islandDef.id == 1 then
		buildLighthouse(relief, c + Vector3.new(62, 6.2, -50))
	end

	-- Hat dom dom / bui anh sang lo lung khap quang truong dao
	local emitterHost = PartFactory.Block(relief, "AmbientFireflies", Vector3.new(110, 14, 96), CFrame.new(c + Vector3.new(0, 8, 4)), theme.accentColor, Enum.Material.SmoothPlastic, false, 1)
	emitterHost.CanQuery = false
	local fireflies = Instance.new("ParticleEmitter")
	fireflies.Color = ColorSequence.new(theme.accentColor)
	fireflies.LightEmission = 1
	fireflies.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.22), NumberSequenceKeypoint.new(0.5, 0.38), NumberSequenceKeypoint.new(1, 0) })
	fireflies.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	fireflies.Lifetime = NumberRange.new(4, 7)
	fireflies.Rate = 14
	fireflies.Speed = NumberRange.new(0.6, 1.6)
	fireflies.SpreadAngle = Vector2.new(180, 45)
	fireflies.Parent = emitterHost

	TerrainWaterBuilder.BuildEnchantAltar(islandFolder, islandDef)
end

return TerrainWaterBuilder
