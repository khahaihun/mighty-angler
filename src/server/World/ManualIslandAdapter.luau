--!strict
-- ManualIslandAdapter.luau: Nhan dien Dao Terrain dung thu cong trong Studio (Workspace/MightyWorldManual/Island_<id>)
-- va doc cac diem neo IslandMarkers de gan nguyen 100% logic cau ca, NPC, Gym, Trung, Cong Dao ma khong de khoi hop cu.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))

local PartFactory = require(script.Parent.PartFactory)

local ManualIslandAdapter = {}

local MANUAL_ROOT_NAME = "MightyWorldManual"

function ManualIslandAdapter.FindManualIsland(islandId: number): Instance?
	local root = Workspace:FindFirstChild(MANUAL_ROOT_NAME)
	if not root then
		return nil
	end
	return root:FindFirstChild("Island_" .. tostring(islandId))
end

function ManualIslandAdapter.GetMarkerCFrame(
	manualIsland: Instance?,
	markerName: string,
	defaultCf: CFrame
): CFrame
	if not manualIsland then
		return defaultCf
	end
	local markers = manualIsland:FindFirstChild("IslandMarkers")
	if not markers then
		return defaultCf
	end
	local found = markers:FindFirstChild(markerName)
	if not found then
		return defaultCf
	end
	if found:IsA("BasePart") then
		return found.CFrame
	elseif found:IsA("Attachment") then
		return found.WorldCFrame
	elseif found:IsA("Model") and found.PrimaryPart then
		return found.PrimaryPart.CFrame
	end
	return defaultCf
end

function ManualIslandAdapter.GetMarkerPart(manualIsland: Instance?, markerName: string): BasePart?
	if not manualIsland then
		return nil
	end
	local markers = manualIsland:FindFirstChild("IslandMarkers")
	if not markers then
		return nil
	end
	local found = markers:FindFirstChild(markerName)
	if found and found:IsA("BasePart") then
		return found
	end
	return nil
end

function ManualIslandAdapter.HideRuntimeMarkers(manualIsland: Instance)
	local markers = manualIsland:FindFirstChild("IslandMarkers")
	if not markers then
		return
	end
	for _, desc in ipairs(markers:GetDescendants()) do
		if desc:IsA("BasePart") then
			desc.Transparency = 1
			desc.CanCollide = false
			desc.CanQuery = false
			desc.CastShadow = false
		elseif desc:IsA("LayerCollector") then
			desc.Enabled = false
		end
	end
end

function ManualIslandAdapter.BuildFishingWaterBounds(
	islandFolder: Folder,
	islandDef: Types.IslandDef,
	manualIsland: Instance
): Part?
	local marker = ManualIslandAdapter.GetMarkerPart(manualIsland, "FishingWater")
	if not marker then
		return nil
	end
	local waterBounds = PartFactory.Block(
		islandFolder,
		"FishingWater",
		marker.Size,
		marker.CFrame,
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

function ManualIslandAdapter.HasManualOceanBounds(manualIsland: Instance): boolean
	local bounds = manualIsland:FindFirstChild("OceanBounds")
	if not bounds then
		return false
	end
	local foundAny = false
	for _, desc in ipairs(bounds:GetDescendants()) do
		if desc:IsA("BasePart") then
			desc:SetAttribute("FishingRayIgnore", true)
			foundAny = true
		end
	end
	return foundAny
end

return ManualIslandAdapter
