--!strict
-- RodAndWeightBuilder.luau: Mo hinh 3D cho 6 Can thuong + 3 Can Exclusive phat sang & Quả Tạ 3D / Đòn Tạ cầm tay khi tập Gym

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local AssetRegistry = require(Shared:WaitForChild("AssetRegistry"))

local RodAndWeightBuilder = {}

local function addWeldedPart(m: Model, handle: BasePart, name: string, shape: Enum.PartType, sz: Vector3, relCf: CFrame, col: Color3, mat: Enum.Material, anchored: boolean): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape
	p.Size = sz
	p.Color = col
	p.Material = mat
	p.Anchored = anchored
	p.CanCollide = false
	p.CanQuery = false
	p.Massless = true
	p.CFrame = handle.CFrame * relCf
	p.Parent = m
	if not anchored then
		local w = Instance.new("WeldConstraint")
		w.Part0 = handle
		w.Part1 = p
		w.Parent = p
	end
	return p
end

local function buildRodInternal(rodDef: Types.RodDef, anchored: boolean): (Model, BasePart, Attachment)
	local m = Instance.new("Model")
	m.Name = "EquippedFishingRod"

	local grip = Instance.new("Part")
	grip.Name = "Grip"
	grip.Size = Vector3.new(0.28, 0.28, 1.55)
	grip.Color = Color3.fromRGB(52, 42, 40)
	grip.Material = Enum.Material.SmoothPlastic
	grip.Anchored = anchored
	grip.CanCollide = false
	grip.CanQuery = false
	grip.Massless = true
	grip.CFrame = CFrame.new()
	grip.Parent = m
	m.PrimaryPart = grip

	local isNeon = rodDef.isExclusive == true or rodDef.order >= 4
	local accMat = if isNeon then Enum.Material.Neon else Enum.Material.Metal

	addWeldedPart(m, grip, "ReelHousing", Enum.PartType.Cylinder, Vector3.new(0.40, 0.72, 0.72), CFrame.new(0, -0.34, -0.45), rodDef.accentColor, accMat, anchored)
	addWeldedPart(m, grip, "Guard", Enum.PartType.Block, Vector3.new(0.52, 0.52, 0.18), CFrame.new(0, 0, -0.78), rodDef.accentColor, accMat, anchored)
	addWeldedPart(m, grip, "ShaftLower", Enum.PartType.Block, Vector3.new(0.20, 0.20, 3.25), CFrame.new(0, 0, -2.35), rodDef.rodColor, Enum.Material.SmoothPlastic, anchored)
	local shaftUpper = addWeldedPart(m, grip, "ShaftUpper", Enum.PartType.Block, Vector3.new(0.13, 0.13, 2.95), CFrame.new(0, 0.08, -5.35) * CFrame.Angles(math.rad(4), 0, 0), rodDef.accentColor, if isNeon then Enum.Material.Neon else Enum.Material.SmoothPlastic, anchored)

	-- Khoen dan day cau doc than can
	for _, zRing in ipairs({ -1.8, -3.4, -5.0 }) do
		addWeldedPart(m, grip, "LineGuide", Enum.PartType.Cylinder, Vector3.new(0.08, 0.32, 0.32), CFrame.new(0, -0.16, zRing), rodDef.accentColor, accMat, anchored)
	end

	-- Chi tiet dau can doc ban cho 3 cay Can Exclusive
	if rodDef.id == "RelicTrident" then
		for _, xProng in ipairs({ -0.38, 0, 0.38 }) do
			addWeldedPart(m, grip, "TridentProng", Enum.PartType.Block, Vector3.new(0.10, 0.10, 0.95), CFrame.new(xProng, 0.16, -6.95), rodDef.accentColor, Enum.Material.Neon, anchored)
		end
	elseif rodDef.id == "VoidScythe" then
		addWeldedPart(m, grip, "ScytheBlade", Enum.PartType.Block, Vector3.new(0.12, 1.45, 0.42), CFrame.new(0, -0.45, -6.75) * CFrame.Angles(math.rad(24), 0, 0), rodDef.accentColor, Enum.Material.Neon, anchored)
	elseif rodDef.id == "SeraphimDragon" then
		for _, s in ipairs({ -1, 1 }) do
			addWeldedPart(m, grip, "DragonWing", Enum.PartType.Block, Vector3.new(1.15, 0.14, 0.58), CFrame.new(0.62 * s, 0.15, -1.25) * CFrame.Angles(0, math.rad(-22 * s), math.rad(16 * s)), rodDef.accentColor, Enum.Material.Neon, anchored)
		end
		addWeldedPart(m, grip, "DragonOrb", Enum.PartType.Ball, Vector3.new(0.46, 0.46, 0.46), CFrame.new(0, 0.22, -6.88), Color3.fromRGB(255, 244, 158), Enum.Material.Neon, anchored)
	end

	local tipAtt = Instance.new("Attachment")
	tipAtt.Name = "RodTipAttachment"
	tipAtt.Position = Vector3.new(0, 0, -1.42)
	tipAtt.Parent = shaftUpper
	return m, grip, tipAtt
end

function RodAndWeightBuilder.BuildCharacterRod(rodDef: Types.RodDef): (Model, BasePart, Attachment)
	local override = AssetRegistry.TryClone("Rods", rodDef.id, false)
	if override and override.PrimaryPart then
		local found = override:FindFirstChild("RodTipAttachment", true)
		local tip: Attachment
		if found and found:IsA("Attachment") then
			tip = found
		else
			tip = Instance.new("Attachment")
			tip.Name = "RodTipAttachment"
			tip.Position = Vector3.new(0, 0, -5.5)
			tip.Parent = override.PrimaryPart
		end
		return override, override.PrimaryPart, tip
	end
	return buildRodInternal(rodDef, false)
end

function RodAndWeightBuilder.BuildRodPreview(rodDef: Types.RodDef): Model
	local m, grip, _ = buildRodInternal(rodDef, true)
	local tilt = CFrame.new(0, -0.4, 2.8) * CFrame.Angles(math.rad(-28), math.rad(35), 0)
	local inv = grip.CFrame:Inverse()
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") and d ~= grip then
			d.CFrame = tilt * (inv * d.CFrame)
		end
	end
	grip.CFrame = tilt
	return m
end

function RodAndWeightBuilder.BuildHandheldDumbbell(accentColor: Color3, scale: number): (Model, BasePart)
	local m = Instance.new("Model")
	m.Name = "GymDumbbell3D"
	local s = math.clamp(scale, 0.85, 1.65)

	local bar = Instance.new("Part")
	bar.Name = "Handle"
	bar.Size = Vector3.new(1.55 * s, 0.22, 0.22)
	bar.Color = Color3.fromRGB(210, 218, 232)
	bar.Material = Enum.Material.Metal
	bar.Anchored = false
	bar.CanCollide = false
	bar.CanQuery = false
	bar.Massless = true
	bar.Parent = m
	m.PrimaryPart = bar

	for _, xSide in ipairs({ -0.68 * s, 0.68 * s }) do
		addWeldedPart(m, bar, "WeightPlate", Enum.PartType.Cylinder, Vector3.new(0.38 * s, 1.05 * s, 1.05 * s), CFrame.new(xSide, 0, 0), accentColor, Enum.Material.SmoothPlastic, false)
		addWeldedPart(m, bar, "InnerRim", Enum.PartType.Cylinder, Vector3.new(0.42 * s, 0.55 * s, 0.55 * s), CFrame.new(xSide, 0, 0), Color3.fromRGB(48, 54, 68), Enum.Material.Metal, false)
	end
	return m, bar
end

function RodAndWeightBuilder.BuildHandheldBarbell(accentColor: Color3, scale: number): (Model, BasePart)
	local m = Instance.new("Model")
	m.Name = "GymBarbell3D"
	local s = math.clamp(scale, 0.9, 1.55)

	local bar = Instance.new("Part")
	bar.Name = "BarShaft"
	bar.Size = Vector3.new(5.8 * s, 0.24, 0.24)
	bar.Color = Color3.fromRGB(214, 222, 236)
	bar.Material = Enum.Material.Metal
	bar.Anchored = false
	bar.CanCollide = false
	bar.CanQuery = false
	bar.Massless = true
	bar.Parent = m
	m.PrimaryPart = bar

	for _, side in ipairs({ -1, 1 }) do
		addWeldedPart(m, bar, "BigPlate", Enum.PartType.Cylinder, Vector3.new(0.42 * s, 1.85 * s, 1.85 * s), CFrame.new(2.25 * s * side, 0, 0), accentColor, Enum.Material.Neon, false)
		addWeldedPart(m, bar, "OuterPlate", Enum.PartType.Cylinder, Vector3.new(0.32 * s, 1.35 * s, 1.35 * s), CFrame.new(2.62 * s * side, 0, 0), Color3.fromRGB(42, 48, 62), Enum.Material.Metal, false)
	end
	return m, bar
end

return RodAndWeightBuilder
