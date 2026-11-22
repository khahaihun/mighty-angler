--!strict
-- PetModelBuilder.luau: Thu vien dung 6 dong Pet Chibi 3D mat long lanh (Crab, Bird, Fish, Spirit, Dragon, Star/Golem)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local AssetRegistry = require(Shared:WaitForChild("AssetRegistry"))

local PetModelBuilder = {}

local function addPart(m: Model, root: BasePart?, shape: Enum.PartType, sz: Vector3, relCf: CFrame, col: Color3, mat: Enum.Material, name: string?): Part
	local p = Instance.new("Part")
	p.Name = name or "Part"
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
	local isExclusive = (petDef :: any).isExclusive == true
	local hasNeonAccent = (not isSil) and (isExclusive or petDef.rarity == "Rare" or petDef.rarity == "Epic" or petDef.rarity == "Legendary" or petDef.rarity == "Mythic")
	-- Than va chi chinh luon dung SmoothPlastic bong Gu B; CHI chi tiet diem nhan nho moi dung Neon (khong choi mat toan than)
	local bodyMat = Enum.Material.SmoothPlastic
	local limbMat = Enum.Material.SmoothPlastic
	local detailGlowMat = if hasNeonAccent then Enum.Material.Neon else Enum.Material.SmoothPlastic

	local m = Instance.new("Model")
	m.Name = "Pet3D_" .. petDef.id

	local arch = petDef.archetype
	local headShape = if arch == "Star" or arch == "Golem" then Enum.PartType.Block else Enum.PartType.Ball
	local headSize = if arch == "Crab" then Vector3.new(1.95, 1.35, 1.65) else Vector3.new(1.78, 1.68, 1.78)
	local body = addPart(m, nil, headShape, headSize, CFrame.new(), c1, bodyMat, "Body")
	m.PrimaryPart = body

	-- Doi mat Chibi long lanh + ma hong de thuong
	if not isSil then
		local zEye = -(headSize.Z * 0.47)
		for _, s in ipairs({ -1, 1 }) do
			addPart(m, body, Enum.PartType.Ball, Vector3.new(0.36, 0.40, 0.22), CFrame.new(0.42 * s, 0.14, zEye), Color3.fromRGB(18, 22, 32), Enum.Material.SmoothPlastic, "Eye")
			addPart(m, body, Enum.PartType.Ball, Vector3.new(0.13, 0.13, 0.12), CFrame.new(0.47 * s, 0.23, zEye - 0.08), Color3.fromRGB(255, 255, 255), Enum.Material.Neon, "EyeSparkle")
			addPart(m, body, Enum.PartType.Ball, Vector3.new(0.24, 0.14, 0.12), CFrame.new(0.58 * s, -0.06, zEye + 0.02), Color3.fromRGB(255, 138, 168), Enum.Material.SmoothPlastic, "Blush")
		end
	end

	if arch == "Crab" then
		for _, s in ipairs({ -1, 1 }) do
			addPart(m, body, Enum.PartType.Ball, Vector3.new(0.65, 0.52, 0.78), CFrame.new(1.12 * s, 0.05, -0.55) * CFrame.Angles(0, math.rad(-22 * s), 0), c2, limbMat, "Claw")
			addPart(m, body, Enum.PartType.Block, Vector3.new(0.55, 0.22, 0.22), CFrame.new(0.95 * s, -0.45, 0.2) * CFrame.Angles(0, 0, math.rad(-25 * s)), c2, limbMat, "Leg")
			if hasNeonAccent then
				addPart(m, body, Enum.PartType.Ball, Vector3.new(0.22, 0.22, 0.22), CFrame.new(1.22 * s, 0.14, -0.88), c2, detailGlowMat, "ClawTipGlow")
			end
		end
	elseif arch == "Bird" then
		addPart(m, body, Enum.PartType.Block, Vector3.new(0.34, 0.26, 0.48), CFrame.new(0, -0.04, -0.96), Color3.fromRGB(255, 196, 52), limbMat, "Beak")
		for _, s in ipairs({ -1, 1 }) do
			addPart(m, body, Enum.PartType.Block, Vector3.new(0.82, 0.22, 0.85), CFrame.new(1.06 * s, 0.12, 0.08) * CFrame.Angles(0, 0, math.rad(-18 * s)), c2, limbMat, "Wing")
		end
		addPart(m, body, Enum.PartType.Ball, Vector3.new(0.45, 0.55, 0.45), CFrame.new(0, 0.92, 0), c2, limbMat, "Crest")
		if hasNeonAccent then
			addPart(m, body, Enum.PartType.Ball, Vector3.new(0.22, 0.22, 0.22), CFrame.new(0, 1.18, -0.05), c2, detailGlowMat, "CrestGem")
		end
	elseif arch == "Dragon" then
		for _, s in ipairs({ -1, 1 }) do
			addPart(m, body, Enum.PartType.Block, Vector3.new(0.22, 0.56, 0.22), CFrame.new(0.46 * s, 0.86, -0.1) * CFrame.Angles(math.rad(-18), 0, math.rad(-16 * s)), c2, limbMat, "Horn")
			addPart(m, body, Enum.PartType.Block, Vector3.new(0.98, 0.58, 0.22), CFrame.new(1.12 * s, 0.22, 0.28) * CFrame.Angles(0, math.rad(22 * s), math.rad(-20 * s)), c2, limbMat, "Wing")
			if hasNeonAccent then
				addPart(m, body, Enum.PartType.Ball, Vector3.new(0.20, 0.20, 0.20), CFrame.new(0.54 * s, 1.16, -0.18), c2, detailGlowMat, "HornTipGlow")
				addPart(m, body, Enum.PartType.Block, Vector3.new(0.22, 0.16, 0.24), CFrame.new(1.56 * s, 0.36, 0.34), c2, detailGlowMat, "WingTipGlow")
			end
		end
		addPart(m, body, Enum.PartType.Ball, Vector3.new(0.52, 0.52, 0.95), CFrame.new(0, -0.25, 1.05), c1, bodyMat, "Tail")
	elseif arch == "Star" then
		addPart(m, body, Enum.PartType.Block, Vector3.new(1.32, 1.32, 1.32), CFrame.Angles(math.rad(45), math.rad(45), 0), c2, limbMat, "StarCore")
		if not isSil then
			addPart(m, body, Enum.PartType.Cylinder, Vector3.new(0.12, 2.2, 2.2), CFrame.new(0, 1.12, 0) * CFrame.Angles(0, 0, math.rad(90)), c2, Enum.Material.Neon, "StarHalo")
		end
	elseif arch == "Fish" then
		for _, s in ipairs({ -1, 1 }) do
			addPart(m, body, Enum.PartType.Block, Vector3.new(0.62, 0.18, 0.55), CFrame.new(0.96 * s, 0, 0.05) * CFrame.Angles(0, 0, math.rad(-16 * s)), c2, limbMat, "SideFin")
			if hasNeonAccent then
				addPart(m, body, Enum.PartType.Ball, Vector3.new(0.18, 0.18, 0.18), CFrame.new(1.26 * s, 0.06, 0.05), c2, detailGlowMat, "FinTipGlow")
			end
		end
		addPart(m, body, Enum.PartType.Block, Vector3.new(0.24, 0.95, 0.68), CFrame.new(0, 0.08, 1.02), c2, limbMat, "TailFin")
	else
		-- Spirit / Familiar co tai nhon & dom lua nho
		for _, s in ipairs({ -1, 1 }) do
			addPart(m, body, Enum.PartType.Block, Vector3.new(0.38, 0.65, 0.32), CFrame.new(0.52 * s, 0.88, 0) * CFrame.Angles(0, 0, math.rad(-14 * s)), c2, limbMat, "Ear")
			addPart(m, body, Enum.PartType.Ball, Vector3.new(0.30, 0.30, 0.30), CFrame.new(1.06 * s, 0.12, 0.15), c2, if isSil then limbMat else Enum.Material.Neon, "SpiritOrb")
		end
	end

	if not isSil and isExclusive then
		-- Vuong mien vang bong + vien ngoc Neon nho + vong hao quang manh cho Pet Exclusive (gu PS99)
		addPart(m, body, Enum.PartType.Cylinder, Vector3.new(0.10, 2.25, 2.25), CFrame.new(0, 1.28, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(255, 226, 92), Enum.Material.Neon, "ExclusiveHalo")
		addPart(m, body, Enum.PartType.Block, Vector3.new(0.72, 0.32, 0.72), CFrame.new(0, 1.02, -0.05) * CFrame.Angles(0, math.rad(45), 0), Color3.fromRGB(255, 206, 56), Enum.Material.SmoothPlastic, "ExclusiveCrown")
		addPart(m, body, Enum.PartType.Ball, Vector3.new(0.24, 0.24, 0.24), CFrame.new(0, 1.14, -0.44), c2, Enum.Material.Neon, "CrownGem")
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
