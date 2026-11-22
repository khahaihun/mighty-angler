--!strict
-- IslandScenery1_2.luau: Trang tri canh quan Low-Poly Gu B song dong, bat doi xung cho Dao 1 (Sunny) va Dao 2 (Coral)

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

	local trunkColor = Color3.fromRGB(174, 124, 72)
	local leafMain = Color3.fromRGB(64, 206, 82)
	local leafLight = Color3.fromRGB(116, 232, 98)

	local curCf = CFrame.new(rootPos) * CFrame.Angles(0, math.rad(yawDeg), 0)
	for seg = 1, 5 do
		local segHeight = 3.2 * scale
		local diameter = (2.1 - seg * 0.22) * scale
		curCf = curCf * CFrame.Angles(math.rad(6.5), 0, 0)
		local centerCf = curCf * CFrame.new(0, segHeight * 0.5, 0)
		PartFactory.VerticalCylinder(tree, "Trunk_" .. tostring(seg), segHeight, diameter, centerCf, trunkColor, Enum.Material.Wood)
		curCf = curCf * CFrame.new(0, segHeight * 0.94, 0)
	end

	for c = 1, 3 do
		local ang = math.rad(c * 120)
		local cocoPos = (curCf * CFrame.new(math.cos(ang) * 0.85 * scale, -0.3 * scale, math.sin(ang) * 0.85 * scale)).Position
		PartFactory.Ball(tree, "Coconut", 1.05 * scale, cocoPos, Color3.fromRGB(112, 68, 36), Enum.Material.Wood, false)
	end

	for f = 1, 6 do
		local leafYaw = math.rad(f * 60)
		local leafCol = if f % 2 == 0 then leafMain else leafLight
		local frondRoot = curCf * CFrame.Angles(0, leafYaw, 0) * CFrame.Angles(math.rad(-26), 0, 0)
		PartFactory.Block(tree, "FrondInner", Vector3.new(1.8 * scale, 0.32 * scale, 5.2 * scale), frondRoot * CFrame.new(0, 0, -2.6 * scale), leafCol, Enum.Material.SmoothPlastic, false)
		PartFactory.Block(tree, "FrondTip", Vector3.new(1.3 * scale, 0.26 * scale, 3.8 * scale), frondRoot * CFrame.new(0, -1.05 * scale, -6.2 * scale) * CFrame.Angles(math.rad(-24), 0, 0), leafCol, Enum.Material.SmoothPlastic, false)
	end
end

local function buildTropicalBush(parent: Instance, pos: Vector3, flowerColor: Color3, scale: number)
	local model = Instance.new("Model")
	model.Name = "TropicalBush"
	model.Parent = parent

	local bushMain = Color3.fromRGB(68, 198, 78)
	local bushBright = Color3.fromRGB(108, 226, 94)
	PartFactory.Ball(model, "BushCore", 3.4 * scale, pos + Vector3.new(0, 1.2 * scale, 0), bushMain, Enum.Material.SmoothPlastic, false)
	PartFactory.Ball(model, "BushSideA", 2.5 * scale, pos + Vector3.new(1.4 * scale, 0.95 * scale, 0.6 * scale), bushBright, Enum.Material.SmoothPlastic, false)
	PartFactory.Ball(model, "BushSideB", 2.3 * scale, pos + Vector3.new(-1.3 * scale, 0.9 * scale, -0.5 * scale), bushMain, Enum.Material.SmoothPlastic, false)
	PartFactory.Ball(model, "FlowerA", 0.72 * scale, pos + Vector3.new(0.6 * scale, 2.5 * scale, -0.4 * scale), flowerColor, Enum.Material.SmoothPlastic, false)
	PartFactory.Ball(model, "FlowerB", 0.62 * scale, pos + Vector3.new(-0.9 * scale, 1.9 * scale, 0.7 * scale), Color3.fromRGB(255, 224, 72), Enum.Material.SmoothPlastic, false)
end

local function buildBeachedRowboat(parent: Instance, pos: Vector3, yawDeg: number)
	local boat = Instance.new("Model")
	boat.Name = "BeachedRowboat"
	boat.Parent = parent

	local base = CFrame.new(pos) * CFrame.Angles(math.rad(4), math.rad(yawDeg), math.rad(-6))
	local hullCol = Color3.fromRGB(186, 128, 74)
	local trimCol = Color3.fromRGB(56, 174, 245)
	PartFactory.Block(boat, "HullBottom", Vector3.new(4.2, 0.7, 9.6), base * CFrame.new(0, 0.5, 0), hullCol, Enum.Material.WoodPlanks)
	PartFactory.Block(boat, "HullSideL", Vector3.new(0.45, 1.5, 9.2), base * CFrame.new(-2.0, 1.25, 0), hullCol, Enum.Material.WoodPlanks)
	PartFactory.Block(boat, "HullSideR", Vector3.new(0.45, 1.5, 9.2), base * CFrame.new(2.0, 1.25, 0), hullCol, Enum.Material.WoodPlanks)
	PartFactory.Block(boat, "HullBow", Vector3.new(3.6, 1.6, 1.2), base * CFrame.new(0, 1.3, -4.6), trimCol, Enum.Material.SmoothPlastic)
	PartFactory.Block(boat, "HullStern", Vector3.new(4.2, 1.5, 0.6), base * CFrame.new(0, 1.25, 4.6), trimCol, Enum.Material.SmoothPlastic)
	PartFactory.Block(boat, "SeatBench", Vector3.new(3.7, 0.35, 1.2), base * CFrame.new(0, 1.35, 0.2), Color3.fromRGB(224, 178, 118), Enum.Material.Wood)
	PartFactory.Block(boat, "OarShaft", Vector3.new(0.22, 0.22, 6.4), base * CFrame.new(0.9, 1.65, -0.4) * CFrame.Angles(0, math.rad(14), 0), Color3.fromRGB(236, 206, 152), Enum.Material.Wood, false)
end

local function buildBeachUmbrella(parent: Instance, pos: Vector3, yawDeg: number, canopyColor: Color3)
	local model = Instance.new("Model")
	model.Name = "BeachUmbrella"
	model.Parent = parent

	local base = CFrame.new(pos) * CFrame.Angles(0, math.rad(yawDeg), 0)
	PartFactory.VerticalCylinder(model, "Pole", 8.6, 0.42, base * CFrame.new(0, 4.3, 0), Color3.fromRGB(246, 248, 255))
	for i = 0, 5 do
		local ang = math.rad(i * 60)
		local col = if i % 2 == 0 then canopyColor else Color3.fromRGB(255, 250, 240)
		local panelCf = base * CFrame.new(0, 8.2, 0) * CFrame.Angles(0, ang, 0) * CFrame.new(0, -0.45, -2.4) * CFrame.Angles(math.rad(20), 0, 0)
		PartFactory.Block(model, "CanopySlice", Vector3.new(2.9, 0.35, 4.8), panelCf, col, Enum.Material.SmoothPlastic, false)
	end
	PartFactory.Block(model, "BeachTowel", Vector3.new(4.2, 0.18, 7.2), base * CFrame.new(3.1, 0.12, 0.8) * CFrame.Angles(0, math.rad(18), 0), canopyColor, Enum.Material.SmoothPlastic, false)
	PartFactory.Ball(model, "Starfish", 0.9, (base * CFrame.new(-2.4, 0.14, 1.9)).Position, Color3.fromRGB(255, 122, 86), Enum.Material.SmoothPlastic, false)
end

local function buildRockCluster(parent: Instance, pos: Vector3, rockColor: Color3, scale: number, yawDeg: number)
	local base = CFrame.new(pos) * CFrame.Angles(0, math.rad(yawDeg), 0)
	PartFactory.Block(parent, "BoulderMain", Vector3.new(5.5 * scale, 3.6 * scale, 4.8 * scale), base * CFrame.new(0, 1.4 * scale, 0) * CFrame.Angles(math.rad(8), math.rad(24), math.rad(-6)), rockColor, Enum.Material.Slate)
	PartFactory.Block(parent, "BoulderSide", Vector3.new(3.4 * scale, 2.2 * scale, 3.2 * scale), base * CFrame.new(2.8 * scale, 0.9 * scale, 1.2 * scale) * CFrame.Angles(math.rad(-10), math.rad(48), math.rad(5)), rockColor, Enum.Material.Slate)
end

local function buildCoralArch(parent: Instance, pos: Vector3, yawDeg: number, scale: number, coralColor: Color3, glowColor: Color3)
	local model = Instance.new("Model")
	model.Name = "CoralFormation"
	model.Parent = parent

	local base = CFrame.new(pos) * CFrame.Angles(0, math.rad(yawDeg), 0)
	for i = -2, 2 do
		local h = (7.4 - math.abs(i) * 1.35) * scale
		local branchCf = base * CFrame.new(i * 2.1 * scale, h * 0.5, 0) * CFrame.Angles(0, 0, math.rad(i * -10))
		PartFactory.VerticalCylinder(model, "CoralBranch", h, 1.45 * scale, branchCf, coralColor)
		local tipPos = (branchCf * CFrame.new(0, h * 0.5 + 0.45 * scale, 0)).Position
		PartFactory.Ball(model, "CoralTipGlow", 1.75 * scale, tipPos, glowColor, Enum.Material.Neon, false)
	end

	local bubbleEmitterPart = PartFactory.Ball(model, "BubbleSource", 1.0, pos + Vector3.new(0, 1.2, 0), glowColor, Enum.Material.Neon, false, 1)
	local emitter = Instance.new("ParticleEmitter")
	emitter:SetAttribute("ClientBudgetManaged", true)
	emitter.Color = ColorSequence.new(Color3.fromRGB(175, 245, 255))
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0.9) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1) })
	emitter.Lifetime = NumberRange.new(2.5, 4.2)
	emitter.Rate = 6
	emitter.Speed = NumberRange.new(2.5, 4.8)
	emitter.Parent = bubbleEmitterPart
end

local function buildSeaAnemone(parent: Instance, pos: Vector3, bodyCol: Color3, tipCol: Color3)
	local model = Instance.new("Model")
	model.Name = "SeaAnemone"
	model.Parent = parent

	PartFactory.VerticalCylinder(model, "AnemoneBase", 1.2, 3.2, CFrame.new(pos + Vector3.new(0, 0.6, 0)), bodyCol)
	for i = 0, 5 do
		local ang = math.rad(i * 60)
		local cf = CFrame.new(pos + Vector3.new(math.cos(ang) * 0.95, 1.9, math.sin(ang) * 0.95)) * CFrame.Angles(math.rad(16 * math.sin(ang)), 0, math.rad(-16 * math.cos(ang)))
		PartFactory.VerticalCylinder(model, "Tentacle", 2.2, 0.55, cf, bodyCol, Enum.Material.SmoothPlastic, false)
		PartFactory.Ball(model, "TentacleTip", 0.65, (cf * CFrame.new(0, 1.2, 0)).Position, tipCol, Enum.Material.Neon, false)
	end
end

local function buildKelpCluster(parent: Instance, pos: Vector3, yawDeg: number)
	local model = Instance.new("Model")
	model.Name = "KelpCluster"
	model.Parent = parent
	local base = CFrame.new(pos) * CFrame.Angles(0, math.rad(yawDeg), 0)
	local greens = { Color3.fromRGB(48, 194, 152), Color3.fromRGB(72, 224, 178), Color3.fromRGB(38, 168, 138) }
	for idx, off in ipairs({ Vector3.new(-0.9, 0, -0.4), Vector3.new(0.2, 0, 0.7), Vector3.new(1.1, 0, -0.3) }) do
		local h = 5.4 + idx * 1.4
		local cf = base * CFrame.new(off + Vector3.new(0, h * 0.5, 0)) * CFrame.Angles(math.rad(6 * idx - 10), math.rad(idx * 35), math.rad(5))
		PartFactory.Block(model, "KelpBlade", Vector3.new(1.1, h, 0.26), cf, greens[idx], Enum.Material.SmoothPlastic, false)
	end
end

function IslandScenery1_2.Populate(sceneryFolder: Folder, islandDef: Types.IslandDef)
	local c = islandDef.centerPosition
	local style = islandDef.theme.sceneryStyle

	if style == "Sunny" then
		-- Cum dua lech nhien theo nhom lon-nho (bo bo cuc doi xung guong cung nhac)
		local palmSpots = {
			{ off = Vector3.new(-63, 0, -49), yaw = 28, sc = 1.14 },
			{ off = Vector3.new(-54, 0, -57), yaw = 72, sc = 0.86 },
			{ off = Vector3.new(57, 0, -42), yaw = -48, sc = 1.08 },
			{ off = Vector3.new(26, 0, -61), yaw = -18, sc = 0.94 },
			{ off = Vector3.new(-66, 0, 39), yaw = 82, sc = 1.02 },
			{ off = Vector3.new(63, 0, 48), yaw = -112, sc = 0.92 },
			{ off = Vector3.new(-22, 0, -58), yaw = 12, sc = 0.88 },
		}
		for _, p in ipairs(palmSpots) do
			buildCoconutPalm(sceneryFolder, c + p.off, p.yaw, p.sc)
		end

		local bushSpots = {
			{ off = Vector3.new(-42, 0, -48), col = Color3.fromRGB(255, 96, 148), sc = 1.05 },
			{ off = Vector3.new(34, 0, -46), col = Color3.fromRGB(255, 138, 72), sc = 0.92 },
			{ off = Vector3.new(-64, 0, 12), col = Color3.fromRGB(255, 92, 128), sc = 0.88 },
			{ off = Vector3.new(61, 0, 26), col = Color3.fromRGB(255, 184, 62), sc = 1.12 },
			{ off = Vector3.new(-36, 0, 52), col = Color3.fromRGB(255, 112, 168), sc = 0.84 },
		}
		for _, b in ipairs(bushSpots) do
			buildTropicalBush(sceneryFolder, c + b.off, b.col, b.sc)
		end

		buildBeachUmbrella(sceneryFolder, c + Vector3.new(-51, -0.2, 53), 18, Color3.fromRGB(255, 88, 78))
		buildBeachUmbrella(sceneryFolder, c + Vector3.new(44, -0.2, 57), -34, Color3.fromRGB(52, 182, 255))
		buildBeachedRowboat(sceneryFolder, c + Vector3.new(56, -0.35, 34), -32)

		buildRockCluster(sceneryFolder, c + Vector3.new(-68, -0.2, -32), islandDef.theme.cliffColor, 1.18, 12)
		buildRockCluster(sceneryFolder, c + Vector3.new(64, -0.2, -24), islandDef.theme.cliffColor, 0.92, -42)
		buildRockCluster(sceneryFolder, c + Vector3.new(-58, -0.2, 56), islandDef.theme.cliffColor, 0.78, 65)
	elseif style == "Coral" then
		-- San ho, hai quy & tao bien bat doi xung cho Dao 2 (Coral Depths)
		local coralSpots = {
			{ off = Vector3.new(-63, 0, -44), yaw = 24, sc = 1.12, col = Color3.fromRGB(255, 102, 168), glow = Color3.fromRGB(112, 248, 255) },
			{ off = Vector3.new(56, 0, -52), yaw = -32, sc = 0.94, col = Color3.fromRGB(72, 212, 255), glow = Color3.fromRGB(255, 168, 232) },
			{ off = Vector3.new(-55, 0, 48), yaw = 52, sc = 0.98, col = Color3.fromRGB(172, 112, 255), glow = Color3.fromRGB(98, 255, 218) },
			{ off = Vector3.new(64, 0, 38), yaw = -58, sc = 1.08, col = Color3.fromRGB(255, 152, 92), glow = Color3.fromRGB(112, 235, 255) },
			{ off = Vector3.new(-24, 0, -58), yaw = 14, sc = 0.82, col = Color3.fromRGB(255, 126, 186), glow = Color3.fromRGB(148, 255, 236) },
		}
		for _, sp in ipairs(coralSpots) do
			buildCoralArch(sceneryFolder, c + sp.off, sp.yaw, sp.sc, sp.col, sp.glow)
		end

		buildSeaAnemone(sceneryFolder, c + Vector3.new(-42, 0, 52), Color3.fromRGB(246, 98, 178), Color3.fromRGB(255, 224, 112))
		buildSeaAnemone(sceneryFolder, c + Vector3.new(47, 0, -28), Color3.fromRGB(82, 198, 255), Color3.fromRGB(168, 255, 224))
		buildKelpCluster(sceneryFolder, c + Vector3.new(54, 0, 52), -24)
		buildKelpCluster(sceneryFolder, c + Vector3.new(-66, 0, -14), 38)
		buildRockCluster(sceneryFolder, c + Vector3.new(-65, -0.2, 14), islandDef.theme.cliffColor, 1.15, 20)
		buildRockCluster(sceneryFolder, c + Vector3.new(62, -0.2, -12), islandDef.theme.cliffColor, 0.95, -35)
	end
end

return IslandScenery1_2
