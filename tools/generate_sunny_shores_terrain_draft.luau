--!strict
-- generate_sunny_shores_terrain_draft.luau
-- HUONG DAN DUNG TRONG ROBLOX STUDIO (CHEDO EDIT - KHONG PHAI PLAY):
-- 1. Mo build/mighty-angler-dev.rbxlx trong Roblox Studio, sau do File -> Save to File As...
--    thanh file rieng (vi du: studio/SunnyShores_Manual.rbxl) — KHONG ghi de build/mighty-angler-dev.rbxlx!
-- 2. Mo View -> Command Bar, copy-paste toan bo file nay va bam Enter.
-- 3. Script se lot day bien cat + do nuoc Y = 9.7 kin 100% mep hop bien (khop tuyet doi OceanBuilder),
--    dap phoi dia hinh Terrain cong tu nhien cho Dao 1 (Sunny Shores) + dat IslandMarkers + OceanBounds.
-- 4. Dung Terrain Editor -> Smooth / Paint / Grow de vuot muot theo gu cua ban, luu file rieng roi bam Play (F5)!

local Workspace = game:GetService("Workspace")
local Terrain = Workspace.Terrain

local CENTER = Vector3.new(0, 10, 0)
-- Khop tuyet doi OceanLayout.ManualBox(0, 0) da SnapOut theo luoi voxel 4 studs:
-- X: -132..+132 (rong 264), Z: -100..+196 (sau 296), tam Z = 48.
-- Mat nuoc toan game: Y = CENTER.Y - 0.3 = 9.7; day bien: Y = 0.0 (sau 9.7 studs).
local WATER_SURFACE_Y = CENTER.Y - 0.3
local OCEAN_FLOOR_Y = 0
local OCEAN_DEPTH = WATER_SURFACE_Y - OCEAN_FLOOR_Y
local BOX_CENTER_X = CENTER.X
local BOX_CENTER_Z = CENTER.Z + 48
local BOX_SIZE_X = 264
local BOX_SIZE_Z = 296

-- 1. Chinh mau Terrain tuoi sang theo Gu B (PS99 x Arm Wrestle)
Terrain.WaterColor = Color3.fromRGB(26, 184, 240)
Terrain.WaterReflectance = 0.65
Terrain.WaterTransparency = 0.25
Terrain.WaterWaveSize = 0.14
Terrain.WaterWaveSpeed = 13

Terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(82, 214, 88))
Terrain:SetMaterialColor(Enum.Material.LeafyGrass, Color3.fromRGB(116, 232, 98))
Terrain:SetMaterialColor(Enum.Material.Sand, Color3.fromRGB(250, 226, 162))
Terrain:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(148, 122, 98))

-- 2. Don cuc bo toan bo hop Dao 1 (khong xoa Terrain o cac dao khac!)
Terrain:FillBlock(CFrame.new(BOX_CENTER_X, CENTER.Y + 4, BOX_CENTER_Z), Vector3.new(BOX_SIZE_X, 52, BOX_SIZE_Z), Enum.Material.Air)

-- 3. Lot day bien cat (Y = -4..0) & do nuoc Y = 9.7 phu KIN 100% toi mep hop [-132..132, -100..196]
--    truoc khi dap dao de noi lien mach tuyet doi voi bien ngoai khoi cua OceanBuilder (0 studs ho!).
Terrain:FillBlock(
	CFrame.new(BOX_CENTER_X, OCEAN_FLOOR_Y - 2, BOX_CENTER_Z),
	Vector3.new(BOX_SIZE_X, 4, BOX_SIZE_Z),
	Enum.Material.Sand
)
Terrain:FillBlock(
	CFrame.new(BOX_CENTER_X, (WATER_SURFACE_Y + OCEAN_FLOOR_Y) * 0.5, BOX_CENTER_Z),
	Vector3.new(BOX_SIZE_X, OCEAN_DEPTH, BOX_SIZE_Z),
	Enum.Material.Water
)

-- 4. Dap nen da ngam & bo cat vong cung thoai thoai noi tren mat bien
Terrain:FillCylinder(CFrame.new(CENTER + Vector3.new(0, -8, -4)), 16, 92, Enum.Material.Rock)
Terrain:FillCylinder(CFrame.new(CENTER + Vector3.new(0, -2.2, 2)), 5.6, 84, Enum.Material.Sand)

-- 5. Dap san co trung tam phang cho Spawn, Cho, Gym & Quang truong Trung
Terrain:FillCylinder(CFrame.new(CENTER + Vector3.new(0, -0.8, -8)), 2.2, 68, Enum.Material.Grass)
Terrain:FillBlock(CFrame.new(CENTER + Vector3.new(0, -0.6, 4)), Vector3.new(124, 1.8, 98), Enum.Material.Grass)

-- 6. Dap cac ngong doi co & ghenh da tu nhien (bat doi xung cho song dong)
local hills = {
	{ pos = Vector3.new(-66, 3.5, -50), r = 24, mat = Enum.Material.Rock },
	{ pos = Vector3.new(-61, 7.6, -49), r = 19, mat = Enum.Material.Grass },
	{ pos = Vector3.new(62, 5.0, -54), r = 27, mat = Enum.Material.Rock },
	{ pos = Vector3.new(60, 9.6, -52), r = 22, mat = Enum.Material.Grass },
	{ pos = Vector3.new(-28, 2.4, -70), r = 17, mat = Enum.Material.LeafyGrass },
	{ pos = Vector3.new(35, 3.0, -66), r = 19, mat = Enum.Material.LeafyGrass },
	{ pos = Vector3.new(-74, 0.5, 18), r = 15, mat = Enum.Material.Sand },
	{ pos = Vector3.new(76, 0.4, 28), r = 13, mat = Enum.Material.Sand },
}
for _, h in ipairs(hills) do
	Terrain:FillBall(CENTER + h.pos, h.r, h.mat)
end

-- 7. Cat phang lai loi ra cau tau & quang truong trung tam (chi cat tu Y >= 10.2, KHONG an vao mat nuoc 9.7)
Terrain:FillBlock(CFrame.new(CENTER + Vector3.new(0, 6.2, 2)), Vector3.new(122, 12, 96), Enum.Material.Air)

-- 8. Them bai cat can tu nhien o day vinh phia Nam duoi lop nuoc 9.7 de nhin ro phao & xoan nuoc
local lagoonCenter = CENTER + Vector3.new(0, 0, 114)
Terrain:FillBlock(CFrame.new(lagoonCenter + Vector3.new(0, -7.2, 0)), Vector3.new(212, 3.6, 124), Enum.Material.Sand)
Terrain:FillBlock(CFrame.new(lagoonCenter + Vector3.new(0, -2.55, 0)), Vector3.new(212, 4.5, 124), Enum.Material.Water)

-- 9. Tao thu muc MightyWorldManual/Island_1 gom IslandMarkers (co OceanHole) & OceanBounds om dao
local manualRoot = Workspace:FindFirstChild("MightyWorldManual")
if not (manualRoot and manualRoot:IsA("Folder")) then
	manualRoot = Instance.new("Folder")
	manualRoot.Name = "MightyWorldManual"
	manualRoot.Parent = Workspace
end

local oldIsland = manualRoot:FindFirstChild("Island_1")
if oldIsland then
	oldIsland:Destroy()
end

local island1 = Instance.new("Folder")
island1.Name = "Island_1"
island1.Parent = manualRoot

local markers = Instance.new("Folder")
markers.Name = "IslandMarkers"
markers.Parent = island1

local function addMarker(name: string, size: Vector3, cf: CFrame, color: Color3, transparency: number?)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.Neon
	p.Transparency = transparency or 0.55
	p.Anchored = true
	p.CanCollide = false
	p.Parent = markers
end

-- OceanHole khop chinh xac hop [-132..132, -100..196] de OceanBuilder do bien lien mach ngay mep ngoai
addMarker("OceanHole", Vector3.new(BOX_SIZE_X, 10, BOX_SIZE_Z), CFrame.new(BOX_CENTER_X, 5, BOX_CENTER_Z), Color3.fromRGB(48, 180, 255), 0.92)
addMarker("Spawn", Vector3.new(10, 0.5, 10), CFrame.new(CENTER + Vector3.new(0, 0.25, 2)) * CFrame.Angles(0, math.rad(180), 0), Color3.fromRGB(255, 224, 72))
addMarker("Dock", Vector3.new(4, 0.5, 4), CFrame.new(CENTER), Color3.fromRGB(168, 116, 72))
addMarker("FishingWater", Vector3.new(206, 1.2, 118), CFrame.new(lagoonCenter + Vector3.new(0, -0.9, 0)), Color3.fromRGB(48, 198, 255))
addMarker("SellMarket", Vector3.new(13, 0.5, 6), CFrame.new(CENTER + Vector3.new(-28, 0, 44)), Color3.fromRGB(245, 92, 76))
addMarker("RodShop", Vector3.new(13, 0.5, 6), CFrame.new(CENTER + Vector3.new(28, 0, 44)), Color3.fromRGB(56, 168, 255))
addMarker("NpcMerchant", Vector3.new(3, 0.5, 3), CFrame.new(CENTER + Vector3.new(-28, 0, 36.5)), Color3.fromRGB(255, 206, 76))
addMarker("NpcShop", Vector3.new(3, 0.5, 3), CFrame.new(CENTER + Vector3.new(28, 0, 36.5)), Color3.fromRGB(98, 224, 255))
addMarker("NpcCollector", Vector3.new(3, 0.5, 3), CFrame.new(CENTER + Vector3.new(-11, 0, 48.2)), Color3.fromRGB(122, 255, 186))
addMarker("NpcCoach", Vector3.new(3, 0.5, 3), CFrame.new(CENTER + Vector3.new(-36, 0, -10)) * CFrame.Angles(0, math.rad(-90), 0), Color3.fromRGB(255, 118, 88))
addMarker("Gym_1", Vector3.new(12, 0.5, 12), CFrame.new(CENTER + Vector3.new(-52, 0, -22)), Color3.fromRGB(82, 214, 126))
addMarker("Gym_2", Vector3.new(12, 0.5, 12), CFrame.new(CENTER + Vector3.new(-52, 0, 0)), Color3.fromRGB(68, 178, 255))
addMarker("Gym_3", Vector3.new(12, 0.5, 12), CFrame.new(CENTER + Vector3.new(-52, 0, 22)), Color3.fromRGB(255, 152, 62))
addMarker("EggGold", Vector3.new(8, 0.5, 8), CFrame.new(CENTER + Vector3.new(50, 0, -12)), Color3.fromRGB(255, 208, 64))
addMarker("EggGem", Vector3.new(10, 0.5, 10), CFrame.new(CENTER + Vector3.new(50, 0, 12)), Color3.fromRGB(214, 96, 255))
addMarker("EnchantAltar", Vector3.new(10, 0.5, 10), CFrame.new(CENTER + Vector3.new(42, 0, -36)), Color3.fromRGB(196, 108, 255))
addMarker("PortalNext", Vector3.new(16, 0.5, 5), CFrame.new(CENTER + Vector3.new(0, 0, -58)), Color3.fromRGB(82, 232, 255))

-- OceanBounds rieng om tron dao + vinh cau (X = +-118, Z = -94..+182), nam tren vung bien kin nuoc, khong chan giua bai trong
local oceanBounds = Instance.new("Folder")
oceanBounds.Name = "OceanBounds"
oceanBounds.Parent = island1

local function addBoundWall(name: string, size: Vector3, cf: CFrame)
	local wall = Instance.new("Part")
	wall.Name = name
	wall.Size = size
	wall.CFrame = cf
	wall.Color = Color3.fromRGB(26, 184, 240)
	wall.Material = Enum.Material.SmoothPlastic
	wall.Transparency = 1
	wall.Anchored = true
	wall.CanCollide = true
	wall.CastShadow = false
	wall:SetAttribute("FishingRayIgnore", true)
	wall.Parent = oceanBounds
end

addBoundWall("OceanBoundW", Vector3.new(2, 40, 278), CFrame.new(CENTER + Vector3.new(-118, 4, 44)))
addBoundWall("OceanBoundE", Vector3.new(2, 40, 278), CFrame.new(CENTER + Vector3.new(118, 4, 44)))
addBoundWall("OceanBoundN", Vector3.new(238, 40, 2), CFrame.new(CENTER + Vector3.new(0, 4, -94)))
addBoundWall("OceanBoundS", Vector3.new(238, 40, 2), CFrame.new(CENTER + Vector3.new(0, 4, 182)))

print("[SunnyShores] Da tao phoi Terrain Dao 1 lien mach bien Y=9.7 (0 ho vanh) + 17 IslandMarkers (co OceanHole) + OceanBounds!")
