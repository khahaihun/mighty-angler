--!strict
-- IslandScenery1_2.luau: Trang tri canh quan Low-Poly cho Dao 1 (Sunny Shores) va Dao 2 (Coral Depths)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local AssetRegistry = require(Shared:WaitForChild("AssetRegistry"))

local PartFactory = require(script.Parent.PartFactory)

local IslandScenery1_2 = {}

local function buildCoconutPalm(parent: Instance, rootPos: Vector3, yawDeg: number, scale: number)
	local override = AssetRegistry.TryClone("Trees", "PalmTree", true)
	if override then
		override:PivotTo(CFrame.new(rootPos) * CFrame.Angles(0, math.rad(yawDeg), 0))
		override.Parent = parent
		return
	end

	local tree = Instance.new("Model")
	tree.Name = "PalmTree"
	tree.Parent = parent

	local trunkColor = Color3.fromRGB(168, 122, 74)
	local leafMain = Color3.fromRGB(72, 198, 78)
	local leafLight = Color3.fromRGB(112, 224, 96)

	local baseCf = CFrame.new(rootPos) * CFrame.Angles(0, math.rad(yawDeg), 0)
	local curCf = baseCf

	for seg = 1, 5 do
		local segHeight = 3.2 * scale
		local diameter = (2.1 - seg * 0.22) * scale
		curCf = curCf * CFrame.Angles(math.rad(6.5), 0, 0)
		local centerCf = curCf * CFrame.new(0, segHeight * 0.5, 0)
		PartFactory.VerticalCylinder(tree, "Trunk_" .. tostring(seg), segHeight, diameter, centerCf, trunkColor, Enum.Material.Wood)
		curCf = curCf * CFrame.new(0, segHeight * 0.94, 0)
	end

	-- 3 qua dua nau duoi tan la
	for c = 1, 3 do
		local ang = math.rad(c * 120)
		local cocoPos = (curCf * CFrame.new(math.cos(ang) * 0.85 * scale, -0.3 * scale, math.sin(ang) * 0.85 * scale)).Position
		PartFactory.Ball(tree, "Coconut", 1.05 * scale, cocoPos, Color3.fromRGB(108, 68, 38), Enum.Material.Wood, false)
	end

	-- 6 tau la dua cong muot
	for f = 1, 6 do
		local leafYaw = math.rad(f * 60)
		local leafCol = if f % 2 == 0 then leafMain else leafLight
		local frondRoot = curCf * CFrame.Angles(0, leafYaw, 0) * CFrame.Angles(math.rad(-26), 0, 0)
		local p1 = frondRoot * CFrame.new(0, 0, -2.6 * scale)
		PartFactory.Block(tree, "FrondInner", Vector3.new(1.8 * scale, 0.32 * scale, 5.2 * scale), p1, leafCol, Enum.Material.SmoothPlastic, false)
		local p2 = frondRoot * CFrame.new(0, -1.05 * scale, -6.2 * scale) * CFrame.Angles(math.rad(-24), 0, 0)
		PartFactory.Block(tree, "FrondTip", Vector3.new(1.3 * scale, 0.26 * scale, 3.8 * scale), p2, leafCol, Enum.Material.SmoothPlastic, false)
	end
end

local function buildBeachUmbrella(parent: Instance, pos: Vector3, canopyColor: Color3)
	local model = Instance.new("Model")
	model.Name = "BeachUmbrella"
	model.Parent = parent

	PartFactory.VerticalCylinder(model, "Pole", 8.6, 0.42, CFrame.new(pos + Vector3.new(0, 4.3, 0)), Color3.fromRGB(240, 244, 250))
	for i = 0, 5 do
		local ang = math.rad(i * 60)
		local col = if i % 2 == 0 then canopyColor else Color3.fromRGB(255, 250, 240)
		local panelCf = CFrame.new(pos + Vector3.new(0, 8.2, 0))
			* CFrame.Angles(0, ang, 0)
			* CFrame.new(0, -0.45, -2.4)
			* CFrame.Angles(math.rad(20), 0, 0)
		PartFactory.Block(model, "CanopySlice", Vector3.new(2.9, 0.35, 4.8), panelCf, col, Enum.Material.SmoothPlastic, false)
	end
	PartFactory.Block(model, "BeachTowel", Vector3.new(4.2, 0.18, 7.2), CFrame.new(pos + Vector3.new(3.2, 0.12, 0.6)) * CFrame.Angles(0, math.rad(15), 0), canopyColor, Enum.Material.SmoothPlastic, false)
end

local function buildRockCluster(parent: Instance, pos: Vector3, rockColor: Color3, scale: number)
	PartFactory.Block(
		parent,
		"BoulderMain",
		Vector3.new(5.5 * scale, 3.6 * scale, 4.8 * scale),
		CFrame.new(pos + Vector3.new(0, 1.4 * scale, 0)) * CFrame.Angles(math.rad(8), math.rad(24), math.rad(-6)),
		rockColor,
		Enum.Material.Slate
	)
	PartFactory.Block(
		parent,
		"BoulderSide",
		Vector3.new(3.4 * scale, 2.2 * scale, 3.2 * scale),
		CFrame.new(pos + Vector3.new(2.8 * scale, 0.9 * scale, 1.2 * scale)) * CFrame.Angles(math.rad(-10), math.rad(48), math.rad(5)),
		rockColor,
		Enum.Material.Slate
	)
end

local function buildCoralArch(parent: Instance, pos: Vector3, yawDeg: number, coralColor: Color3, glowColor: Color3)
	local model = Instance.new("Model")
	model.Name = "CoralFormation"
	model.Parent = parent

	local base = CFrame.new(pos) * CFrame.Angles(0, math.rad(yawDeg), 0)
	for i = -2, 2 do
		local h = 7.5 - math.abs(i) * 1.4
		local branchCf = base * CFrame.new(i * 2.1, h * 0.5, 0) * CFrame.Angles(0, 0, math.rad(i * -10))
		PartFactory.VerticalCylinder(model, "CoralBranch", h, 1.5, branchCf, coralColor)
		local tipPos = (branchCf * CFrame.new(0, h * 0.5 + 0.5, 0)).Position
		PartFactory.Ball(model, "CoralTipGlow", 1.85, tipPos, glowColor, Enum.Material.Neon, false)
	end

	local bubbleEmitterPart = PartFactory.Ball(model, "BubbleSource", 1.0, pos + Vector3.new(0, 1.2, 0), glowColor, Enum.Material.Neon, false, 1)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(Color3.fromRGB(175, 245, 255))
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 0.9),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(2.5, 4.2)
	emitter.Rate = 6
	emitter.Speed = NumberRange.new(2.5, 4.8)
	emitter.Parent = bubbleEmitterPart
end

function IslandScenery1_2.Populate(sceneryFolder: Folder, islandDef: Types.IslandDef)
	local c = islandDef.centerPosition
	local style = islandDef.theme.sceneryStyle

	if style == "Sunny" then
		local palmSpots = {
			{ off = Vector3.new(-60, 0, -52), yaw = 25, sc = 1.05 },
			{ off = Vector3.new(58, 0, -50), yaw = -40, sc = 1.12 },
			{ off = Vector3.new(-62, 0, 44), yaw = 70, sc = 0.98 },
			{ off = Vector3.new(60, 0, 44), yaw = -85, sc = 1.02 },
			{ off = Vector3.new(-28, 0, -56), yaw = 15, sc = 0.92 },
			{ off = Vector3.new(30, 0, -55), yaw = -20, sc = 0.95 },
		}
		for _, p in ipairs(palmSpots) do
			buildCoconutPalm(sceneryFolder, c + p.off, p.yaw, p.sc)
		end

		buildBeachUmbrella(sceneryFolder, c + Vector3.new(-48, -0.2, 54), Color3.fromRGB(255, 98, 88))
		buildBeachUmbrella(sceneryFolder, c + Vector3.new(48, -0.2, 54), Color3.fromRGB(64, 178, 255))

		buildRockCluster(sceneryFolder, c + Vector3.new(-66, -0.2, -38), islandDef.theme.cliffColor, 1.1)
		buildRockCluster(sceneryFolder, c + Vector3.new(66, -0.2, -36), islandDef.theme.cliffColor, 1.0)
	elseif style == "Coral" then
		local coralSpots = {
			{ off = Vector3.new(-60, 0, -48), yaw = 20, col = Color3.fromRGB(255, 106, 168), glow = Color3.fromRGB(112, 248, 255) },
			{ off = Vector3.new(60, 0, -48), yaw = -25, col = Color3.fromRGB(82, 212, 255), glow = Color3.fromRGB(255, 168, 232) },
			{ off = Vector3.new(-60, 0, 44), yaw = 45, col = Color3.fromRGB(168, 112, 255), glow = Color3.fromRGB(98, 255, 218) },
			{ off = Vector3.new(60, 0, 44), yaw = -45, col = Color3.fromRGB(255, 152, 92), glow = Color3.fromRGB(112, 235, 255) },
		}
		for _, sp in ipairs(coralSpots) do
			buildCoralArch(sceneryFolder, c + sp.off, sp.yaw, sp.col, sp.glow)
		end
		buildRockCluster(sceneryFolder, c + Vector3.new(-65, -0.2, 10), islandDef.theme.cliffColor, 1.15)
		buildRockCluster(sceneryFolder, c + Vector3.new(65, -0.2, -16), islandDef.theme.cliffColor, 1.15)
	end
end

return IslandScenery1_2
