--!strict
-- generate_sunny_shores_terrain_draft.luau
-- HUONG DAN DUNG TRONG ROBLOX STUDIO (CHEDO EDIT - KHONG PHAI PLAY):
-- 1. Mo build/mighty-angler-dev.rbxlx trong Roblox Studio.
-- 2. Mo View -> Command Bar, copy-paste toan bo file nay va bam Enter.
-- 3. Script se tu tao phoi dia hinh Terrain cong tu nhien cho Dao 1 (Sunny Shores) + dat cac diem cam co (IslandMarkers).
-- 4. Dung Terrain Editor -> Smooth / Paint / Grow de vuot muot theo gu cua ban, roi luu place va bam Play (F5)!

local Workspace = game:GetService("Workspace")
local Terrain = Workspace.Terrain

local CENTER = Vector3.new(0, 10, 0)

-- 1. Chinh mau Terrain tuoi sang theo Gu B (PS99 x Arm Wrestle)
Terrain.WaterColor = Color3.fromRGB(26, 178, 236)
Terrain.WaterReflectance = 0.65
Terrain.WaterTransparency = 0.25
Terrain.WaterWaveSize = 0.14
Terrain.WaterWaveSpeed = 13

Terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(88, 212, 82))
Terrain:SetMaterialColor(Enum.Material.LeafyGrass, Color3.fromRGB(112, 226, 94))
Terrain:SetMaterialColor(Enum.Material.Sand, Color3.fromRGB(248, 228, 168))
Terrain:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(142, 124, 108))

-- 2. Don cuc bo vung Dao 1 (khong xoa Terrain o cac dao khac!)
Terrain:FillBlock(CFrame.new(CENTER + Vector3.new(0, 4, 48)), Vector3.new(260, 52, 290), Enum.Material.Air)

-- 3. Dap nen da ngam & bo cat vong cung thoai thoai
Terrain:FillCylinder(CFrame.new(CENTER + Vector3.new(0, -10, -4)), 14, 92, Enum.Material.Rock)
Terrain:FillCylinder(CFrame.new(CENTER + Vector3.new(0, -2.2, 2)), 5.6, 84, Enum.Material.Sand)

-- 4. Dap san co trung tam phang cho Spawn, Cho, Gym & Quang truong Trung
Terrain:FillCylinder(CFrame.new(CENTER + Vector3.new(0, -0.8, -8)), 2.2, 68, Enum.Material.Grass)
Terrain:FillBlock(CFrame.new(CENTER + Vector3.new(0, -0.6, 4)), Vector3.new(124, 1.8, 98), Enum.Material.Grass)

-- 5. Dap cac ngong doi co & ghenh da tu nhien phia Bac - Dong Bac - Tay Bac
local hills = {
	{ pos = Vector3.new(-64, 3.5, -52), r = 24, mat = Enum.Material.Rock },
	{ pos = Vector3.new(-60, 7.5, -52), r = 20, mat = Enum.Material.Grass },
	{ pos = Vector3.new(64, 4.5, -52), r = 26, mat = Enum.Material.Rock },
	{ pos = Vector3.new(62, 9.0, -50), r = 21, mat = Enum.Material.Grass },
	{ pos = Vector3.new(-32, 2.5, -68), r = 18, mat = Enum.Material.LeafyGrass },
	{ pos = Vector3.new(32, 2.5, -68), r = 18, mat = Enum.Material.LeafyGrass },
	{ pos = Vector3.new(-74, 0.5, 22), r = 14, mat = Enum.Material.Sand },
	{ pos = Vector3.new(74, 0.5, 22), r = 14, mat = Enum.Material.Sand },
}
for _, h in ipairs(hills) do
	Terrain:FillBall(CENTER + h.pos, h.r, h.mat)
end

-- 6. Cat phang lai loi ra cau tau & quang truong trung tam de dung khong bi lun
Terrain:FillBlock(CFrame.new(CENTER + Vector3.new(0, 6.2, 2)), Vector3.new(122, 12, 96), Enum.Material.Air)

-- 7. Day bien cat an toan & vinh nuoc Terrain Water phia Nam
local lagoonCenter = CENTER + Vector3.new(0, 0, 114)
Terrain:FillBlock(CFrame.new(lagoonCenter + Vector3.new(0, -6.5, 0)), Vector3.new(220, 4, 134), Enum.Material.Sand)
Terrain:FillBlock(CFrame.new(lagoonCenter + Vector3.new(0, -2.5, 0)), Vector3.new(208, 4.4, 120), Enum.Material.Water)

-- 8. Tao thu muc MightyWorldManual/Island_1/IslandMarkers de code tu gan NPC, Gym, Trung, Cau tau & Nuoc
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

local function addMarker(name: string, size: Vector3, cf: CFrame, color: Color3)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.Neon
	p.Transparency = 0.55
	p.Anchored = true
	p.CanCollide = false
	p.Parent = markers
end

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

print("[SunnyShores] Da tao xong phoi Terrain Dao 1 + 16 diem cam co IslandMarkers! Ban co the dung Terrain Editor de vuot muot roi bam Play (F5).")
