param([string]$LuauExe = (Join-Path $PSScriptRoot 'luau.exe'))
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
[IO.Directory]::CreateDirectory((Join-Path $root 'build')) | Out-Null

$assetSrc = [IO.File]::ReadAllText((Join-Path $root 'src/shared/AssetRegistry.luau'))
$fishSrc = [IO.File]::ReadAllText((Join-Path $root 'src/shared/ModelBuilders/FishModelBuilder.luau'))
$petSrc = [IO.File]::ReadAllText((Join-Path $root 'src/shared/ModelBuilders/PetModelBuilder.luau'))
$rodSrc = [IO.File]::ReadAllText((Join-Path $root 'src/shared/ModelBuilders/RodAndWeightBuilder.luau'))
$manualSrc = [IO.File]::ReadAllText((Join-Path $root 'src/server/World/ManualIslandAdapter.luau'))
$npcSrc = [IO.File]::ReadAllText((Join-Path $root 'src/server/World/NpcBuilder.luau'))
$scenerySrc = [IO.File]::ReadAllText((Join-Path $root 'src/server/World/IslandScenery1_2.luau'))
$draftSrc = [IO.File]::ReadAllText((Join-Path $root 'tools/generate_sunny_shores_terrain_draft.luau'))
$suiteSrc = [IO.File]::ReadAllText((Join-Path $root 'tests/art_pipeline_and_terrain.luau'))

$runner = @'
local function makeVec3(x, y, z)
	local v = { X = x or 0, Y = y or 0, Z = z or 0 }
	return setmetatable(v, {
		__add = function(a, b) return makeVec3(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end,
		__sub = function(a, b) return makeVec3(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end,
		__mul = function(a, b)
			if type(b) == "number" then return makeVec3(a.X * b, a.Y * b, a.Z * b) end
			return makeVec3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
		end,
	})
end
local Vector3 = {
	new = makeVec3,
	zero = makeVec3(0, 0, 0),
}
local function makeCFrame(x, y, z)
	local pos = if type(x) == "table" then x else makeVec3(x or 0, y or 0, z or 0)
	local cf = { Position = pos }
	function cf:Inverse() return makeCFrame(-self.Position.X, -self.Position.Y, -self.Position.Z) end
	function cf:ToObjectSpace(other) return makeCFrame(other.Position - self.Position) end
	return setmetatable(cf, {
		__mul = function(a, b)
			return makeCFrame(a.Position + b.Position)
		end,
		__sub = function(a, _b)
			return makeCFrame(0, 0, 0)
		end,
	})
end
local CFrame = {
	new = makeCFrame,
	Angles = function() return makeCFrame(0, 0, 0) end,
}
local Color3 = {
	fromRGB = function(r, g, b) return { R = r, G = g, B = b, Lerp = function(self) return self end } end,
	new = function(r, g, b) return { R = r * 255, G = g * 255, B = b * 255, Lerp = function(self) return self end } end,
}
local ColorSequence = { new = function(a, b) return { a, b } end }
local NumberSequenceKeypoint = { new = function(t, v) return { Time = t, Value = v } end }
local NumberSequence = { new = function(t) return t end }
local NumberRange = { new = function(a, b) return { Min = a, Max = b } end }
local Enum = {
	Material = {
		SmoothPlastic = "SmoothPlastic", Neon = "Neon", Metal = "Metal", Foil = "Foil",
		Wood = "Wood", WoodPlanks = "WoodPlanks", Slate = "Slate", Fabric = "Fabric",
		Air = "Air", Water = "Water", Sand = "Sand", Grass = "Grass", LeafyGrass = "LeafyGrass", Rock = "Rock",
	},
	PartType = { Ball = "Ball", Block = "Block", Cylinder = "Cylinder" },
	HumanoidDisplayDistanceType = { None = "None" },
	HumanoidHealthDisplayType = { AlwaysOff = "AlwaysOff" },
	HumanoidRigType = { R15 = "R15" },
}
local origTypeof = typeof
local function typeof(v)
	if type(v) == "table" and v.Position ~= nil and v.Inverse ~= nil then return "CFrame" end
	if type(v) == "table" and v.X ~= nil and v.Y ~= nil and v.Z ~= nil then return "Vector3" end
	return if origTypeof then origTypeof(v) else type(v)
end

local CLASS_HIERARCHY = {
	Part = { BasePart = true, PVInstance = true, Instance = true },
	MeshPart = { BasePart = true, PVInstance = true, Instance = true },
	WedgePart = { BasePart = true, PVInstance = true, Instance = true },
	Script = { LuaSourceContainer = true, Instance = true },
	LocalScript = { LuaSourceContainer = true, Instance = true },
	ModuleScript = { LuaSourceContainer = true, Instance = true },
	BillboardGui = { LayerCollector = true, Instance = true },
	SurfaceGui = { LayerCollector = true, Instance = true },
	Model = { PVInstance = true, Instance = true },
	Folder = { Instance = true },
	Highlight = { Instance = true },
	ParticleEmitter = { Instance = true },
	SurfaceAppearance = { Instance = true },
	Decal = { Instance = true },
	Texture = { Instance = true },
	Attachment = { Instance = true },
	WeldConstraint = { Instance = true },
	Motor6D = { Instance = true },
	Humanoid = { Instance = true },
	Animator = { Instance = true },
}

local function makeInstance(className, name)
	local children = {}
	local attrs = {}
	local pivotCf = CFrame.new(0, 0, 0)
	local scaleVal = 1
	local inst
	local props = {
		ClassName = className,
		Name = name or className,
		Anchored = true,
		CanCollide = true,
		CanQuery = true,
		CastShadow = true,
		Massless = false,
		Transparency = 0,
		Enabled = true,
		Size = Vector3.new(2, 2, 2),
		CFrame = CFrame.new(0, 0, 0),
		Color = Color3.fromRGB(255, 255, 255),
		Material = Enum.Material.SmoothPlastic,
		TextureID = "",
		PrimaryPart = nil,
	}
	local methods = {}
	function methods:IsA(cls)
		if self.ClassName == cls then return true end
		local h = CLASS_HIERARCHY[self.ClassName]
		return h ~= nil and h[cls] == true
	end
	function methods:FindFirstChild(n, recursive)
		for _, ch in ipairs(children) do
			if ch.Name == n then return ch end
			if recursive then
				local sub = ch:FindFirstChild(n, true)
				if sub then return sub end
			end
		end
		return nil
	end
	function methods:WaitForChild(n) return self:FindFirstChild(n) end
	function methods:GetChildren()
		local copy = {}
		for i, ch in ipairs(children) do copy[i] = ch end
		return copy
	end
	function methods:GetDescendants()
		local out = {}
		local function walk(list)
			for _, ch in ipairs(list) do
				table.insert(out, ch)
				walk(ch:GetChildren())
			end
		end
		walk(children)
		return out
	end
	function methods:SetAttribute(k, v) attrs[k] = v end
	function methods:GetAttribute(k) return attrs[k] end
	function methods:Destroy()
		if props._parent then
			local siblings = props._parent._children
			for i = #siblings, 1, -1 do
				if siblings[i] == self then table.remove(siblings, i) break end
			end
			props._parent = nil
		end
	end
	function methods:Clone()
		local copy = makeInstance(self.ClassName, self.Name)
		for k, v in pairs(props) do
			if k ~= "_parent" and k ~= "_children" and k ~= "PrimaryPart" then
				copy[k] = v
			end
		end
		for k, v in pairs(attrs) do copy:SetAttribute(k, v) end
		local primaryName = if props.PrimaryPart then props.PrimaryPart.Name else nil
		for _, ch in ipairs(children) do
			local cc = ch:Clone()
			cc.Parent = copy
			if primaryName and cc.Name == primaryName then
				copy.PrimaryPart = cc
			end
		end
		return copy
	end
	function methods:PivotTo(cf)
		pivotCf = cf
		if props.PrimaryPart then props.PrimaryPart.CFrame = cf end
	end
	function methods:GetPivot() return pivotCf end
	function methods:ScaleTo(s) scaleVal = s end
	function methods:GetScale() return scaleVal end
	function methods:GetBoundingBox() return pivotCf, Vector3.new(4, 2, 2) end
	props._children = children
	inst = setmetatable({}, {
		__index = function(_, k)
			if methods[k] ~= nil then return methods[k] end
			if k == "Parent" then return props._parent end
			return props[k]
		end,
		__newindex = function(self, k, v)
			if k == "Parent" then
				if props._parent then
					local old = props._parent._children
					for i = #old, 1, -1 do
						if old[i] == self then table.remove(old, i) break end
					end
				end
				props._parent = v
				if v and v._children then
					table.insert(v._children, self)
				end
			else
				props[k] = v
			end
		end,
	})
	return inst
end

local Instance = { new = function(cls) return makeInstance(cls, cls) end }
local ReplicatedStorage = makeInstance("Folder", "ReplicatedStorage")
local Workspace = makeInstance("Folder", "Workspace")
local terrainOps = {}
local mockTerrain = {
	WaterColor = Color3.fromRGB(0, 0, 0),
	WaterReflectance = 0,
	WaterTransparency = 0,
	WaterWaveSize = 0,
	WaterWaveSpeed = 0,
	SetMaterialColor = function() end,
	FillBlock = function(_, cf, size, mat)
		table.insert(terrainOps, { kind = "Block", cf = cf, size = size, mat = mat })
	end,
	FillCylinder = function(_, cf, h, r, mat)
		table.insert(terrainOps, { kind = "Cylinder", cf = cf, h = h, r = r, mat = mat })
	end,
	FillBall = function(_, pos, r, mat)
		table.insert(terrainOps, { kind = "Ball", pos = pos, r = r, mat = mat })
	end,
}
Workspace.Terrain = mockTerrain
local SharedFolder = makeInstance("Folder", "Shared")
SharedFolder.Parent = ReplicatedStorage
local ConfigFolder = makeInstance("Folder", "Config")
ConfigFolder.Parent = SharedFolder
local game = {
	GetService = function(_, name)
		if name == "ReplicatedStorage" then return ReplicatedStorage end
		if name == "Workspace" then return Workspace end
		if name == "RunService" then return { IsServer = function() return true end } end
		if name == "CollectionService" then
			return { AddTag = function(_, inst, tag) inst:SetAttribute("Tag_" .. tostring(tag), true) end }
		end
		return {}
	end,
}

local loadedModules = {}
local function makeModToken(key)
	local tok = makeInstance("ModuleScript", key)
	tok._modKey = key
	return tok
end
local function require(mod)
	return loadedModules[mod._modKey]
end

loadedModules["Types"] = {}
loadedModules["GameConfig"] = {
	ANIMATED_NPC_TAG = "MightyAnimatedNpc",
	Mutations = {
		None = { color = Color3.fromRGB(255, 255, 255) },
		Shiny = { color = Color3.fromRGB(110, 235, 255) },
		Golden = { color = Color3.fromRGB(255, 212, 62) },
		Cosmic = { color = Color3.fromRGB(214, 96, 255) },
	},
}
loadedModules["PartFactory"] = {
	Block = function(parent, name, size, cf, col, mat, canCollide, trans)
		local p = makeInstance("Part", name)
		p.Size = size; p.CFrame = cf; p.Color = col; p.Material = mat or Enum.Material.SmoothPlastic
		p.CanCollide = if canCollide == nil then true else canCollide
		p.Transparency = trans or 0
		p.Parent = parent
		return p
	end,
	Ball = function(parent, name, diam, pos, col)
		local p = makeInstance("Part", name)
		p.Size = Vector3.new(diam, diam, diam); p.CFrame = CFrame.new(pos); p.Color = col
		p.Parent = parent
		return p
	end,
	VerticalCylinder = function(parent, name, h, d, cf, col)
		local p = makeInstance("Part", name)
		p.Size = Vector3.new(h, d, d); p.CFrame = cf; p.Color = col
		p.Parent = parent
		return p
	end,
	AddBillboard = function() end,
	AddPrompt = function(host, action, obj, dist, kind, attrs)
		local pr = makeInstance("Folder", "Prompt_" .. kind)
		pr:SetAttribute("Action", action); pr:SetAttribute("Dist", dist)
		if attrs then for k, v in pairs(attrs) do pr:SetAttribute(k, v) end end
		pr.Parent = host
		return pr
	end,
}

makeModToken("Types").Parent = SharedFolder
makeModToken("GameConfig").Parent = ConfigFolder
makeModToken("AssetRegistry").Parent = SharedFolder

local script = { Parent = { PartFactory = makeModToken("PartFactory"), ManualIslandAdapter = makeModToken("ManualIslandAdapter") } }

local function loadAssetRegistry()
'@
$runner += "`n" + $assetSrc + "`nend`nloadedModules['AssetRegistry'] = loadAssetRegistry()`n"
$runner += "local function loadFishBuilder()`n" + $fishSrc + "`nend`nloadedModules['FishModelBuilder'] = loadFishBuilder()`n"
$runner += "local function loadPetBuilder()`n" + $petSrc + "`nend`nloadedModules['PetModelBuilder'] = loadPetBuilder()`n"
$runner += "local function loadRodBuilder()`n" + $rodSrc + "`nend`nloadedModules['RodAndWeightBuilder'] = loadRodBuilder()`n"
$runner += "local function loadManualAdapter()`n" + $manualSrc + "`nend`nloadedModules['ManualIslandAdapter'] = loadManualAdapter()`n"
$runner += "local function loadNpcBuilder()`n" + $npcSrc + "`nend`nloadedModules['NpcBuilder'] = loadNpcBuilder()`n"
$runner += "local function loadScenery12()`n" + $scenerySrc + "`nend`nloadedModules['IslandScenery1_2'] = loadScenery12()`n"
$runner += "local function runTerrainDraft()`n" + $draftSrc + "`nend`n"
$runner += "local function loadSuite()`n" + $suiteSrc + "`nend`n"
$runner += @'
local runSuite = loadSuite()
runSuite({
	AssetRegistry = loadedModules["AssetRegistry"],
	FishModelBuilder = loadedModules["FishModelBuilder"],
	PetModelBuilder = loadedModules["PetModelBuilder"],
	RodAndWeightBuilder = loadedModules["RodAndWeightBuilder"],
	ManualIslandAdapter = loadedModules["ManualIslandAdapter"],
	NpcBuilder = loadedModules["NpcBuilder"],
	IslandScenery1_2 = loadedModules["IslandScenery1_2"],
	runTerrainDraft = runTerrainDraft,
}, {
	makeInstance = makeInstance,
	Workspace = Workspace,
	ReplicatedStorage = ReplicatedStorage,
	terrainOps = terrainOps,
})
'@

$path = Join-Path $root 'build/test_art_pipeline_and_terrain.luau'
[IO.File]::WriteAllText($path, $runner, [Text.UTF8Encoding]::new($false))
& $LuauExe $path
exit $LASTEXITCODE
