--!strict
-- AssetRegistry.luau: Quan ly Assets Override 3D (chong Script an, ho tro RootOnly cho NPC R15, Silhouette/Mutation & ScaleTo)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

export type AnchorMode = "All" | "None" | "RootOnly"

local ASSETS_ROOT_NAME = "Assets"
local CATEGORIES = {
	"Trees",
	"Props",
	"Gym",
	"Rods",
	"Fish",
	"Pets",
	"Eggs",
	"Npcs",
	"Buildings",
}

local AssetRegistry = {}
AssetRegistry.Categories = CATEGORIES

function AssetRegistry.EnsureFolders(): Folder
	local existing = ReplicatedStorage:FindFirstChild(ASSETS_ROOT_NAME)
	local root: Folder
	if existing and existing:IsA("Folder") then
		root = existing
	else
		if not RunService:IsServer() then
			local waited = ReplicatedStorage:WaitForChild(ASSETS_ROOT_NAME, 5)
			if waited and waited:IsA("Folder") then
				return waited
			end
		end
		root = Instance.new("Folder")
		root.Name = ASSETS_ROOT_NAME
		root.Parent = ReplicatedStorage
	end

	if RunService:IsServer() then
		for _, catName in ipairs(CATEGORIES) do
			local sub = root:FindFirstChild(catName)
			if not (sub and sub:IsA("Folder")) then
				local folder = Instance.new("Folder")
				folder.Name = catName
				folder.Parent = root
			end
		end
	end
	return root
end

function AssetRegistry.SanitizeModel(container: Instance): number
	local removed = 0
	for _, desc in ipairs(container:GetDescendants()) do
		if desc:IsA("LuaSourceContainer") then
			desc:Destroy()
			removed += 1
		end
	end
	return removed
end

local function resolveAnchorMode(anchorOption: (boolean | AnchorMode)?): AnchorMode
	if anchorOption == nil or anchorOption == true then
		return "All"
	elseif anchorOption == false then
		return "None"
	elseif anchorOption == "RootOnly" or anchorOption == "None" or anchorOption == "All" then
		return anchorOption
	end
	return "All"
end

local function ensurePrimaryPart(model: Model): BasePart?
	if model.PrimaryPart then
		return model.PrimaryPart
	end
	local hrp = model:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		model.PrimaryPart = hrp
		return hrp
	end
	for _, desc in ipairs(model:GetDescendants()) do
		if desc:IsA("BasePart") then
			model.PrimaryPart = desc
			return desc
		end
	end
	return nil
end

function AssetRegistry.TryClone(
	category: string,
	assetName: string,
	anchorOption: (boolean | AnchorMode)?
): Model?
	local root = ReplicatedStorage:FindFirstChild(ASSETS_ROOT_NAME)
	if not (root and root:IsA("Folder")) then
		return nil
	end
	local catFolder = root:FindFirstChild(category)
	if not (catFolder and catFolder:IsA("Folder")) then
		return nil
	end
	local template = catFolder:FindFirstChild(assetName)
	if not template then
		return nil
	end

	local clonedModel: Model
	if template:IsA("Model") then
		clonedModel = template:Clone()
	elseif template:IsA("BasePart") then
		clonedModel = Instance.new("Model")
		clonedModel.Name = assetName
		local partClone = template:Clone()
		partClone.Parent = clonedModel
		clonedModel.PrimaryPart = partClone
	else
		return nil
	end

	AssetRegistry.SanitizeModel(clonedModel)
	local primary = ensurePrimaryPart(clonedModel)
	local mode = resolveAnchorMode(anchorOption)

	for _, desc in ipairs(clonedModel:GetDescendants()) do
		if desc:IsA("BasePart") then
			if mode == "All" then
				desc.Anchored = true
			elseif mode == "None" then
				desc.Anchored = false
				desc.CanCollide = false
				desc.Massless = true
			else
				local isRoot = (desc == primary) or (desc.Name == "HumanoidRootPart")
				desc.Anchored = isRoot
				if not isRoot then
					desc.Massless = true
				end
			end
		end
	end

	return clonedModel
end

function AssetRegistry.ApplyModelVisuals(
	model: Model,
	silhouette: boolean,
	mutation: string?,
	mutationColor: Color3?
)
	if silhouette then
		for _, desc in ipairs(model:GetDescendants()) do
			if desc:IsA("SurfaceAppearance") or desc:IsA("Decal") or desc:IsA("Texture") or desc:IsA("ParticleEmitter") or desc:IsA("Highlight") then
				desc:Destroy()
			elseif desc:IsA("BasePart") then
				desc.Color = Color3.fromRGB(20, 24, 36)
				desc.Material = Enum.Material.SmoothPlastic
				if desc:IsA("MeshPart") then
					pcall(function()
						desc.TextureID = ""
					end)
				end
			end
		end
		return
	end

	if mutation and mutation ~= "None" and mutationColor then
		local hl = Instance.new("Highlight")
		hl.Name = "MutationHighlight"
		hl.Adornee = model
		hl.FillColor = mutationColor
		hl.OutlineColor = Color3.fromRGB(255, 255, 255)
		hl.FillTransparency = if mutation == "Golden" then 0.62 else 0.72
		hl.OutlineTransparency = 0.15
		hl.Parent = model

		local host = ensurePrimaryPart(model)
		if host then
			local sp = Instance.new("ParticleEmitter")
			sp.Name = "MutationParticles"
			sp:SetAttribute("ClientBudgetManaged", true)
			sp.Color = ColorSequence.new(mutationColor)
			sp.LightEmission = 1
			sp.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.22),
				NumberSequenceKeypoint.new(1, 0),
			})
			sp.Lifetime = NumberRange.new(0.6, 1.1)
			sp.Rate = 8
			sp.Speed = NumberRange.new(0.8, 1.8)
			sp.Parent = host
		end
	end
end

function AssetRegistry.ScaleModelUniform(model: Model, scaleFactor: number)
	if scaleFactor <= 0 or math.abs(scaleFactor - 1) < 0.001 then
		return
	end
	local ok = pcall(function()
		model:ScaleTo(scaleFactor)
	end)
	if ok then
		return
	end
	local root = ensurePrimaryPart(model)
	if not root then
		return
	end
	local invRoot = root.CFrame:Inverse()
	local targetCf = root.CFrame
	root.Size = root.Size * scaleFactor
	for _, inst in ipairs(model:GetDescendants()) do
		if inst:IsA("BasePart") and inst ~= root then
			local rel = invRoot * inst.CFrame
			inst.Size = inst.Size * scaleFactor
			inst.CFrame = targetCf * CFrame.new(rel.Position * scaleFactor) * (rel - rel.Position)
		end
	end
end

function AssetRegistry.NormalizeForViewport(model: Model, targetExtent: number, extraRotation: CFrame?)
	local size: Vector3? = nil
	pcall(function()
		local _, s = model:GetBoundingBox()
		size = s
	end)
	if not size then
		return
	end
	local maxAxis = math.max(size.X, size.Y, size.Z)
	if maxAxis > 0.001 then
		AssetRegistry.ScaleModelUniform(model, targetExtent / maxAxis)
	end
	local newCf: CFrame? = nil
	pcall(function()
		local c = model:GetBoundingBox()
		newCf = c
	end)
	local rot: CFrame = extraRotation or CFrame.new()
	if newCf then
		local pivot = model:GetPivot()
		local offset: Vector3 = newCf.Position - pivot.Position
		model:PivotTo(rot * CFrame.new(-offset.X, -offset.Y, -offset.Z))
	else
		model:PivotTo(rot)
	end
end

return AssetRegistry
