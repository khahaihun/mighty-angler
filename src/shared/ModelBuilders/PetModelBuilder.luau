--!strict
-- PetModelBuilder.luau: Thu vien dung 6 dong Pet Chibi 3D mat long lanh (Crab, Bird, Fish, Spirit, Dragon, Star/Golem)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local AssetRegistry = require(Shared:WaitForChild("AssetRegistry"))

local PetModelBuilder = {}

local function addPart(m: Model, root: BasePart?, shape: Enum.PartType, sz: Vector3, relCf: CFrame, col: Color3, mat: Enum.Material): Part
	local p = Instance.new("Part")
	p.Shape = shape
	p.Size = sz
	p.Color = col
	p.Material = mat
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.Massless = true
	p.CFrame = if root then (root.CFrame * relCf) else relCf
	p.Parent = m
	return p
end

local function WeldAllToPrimary(m: Model)
	local root = m.PrimaryPart
	if not root then
		return
	end
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") and d ~= root then
			d.Anchored = false
			local w = Instance.new("WeldConstraint")
			w.Part0 = root
			w.Part1 = d
			w.Parent = d
		end
	end
end

function PetModelBuilder.BuildPet(petDef: Types.PetDef, silhouette: boolean?, forWorldFollow: boolean?): Model
	local isSil = (silhouette == true)
	local override = AssetRegistry.TryClone("Pets", petDef.id, true)
	if override and override.PrimaryPart then
		override.Name = "Pet3D_" .. petDef.id
		AssetRegistry.ApplyModelVisuals(override, isSil, nil, nil)
		if forWorldFollow then
			WeldAllToPrimary(override)
		end
		return override
	end

	local c1 = if isSil then Color3.fromRGB(22, 26, 38) else petDef.primaryColor
	local c2 = if isSil then Color3.fromRGB(34, 40, 58) else petDef.secondaryColor
	local isGlowing = (not isSil) and (petDef.rarity == "Mythic" or petDef.rarity == "Legendary")
	local bodyMat = if isGlowing then Enum.Material.Neon else Enum.Material.SmoothPlastic
	local accMat = if not isSil and petDef.rarity ~= "Common" then Enum.Material.Neon else Enum.Material.SmoothPlastic

	local m = Instance.new("Model")
	m.Name = "Pet3D_" .. petDef.id

	local arch = petDef.archetype
	local headShape = if arch == "Star" or arch == "Golem" then Enum.PartType.Block else Enum.PartType.Ball
	local headSize = if arch == "Crab" then Vector3.new(1.95, 1.35, 1.65) else Vector3.new(1.78, 1.68, 1.78)
	local body = addPart(m, nil, headShape, headSize, CFrame.new(), c1, bodyMat)
	m.PrimaryPart = body

	-- Doi mat Chibi long lanh + ma hong de thuong
	if not isSil then
		local zEye = -(headSize.Z * 0.47)
		for _, s in ipairs({ -1, 1 }) do
			addPart(m, body, Enum.PartType.Ball, Vector3.new(0.36, 0.40, 0.22), CFrame.new(0.42 * s, 0.14, zEye), Color3.fromRGB(18, 22, 32), Enum.Material.SmoothPlastic)
			addPart(m, body, Enum.PartType.Ball, Vector3.new(0.13, 0.13, 0.12), CFrame.new(0.47 * s, 0.23, zEye - 0.08), Color3.fromRGB(255, 255, 255), Enum.Material.Neon)
			addPart(m, body, Enum.PartType.Ball, Vector3.new(0.24, 0.14, 0.12), CFrame.new(0.58 * s, -0.06, zEye + 0.02), Color3.fromRGB(255, 138, 168), Enum.Material.SmoothPlastic)
		end
	end

	if arch == "Crab" then
		for _, s in ipairs({ -1, 1 }) do
			addPart(m, body, Enum.PartType.Ball, Vector3.new(0.65, 0.52, 0.78), CFrame.new(1.12 * s, 0.05, -0.55) * CFrame.Angles(0, math.rad(-22 * s), 0), c2, accMat)
			addPart(m, body, Enum.PartType.Block, Vector3.new(0.55, 0.22, 0.22), CFrame.new(0.95 * s, -0.45, 0.2) * CFrame.Angles(0, 0, math.rad(-25 * s)), c2, Enum.Material.SmoothPlastic)
		end
	elseif arch == "Bird" then
		addPart(m, body, Enum.PartType.Block, Vector3.new(0.34, 0.26, 0.48), CFrame.new(0, -0.04, -0.96), Color3.fromRGB(255, 196, 52), Enum.Material.SmoothPlastic)
		for _, s in ipairs({ -1, 1 }) do
			addPart(m, body, Enum.PartType.Block, Vector3.new(0.82, 0.22, 0.85), CFrame.new(1.06 * s, 0.12, 0.08) * CFrame.Angles(0, 0, math.rad(-18 * s)), c2, accMat)
		end
		addPart(m, body, Enum.PartType.Ball, Vector3.new(0.45, 0.55, 0.45), CFrame.new(0, 0.92, 0), c2, accMat)
	elseif arch == "Dragon" then
		for _, s in ipairs({ -1, 1 }) do
			addPart(m, body, Enum.PartType.Block, Vector3.new(0.22, 0.68, 0.22), CFrame.new(0.48 * s, 0.92, -0.1) * CFrame.Angles(math.rad(-18), 0, math.rad(-16 * s)), c2, Enum.Material.Neon)
			addPart(m, body, Enum.PartType.Block, Vector3.new(0.98, 0.58, 0.22), CFrame.new(1.12 * s, 0.22, 0.28) * CFrame.Angles(0, math.rad(22 * s), math.rad(-20 * s)), c2, accMat)
		end
		addPart(m, body, Enum.PartType.Ball, Vector3.new(0.52, 0.52, 0.95), CFrame.new(0, -0.25, 1.05), c1, bodyMat)
	elseif arch == "Star" then
		addPart(m, body, Enum.PartType.Block, Vector3.new(1.35, 1.35, 1.35), CFrame.Angles(math.rad(45), math.rad(45), 0), c2, Enum.Material.Neon)
		addPart(m, body, Enum.PartType.Cylinder, Vector3.new(0.16, 2.35, 2.35), CFrame.new(0, 1.15, 0) * CFrame.Angles(0, 0, math.rad(90)), c2, Enum.Material.Neon)
	elseif arch == "Fish" then
		for _, s in ipairs({ -1, 1 }) do
			addPart(m, body, Enum.PartType.Block, Vector3.new(0.62, 0.18, 0.55), CFrame.new(0.96 * s, 0, 0.05) * CFrame.Angles(0, 0, math.rad(-16 * s)), c2, accMat)
		end
		addPart(m, body, Enum.PartType.Block, Vector3.new(0.24, 0.95, 0.68), CFrame.new(0, 0.08, 1.02), c2, accMat)
	else
		-- Spirit / Familiar co tai nhon & vong sang
		for _, s in ipairs({ -1, 1 }) do
			addPart(m, body, Enum.PartType.Block, Vector3.new(0.38, 0.65, 0.32), CFrame.new(0.52 * s, 0.88, 0) * CFrame.Angles(0, 0, math.rad(-14 * s)), c2, accMat)
			addPart(m, body, Enum.PartType.Ball, Vector3.new(0.46, 0.46, 0.46), CFrame.new(1.08 * s, 0.10, 0.15), c2, Enum.Material.Neon)
		end
	end

	if not isSil and (petDef :: any).isExclusive == true then
		-- Hào quang + vương miện hoàng kim cho Pet Exclusive (gu PS99)
		addPart(m, body, Enum.PartType.Cylinder, Vector3.new(0.14, 2.35, 2.35), CFrame.new(0, 1.28, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(255, 226, 92), Enum.Material.Neon)
		addPart(m, body, Enum.PartType.Block, Vector3.new(0.75, 0.34, 0.75), CFrame.new(0, 1.05, -0.05) * CFrame.Angles(0, math.rad(45), 0), Color3.fromRGB(255, 214, 62), Enum.Material.Neon)
		local sp = Instance.new("ParticleEmitter")
		sp.Name = "ExclusiveSparkle"
		sp:SetAttribute("ClientBudgetManaged", true)
		sp.Color = ColorSequence.new(Color3.fromRGB(255, 232, 118), c2)
		sp.LightEmission = 1
		sp.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.22), NumberSequenceKeypoint.new(1, 0) })
		sp.Lifetime = NumberRange.new(0.6, 1.0)
		sp.Rate = 6
		sp.Speed = NumberRange.new(0.6, 1.4)
		sp.Parent = body
	end

	if forWorldFollow then
		WeldAllToPrimary(m)
	end
	return m
end

function PetModelBuilder.BuildEggPreview(eggDef: Types.EggDef): Model
	local override = AssetRegistry.TryClone("Eggs", eggDef.id, true)
	if override and override.PrimaryPart then
		override.Name = "Egg3D_" .. eggDef.id
		AssetRegistry.NormalizeForViewport(override, 2.75)
		return override
	end

	local m = Instance.new("Model")
	m.Name = "Egg3D_" .. eggDef.id
	local shell = addPart(m, nil, Enum.PartType.Ball, Vector3.new(2.05, 2.60, 2.05), CFrame.new(), eggDef.eggColor, Enum.Material.SmoothPlastic)
	m.PrimaryPart = shell
	addPart(m, shell, Enum.PartType.Cylinder, Vector3.new(0.34, 2.14, 2.14), CFrame.new(0, -0.10, 0) * CFrame.Angles(0, 0, math.rad(90)), eggDef.accentColor, Enum.Material.Neon)
	if (eggDef :: any).isExclusive == true then
		addPart(m, shell, Enum.PartType.Cylinder, Vector3.new(0.16, 2.65, 2.65), CFrame.new(0, 1.42, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(255, 224, 88), Enum.Material.Neon)
		addPart(m, shell, Enum.PartType.Block, Vector3.new(0.72, 0.42, 0.72), CFrame.new(0, 1.38, 0) * CFrame.Angles(0, math.rad(45), 0), Color3.fromRGB(255, 212, 62), Enum.Material.Neon)
	end
	return m
end

return PetModelBuilder
