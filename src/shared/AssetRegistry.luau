--!strict
-- AssetRegistry.luau: Ho tro Assets Override tu Roblox Studio Toolbox
-- Neu nguoi dung tha Model 3D vao ReplicatedStorage.Assets.<Category>.<AssetName>,
-- game tu dong dung Model do thay cho Low-Poly code mac dinh.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ASSETS_ROOT_NAME = "Assets"
local CATEGORIES = {
	"Trees",
	"Props",
	"Gym",
	"Rods",
	"Fish",
	"Pets",
}

local AssetRegistry = {}

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

function AssetRegistry.TryClone(category: string, assetName: string, anchored: boolean?): Model?
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

	local shouldAnchor = if anchored == nil then true else anchored
	for _, desc in ipairs(clonedModel:GetDescendants()) do
		if desc:IsA("BasePart") then
			desc.Anchored = shouldAnchor
			if not shouldAnchor then
				desc.CanCollide = false
				desc.Massless = true
			end
		end
	end

	return clonedModel
end

return AssetRegistry
