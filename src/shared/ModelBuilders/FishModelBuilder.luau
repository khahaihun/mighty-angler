--!strict
-- FishModelBuilder.luau: Thu vien dung Mo Hinh 3D Chi Tiet Cao cho 5 Ho Ca (Sleek, Billfish, Manta, Shark, Leviathan)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local AssetRegistry = require(Shared:WaitForChild("AssetRegistry"))
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))

local FishModelBuilder = {}

export type FishFamily = "Sleek" | "Billfish" | "Manta" | "Shark" | "Leviathan"

function FishModelBuilder.ClassifyFamily(fishDef: Types.FishDef): FishFamily
	local id = string.lower(fishDef.id)
	if string.find(id, "stingray") or string.find(id, "manta") then
		return "Manta"
	elseif string.find(id, "marlin") or string.find(id, "sword") or string.find(id, "barracuda") or string.find(id, "gar") or string.find(id, "oarfish") or string.find(id, "tuna") then
		return "Billfish"
	elseif string.find(id, "shark") or string.find(id, "piranha") or string.find(id, "lionfish") then
		return "Shark"
	elseif fishDef.rarity == "Boss" or string.find(id, "hydra") or string.find(id, "leviathan") or string.find(id, "serpent") or string.find(id, "behemoth") or string.find(id, "eel") or string.find(id, "wyrm") then
		return "Leviathan"
	end
	return "Sleek"
end

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

local function addWedge(m: Model, root: BasePart, sz: Vector3, relCf: CFrame, col: Color3, mat: Enum.Material): WedgePart
	local w = Instance.new("WedgePart")
	w.Size = sz
	w.Color = col
	w.Material = mat
	w.Anchored = true
	w.CanCollide = false
	w.CanQuery = false
	w.Massless = true
	w.CFrame = root.CFrame * relCf
	w.Parent = m
	return w
end

local function addGlossyEyes(m: Model, root: BasePart, xSpread: number, yOff: number, zFront: number, silhouette: boolean)
	if silhouette then
		return
	end
	for _, s in ipairs({ -1, 1 }) do
		addPart(m, root, Enum.PartType.Ball, Vector3.new(0.26, 0.26, 0.26), CFrame.new(xSpread * s, yOff, zFront), Color3.fromRGB(16, 20, 30), Enum.Material.SmoothPlastic)
		addPart(m, root, Enum.PartType.Ball, Vector3.new(0.10, 0.10, 0.10), CFrame.new((xSpread + 0.06) * s, yOff + 0.06, zFront - 0.08), Color3.fromRGB(255, 255, 255), Enum.Material.Neon)
	end
end

function FishModelBuilder.BuildFish(fishDef: Types.FishDef, mutation: string?, silhouette: boolean?): Model
	if not silhouette then
		local override = AssetRegistry.TryClone("Fish", fishDef.id, true)
		if override and override.PrimaryPart then
			return override
		end
	end

	local isSil = (silhouette == true)
	local mut = mutation or "None"
	local c1 = if isSil then Color3.fromRGB(20, 24, 36) else fishDef.primaryColor
	local c2 = if isSil then Color3.fromRGB(30, 36, 52) else fishDef.secondaryColor
	local bellyCol = if isSil then c2 else c1:Lerp(Color3.fromRGB(250, 252, 255), 0.45)
	local bodyMat = Enum.Material.SmoothPlastic
	local finMat = if not isSil and (fishDef.rarity == "Legendary" or fishDef.rarity == "Boss") then Enum.Material.Neon else Enum.Material.SmoothPlastic

	if not isSil then
		if mut == "Shiny" then
			c1 = GameConfig.Mutations.Shiny.color
			bodyMat = Enum.Material.Neon
		elseif mut == "Golden" then
			c1 = GameConfig.Mutations.Golden.color
			bodyMat = Enum.Material.Foil
		elseif mut == "Cosmic" then
			c1 = GameConfig.Mutations.Cosmic.color
			bodyMat = Enum.Material.Neon
			finMat = Enum.Material.Neon
		end
	end

	local m = Instance.new("Model")
	m.Name = "Fish3D_" .. fishDef.id
	local fam = FishModelBuilder.ClassifyFamily(fishDef)

	if fam == "Manta" then
		local body = addPart(m, nil, Enum.PartType.Ball, Vector3.new(1.5, 0.55, 2.2), CFrame.new(), c1, bodyMat)
		m.PrimaryPart = body
		for _, s in ipairs({ -1, 1 }) do
			addWedge(m, body, Vector3.new(0.28, 1.35, 1.85), CFrame.new(1.15 * s, 0, 0.1) * CFrame.Angles(0, math.rad(90 * s), math.rad(90 * s)), c1, bodyMat)
			addPart(m, body, Enum.PartType.Block, Vector3.new(0.22, 0.18, 0.65), CFrame.new(0.45 * s, 0.05, -1.15) * CFrame.Angles(0, math.rad(-14 * s), 0), c2, finMat)
		end
		addPart(m, body, Enum.PartType.Block, Vector3.new(0.14, 0.14, 1.9), CFrame.new(0, 0, 1.85), c2, finMat)
		addGlossyEyes(m, body, 0.52, 0.18, -0.78, isSil)
	elseif fam == "Billfish" then
		local body = addPart(m, nil, Enum.PartType.Ball, Vector3.new(0.95, 1.15, 2.85), CFrame.new(), c1, bodyMat)
		m.PrimaryPart = body
		addPart(m, body, Enum.PartType.Ball, Vector3.new(0.75, 0.45, 2.3), CFrame.new(0, -0.34, -0.05), bellyCol, Enum.Material.SmoothPlastic)
		-- Mui kiem nhon phia truoc
		addPart(m, body, Enum.PartType.Block, Vector3.new(0.12, 0.12, 1.35), CFrame.new(0, 0.06, -1.85), c2, finMat)
		-- Vay buom lung cao
		addWedge(m, body, Vector3.new(0.18, 1.05, 1.65), CFrame.new(0, 0.78, 0.05), c2, finMat)
		addWedge(m, body, Vector3.new(0.22, 1.55, 0.95), CFrame.new(0, 0, 1.65), c2, finMat)
		addGlossyEyes(m, body, 0.38, 0.20, -1.02, isSil)
	elseif fam == "Shark" then
		local body = addPart(m, nil, Enum.PartType.Ball, Vector3.new(1.30, 1.35, 2.75), CFrame.new(), c1, bodyMat)
		m.PrimaryPart = body
		addPart(m, body, Enum.PartType.Ball, Vector3.new(1.08, 0.58, 2.15), CFrame.new(0, -0.38, -0.1), bellyCol, Enum.Material.SmoothPlastic)
		-- Vay lung ca map dung thang & 2 vay nguc
		addWedge(m, body, Vector3.new(0.24, 1.15, 1.05), CFrame.new(0, 0.92, -0.05), c1, bodyMat)
		for _, s in ipairs({ -1, 1 }) do
			addPart(m, body, Enum.PartType.Block, Vector3.new(0.85, 0.14, 0.55), CFrame.new(0.78 * s, -0.22, -0.25) * CFrame.Angles(0, math.rad(18 * s), math.rad(-20 * s)), c2, finMat)
		end
		addWedge(m, body, Vector3.new(0.26, 1.65, 1.1), CFrame.new(0, 0.12, 1.65), c2, finMat)
		addGlossyEyes(m, body, 0.48, 0.24, -0.96, isSil)
	elseif fam == "Leviathan" then
		local head = addPart(m, nil, Enum.PartType.Ball, Vector3.new(1.38, 1.32, 1.75), CFrame.new(0, 0.15, -0.85), c1, bodyMat)
		m.PrimaryPart = head
		local seg1 = addPart(m, head, Enum.PartType.Ball, Vector3.new(1.18, 1.15, 1.55), CFrame.new(0, -0.12, 1.15), c1, bodyMat)
		addPart(m, seg1, Enum.PartType.Ball, Vector3.new(0.92, 0.92, 1.45), CFrame.new(0, 0.10, 1.10), c1, bodyMat)
		addWedge(m, head, Vector3.new(0.26, 1.45, 1.15), CFrame.new(0, 0.05, 3.15), c2, Enum.Material.Neon)
		-- Sung rong / Vuong mien Thuy Quai
		for _, s in ipairs({ -1, 1 }) do
			addPart(m, head, Enum.PartType.Block, Vector3.new(0.18, 0.85, 0.22), CFrame.new(0.46 * s, 0.72, -0.15) * CFrame.Angles(math.rad(-28), 0, math.rad(-18 * s)), c2, Enum.Material.Neon)
		end
		addWedge(m, head, Vector3.new(0.20, 0.85, 1.1), CFrame.new(0, 0.78, 0.95), c2, Enum.Material.Neon)
		addGlossyEyes(m, head, 0.50, 0.22, -0.68, isSil)
	else
		local body = addPart(m, nil, Enum.PartType.Ball, Vector3.new(1.08, 1.32, 2.35), CFrame.new(), c1, bodyMat)
		m.PrimaryPart = body
		addPart(m, body, Enum.PartType.Ball, Vector3.new(0.86, 0.52, 1.85), CFrame.new(0, -0.35, -0.05), bellyCol, Enum.Material.SmoothPlastic)
		addWedge(m, body, Vector3.new(0.22, 0.76, 0.98), CFrame.new(0, 0.78, 0.08), c2, finMat)
		addWedge(m, body, Vector3.new(0.26, 1.42, 1.05), CFrame.new(0, 0, 1.38), c2, finMat)
		for _, s in ipairs({ -1, 1 }) do
			addPart(m, body, Enum.PartType.Block, Vector3.new(0.55, 0.12, 0.42), CFrame.new(0.58 * s, -0.12, -0.20) * CFrame.Angles(0, math.rad(20 * s), math.rad(-18 * s)), c2, finMat)
		end
		addGlossyEyes(m, body, 0.40, 0.22, -0.82, isSil)
	end

	if not isSil and mut ~= "None" and m.PrimaryPart then
		local sp = Instance.new("ParticleEmitter")
	sp:SetAttribute("ClientBudgetManaged", true)
		sp.Color = ColorSequence.new(c1)
		sp.LightEmission = 1
		sp.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.22), NumberSequenceKeypoint.new(1, 0) })
		sp.Lifetime = NumberRange.new(0.6, 1.1)
		sp.Rate = 8
		sp.Speed = NumberRange.new(0.8, 1.8)
		sp.Parent = m.PrimaryPart
	end

	return m
end

function FishModelBuilder.PositionOrScaleModel(model: Model, targetCf: CFrame, uniformScale: number, weldToPart: BasePart?)
	local root = model.PrimaryPart
	if not root then
		return
	end
	local invRoot = root.CFrame:Inverse()
	local descendants = model:GetDescendants()
	root.Size = root.Size * uniformScale
	root.CFrame = targetCf

	for _, inst in ipairs(descendants) do
		if inst:IsA("BasePart") and inst ~= root then
			local rel = invRoot * inst.CFrame
			local scaledPos = rel.Position * uniformScale
			local rotOnly = rel - rel.Position
			inst.Size = inst.Size * uniformScale
			inst.CFrame = targetCf * CFrame.new(scaledPos) * rotOnly
		end
	end

	if weldToPart then
		for _, inst in ipairs(model:GetDescendants()) do
			if inst:IsA("BasePart") then
				inst.Anchored = false
				local w = Instance.new("WeldConstraint")
				w.Part0 = weldToPart
				w.Part1 = inst
				w.Parent = inst
			end
		end
	end
end

return FishModelBuilder
