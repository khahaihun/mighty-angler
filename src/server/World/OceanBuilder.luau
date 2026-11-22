--!strict
-- OceanBuilder.luau: Do bien Terrain bao quanh va noi cac dao, lot day bien cat, va trai mat bien phang ra tan chan troi.
-- KHONG BAO GIO ghi Terrain vao trong vung dao dung tay (MightyWorldManual): chi do nuoc ben ngoai vung do.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local IslandsRegistry = require(Shared:WaitForChild("Config"):WaitForChild("Islands"))

local PartFactory = require(script.Parent.PartFactory)
local ManualIslandAdapter = require(script.Parent.ManualIslandAdapter)
local OceanLayout = require(script.Parent.OceanLayout)

local OceanBuilder = {}

OceanBuilder.SURFACE_OFFSET_Y = -0.3 -- mat nuoc so voi tam dao; phai bang mat ho bien cua TerrainWaterBuilder
OceanBuilder.DEPTH = 9.7 -- day bien nam o y = 0 voi dao cao 10: tron voxel, du sau de thay mau nuoc dam dan
OceanBuilder.TERRAIN_MARGIN = 384 -- nuoc song that quanh dao
OceanBuilder.HORIZON_MARGIN = 1536 -- mat phang re tien noi tiep ra xa, suong mu che cho noi
OceanBuilder.FILL_SPAN = 1024
OceanBuilder.PART_SPAN = 2048

local FLOOR_COLOR = Color3.fromRGB(226, 208, 158)
local HORIZON_COLOR = Color3.fromRGB(24, 150, 210)

local function manualHole(manualIsland: Instance, box: OceanLayout.Rect): OceanLayout.Rect
	-- Chu du an co the dat Part "OceanHole" (khong xoay) trong IslandMarkers de thu hep/mo rong vung cam do nuoc.
	local marker = ManualIslandAdapter.GetMarkerPart(manualIsland, "OceanHole")
	if not marker then
		return box
	end
	local p, half = marker.Position, marker.Size * 0.5
	return OceanLayout.SnapOut({ x0 = p.X - half.X, x1 = p.X + half.X, z0 = p.Z - half.Z, z1 = p.Z + half.Z })
end

function OceanBuilder.Build(worldRoot: Folder): Folder
	local folder = Instance.new("Folder")
	folder.Name = "Ocean"
	folder.Parent = worldRoot

	local list = IslandsRegistry.List
	if #list == 0 then
		return folder
	end
	local boxes: { OceanLayout.Rect } = {}
	local holes: { OceanLayout.Rect } = {}
	for _, islandDef in ipairs(list) do
		local c = islandDef.centerPosition
		local box = OceanLayout.IslandBox(c.X, c.Z)
		table.insert(boxes, box)
		local manualIsland = ManualIslandAdapter.FindManualIsland(islandDef.id)
		table.insert(holes, if manualIsland then manualHole(manualIsland, box) else OceanLayout.LandHole(c.X, c.Z))
	end

	local surfaceY = list[1].centerPosition.Y + OceanBuilder.SURFACE_OFFSET_Y
	local floorY = surfaceY - OceanBuilder.DEPTH
	local bounds = OceanLayout.Bounds(boxes, OceanBuilder.TERRAIN_MARGIN)
	local terrain = Workspace.Terrain

	for _, free in ipairs(OceanLayout.Subtract(bounds, holes)) do
		for _, r in ipairs(OceanLayout.Split(free, OceanBuilder.FILL_SPAN)) do
			local cx, cz = (r.x0 + r.x1) * 0.5, (r.z0 + r.z1) * 0.5
			local w, d = r.x1 - r.x0, r.z1 - r.z0
			terrain:FillBlock(CFrame.new(cx, (surfaceY + floorY) * 0.5, cz), Vector3.new(w, OceanBuilder.DEPTH, d), Enum.Material.Water)
			local floor = PartFactory.Block(folder, "SeaFloor", Vector3.new(w, 4, d), CFrame.new(cx, floorY - 2, cz), FLOOR_COLOR, Enum.Material.Sand)
			floor.CastShadow = false
		end
	end

	local far = OceanBuilder.HORIZON_MARGIN
	local ring: { OceanLayout.Rect } = {
		{ x0 = bounds.x0 - far, x1 = bounds.x0, z0 = bounds.z0 - far, z1 = bounds.z1 + far },
		{ x0 = bounds.x1, x1 = bounds.x1 + far, z0 = bounds.z0 - far, z1 = bounds.z1 + far },
		{ x0 = bounds.x0, x1 = bounds.x1, z0 = bounds.z0 - far, z1 = bounds.z0 },
		{ x0 = bounds.x0, x1 = bounds.x1, z0 = bounds.z1, z1 = bounds.z1 + far },
	}
	for _, slab in ipairs(ring) do
		for _, r in ipairs(OceanLayout.Split(slab, OceanBuilder.PART_SPAN)) do
			local sea = PartFactory.Block(
				folder,
				"HorizonSea",
				Vector3.new(r.x1 - r.x0, 1, r.z1 - r.z0),
				CFrame.new((r.x0 + r.x1) * 0.5, surfaceY - 0.8, (r.z0 + r.z1) * 0.5),
				HORIZON_COLOR,
				Enum.Material.SmoothPlastic,
				false
			)
			sea.CanQuery = false
			sea.CastShadow = false
			sea.Reflectance = 0.18
		end
	end
	return folder
end

return OceanBuilder
