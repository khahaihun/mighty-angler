--!strict
-- IslandScenery3_5.luau: Canh quan Low-Poly cho Dao 3 (Mystic Swamp), Dao 4 (Ember Isle) va Dao 5 (Celestial Deep)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local AssetRegistry = require(Shared:WaitForChild("AssetRegistry"))

local PartFactory = require(script.Parent.PartFactory)

local IslandScenery3_5 = {}

local function buildGiantMushroom(parent: Instance, pos: Vector3, scale: number, capColor: Color3, glowColor: Color3)
	local override = AssetRegistry.TryClone("Trees", "GiantMushroom", true)
	if override then
		override:PivotTo(CFrame.new(pos))
		override.Parent = parent
		return
	end

	local m = Instance.new("Model")
	m.Name = "GiantMushroom"
	m.Parent = parent

	local stemH = 11.5 * scale
	PartFactory.VerticalCylinder(
		m,
		"Stem",
		stemH,
		2.8 * scale,
		CFrame.new(pos + Vector3.new(0, stemH * 0.5, 0)),
		Color3.fromRGB(232, 222, 248)
	)

	local capPos = pos + Vector3.new(0, stemH + 0.8 * scale, 0)
	local cap = PartFactory.Ball(m, "Cap", 11.2 * scale, capPos, capColor, Enum.Material.SmoothPlastic, true)
	cap.Size = Vector3.new(11.6 * scale, 5.4 * scale, 11.6 * scale)

	PartFactory.VerticalCylinder(
		m,
		"UnderGlow",
		0.4 * scale,
		8.8 * scale,
		CFrame.new(capPos - Vector3.new(0, 1.3 * scale, 0)),
		glowColor,
		Enum.Material.Neon,
		false,
		0.25
	)

	for i = 1, 4 do
		local ang = math.rad(i * 90 + 35)
		local spotPos = capPos + Vector3.new(math.cos(ang) * 3.4 * scale, 1.8 * scale, math.sin(ang) * 3.4 * scale)
		PartFactory.Ball(m, "GlowSpot", 1.5 * scale, spotPos, glowColor, Enum.Material.Neon, false)
	end
end

local function buildMysticLantern(parent: Instance, pos: Vector3, glowColor: Color3)
	PartFactory.VerticalCylinder(parent, "LanternPost", 8.5, 0.55, CFrame.new(pos + Vector3.new(0, 4.25, 0)), Color3.fromRGB(58, 44, 82), Enum.Material.Wood)
	PartFactory.Block(parent, "LanternArm", Vector3.new(2.6, 0.45, 0.45), CFrame.new(pos + Vector3.new(1.0, 8.3, 0)), Color3.fromRGB(58, 44, 82), Enum.Material.Wood)
	PartFactory.Ball(parent, "FloatingWisp", 1.6, pos + Vector3.new(2.0, 7.1, 0), glowColor, Enum.Material.Neon, false)
end

local function buildVolcanoSpire(parent: Instance, pos: Vector3, scale: number)
	local m = Instance.new("Model")
	m.Name = "VolcanoSpire"
	m.Parent = parent

	local darkRock = Color3.fromRGB(42, 36, 42)
	local lavaNeon = Color3.fromRGB(255, 102, 32)

	PartFactory.VerticalCylinder(m, "ConeLower", 9.0 * scale, 14.0 * scale, CFrame.new(pos + Vector3.new(0, 4.5 * scale, 0)), darkRock, Enum.Material.Slate)
	PartFactory.VerticalCylinder(m, "ConeUpper", 7.5 * scale, 9.2 * scale, CFrame.new(pos + Vector3.new(0, 11.5 * scale, 0)), darkRock, Enum.Material.Slate)
	PartFactory.VerticalCylinder(m, "LavaCrater", 1.2 * scale, 6.8 * scale, CFrame.new(pos + Vector3.new(0, 15.1 * scale, 0)), lavaNeon, Enum.Material.Neon, false)

	-- Mach nham thach Neon chay doc suon nui
	for i = 1, 3 do
		local ang = math.rad(i * 120)
		local veinCf = CFrame.new(pos + Vector3.new(math.cos(ang) * 4.8 * scale, 7.2 * scale, math.sin(ang) * 4.8 * scale))
			* CFrame.Angles(0, -ang, math.rad(18))
		PartFactory.Block(m, "LavaVein", Vector3.new(0.8 * scale, 11.0 * scale, 0.9 * scale), veinCf, lavaNeon, Enum.Material.Neon, false)
	end
end

local function buildCelestialCrystalCluster(parent: Instance, pos: Vector3, scale: number, mainCol: Color3, subCol: Color3)
	local m = Instance.new("Model")
	m.Name = "CelestialCluster"
	m.Parent = parent

	local specs = {
		{ off = Vector3.new(0, 6.5, 0), h = 13.0, d = 2.8, rx = 0, rz = 0, col = mainCol },
		{ off = Vector3.new(-2.4, 4.2, 1.2), h = 8.5, d = 2.0, rx = 12, rz = 18, col = subCol },
		{ off = Vector3.new(2.4, 4.6, -1.0), h = 9.2, d = 2.1, rx = -14, rz = -16, col = subCol },
	}
	for _, sp in ipairs(specs) do
		local cf = CFrame.new(pos + sp.off * scale) * CFrame.Angles(math.rad(sp.rx), 0, math.rad(sp.rz))
		PartFactory.Block(m, "CrystalShard", Vector3.new(sp.d * scale, sp.h * scale, sp.d * scale), cf, sp.col, Enum.Material.Neon, false, 0.12)
	end

	-- Vong anh sao bay quanh tinh the
	local halo = PartFactory.VerticalCylinder(
		m,
		"StarHalo",
		0.25 * scale,
		10.5 * scale,
		CFrame.new(pos + Vector3.new(0, 7.5 * scale, 0)) * CFrame.Angles(math.rad(18), 0, math.rad(-14)),
		Color3.fromRGB(255, 232, 126),
		Enum.Material.Neon,
		false,
		0.35
	)
	halo.CanCollide = false
end

function IslandScenery3_5.Populate(sceneryFolder: Folder, islandDef: Types.IslandDef)
	local c = islandDef.centerPosition
	local style = islandDef.theme.sceneryStyle

	if style == "Swamp" then
		buildGiantMushroom(sceneryFolder, c + Vector3.new(-60, 0, -48), 1.15, Color3.fromRGB(162, 82, 245), Color3.fromRGB(118, 255, 192))
		buildGiantMushroom(sceneryFolder, c + Vector3.new(60, 0, -48), 1.05, Color3.fromRGB(218, 92, 235), Color3.fromRGB(255, 232, 112))
		buildGiantMushroom(sceneryFolder, c + Vector3.new(-62, 0, 44), 0.95, Color3.fromRGB(116, 98, 248), Color3.fromRGB(122, 255, 214))
		buildGiantMushroom(sceneryFolder, c + Vector3.new(62, 0, 44), 1.00, Color3.fromRGB(178, 86, 242), Color3.fromRGB(118, 255, 192))

		buildMysticLantern(sceneryFolder, c + Vector3.new(-18, 0, 22), Color3.fromRGB(124, 255, 198))
		buildMysticLantern(sceneryFolder, c + Vector3.new(18, 0, 22), Color3.fromRGB(232, 128, 255))
	elseif style == "Volcano" then
		buildVolcanoSpire(sceneryFolder, c + Vector3.new(-60, -0.4, -48), 1.15)
		buildVolcanoSpire(sceneryFolder, c + Vector3.new(60, -0.4, -48), 1.10)
		buildVolcanoSpire(sceneryFolder, c + Vector3.new(-62, -0.4, 44), 0.85)
		buildVolcanoSpire(sceneryFolder, c + Vector3.new(62, -0.4, 44), 0.88)

		-- Khe dung nham phat sang hai ben quang truong
		PartFactory.Block(sceneryFolder, "LavaCrackL", Vector3.new(3.2, 0.22, 42), CFrame.new(c + Vector3.new(-36, 0.08, -8)), Color3.fromRGB(255, 106, 36), Enum.Material.Neon, false)
		PartFactory.Block(sceneryFolder, "LavaCrackR", Vector3.new(3.2, 0.22, 42), CFrame.new(c + Vector3.new(36, 0.08, -8)), Color3.fromRGB(255, 106, 36), Enum.Material.Neon, false)
	elseif style == "Celestial" then
		local cyan = Color3.fromRGB(108, 246, 255)
		local magenta = Color3.fromRGB(255, 116, 238)
		buildCelestialCrystalCluster(sceneryFolder, c + Vector3.new(-60, 0, -48), 1.15, cyan, magenta)
		buildCelestialCrystalCluster(sceneryFolder, c + Vector3.new(60, 0, -48), 1.15, magenta, cyan)
		buildCelestialCrystalCluster(sceneryFolder, c + Vector3.new(-62, 0, 44), 0.98, magenta, cyan)
		buildCelestialCrystalCluster(sceneryFolder, c + Vector3.new(62, 0, 44), 0.98, cyan, magenta)

		-- 2 cot anh sao canh cong COMING SOON phia Bac Dao 5
		buildCelestialCrystalCluster(sceneryFolder, c + Vector3.new(-22, 0, -56), 0.78, Color3.fromRGB(255, 224, 98), cyan)
		buildCelestialCrystalCluster(sceneryFolder, c + Vector3.new(22, 0, -56), 0.78, Color3.fromRGB(255, 224, 98), magenta)
	end
end

return IslandScenery3_5
