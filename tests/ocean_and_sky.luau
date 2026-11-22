-- Buoc 6: bien bao quanh dao (OceanLayout/OceanBuilder) va bau troi (SkyBuilder).
-- Chay ma that cua cac module World; Instance, Terrain va Lighting la gia lap, khong chung minh hinh anh trong Engine.
local function check(cond, label)
	if not cond then error(label, 2) end
end

local function vec(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, {
		__add = function(a, b) return vec(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end,
		__sub = function(a, b) return vec(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end,
		__mul = function(a, b) return vec(a.X * b, a.Y * b, a.Z * b) end,
	})
end
local function cframe(x, y, z)
	return { Position = if type(x) == "table" then x else vec(x, y, z) }
end
local enumProxy = setmetatable({}, { __index = function(_, group)
	return setmetatable({}, { __index = function(_, item) return group .. "." .. item end })
end })
local TERRAIN_ONLY = { "Water", "Basalt", "Snow", "Glacier", "Ground", "LeafyGrass", "Rock", "Sandstone", "CrackedLava", "Mud", "Salt", "Limestone", "Pavement" }

local function newWorld(sources)
	local function instance(class)
		local children, attrs, parent = {}, {}, nil
		local item = { ClassName = class, Name = class, _children = children, CanQuery = true, CastShadow = true }
		function item:IsA(k) return k == class or k == "Instance" or (k == "BasePart" and (class == "Part" or class == "WedgePart")) end
		function item:FindFirstChild(name) for _, ch in ipairs(children) do if ch.Name == name then return ch end end; return nil end
		function item:FindFirstChildOfClass(k) for _, ch in ipairs(children) do if ch.ClassName == k then return ch end end; return nil end
		function item:WaitForChild(name) return self:FindFirstChild(name) end
		function item:GetChildren() return table.clone(children) end
		function item:GetDescendants() return table.clone(children) end
		function item:SetAttribute(k, v) attrs[k] = v end
		function item:GetAttribute(k) return attrs[k] end
		return setmetatable({}, {
			__index = function(_, k)
				if k == "Parent" then return parent end
				if item[k] ~= nil then return item[k] end
				return item:FindFirstChild(k) -- Workspace.Terrain
			end,
			__newindex = function(proxy, k, v)
				if k ~= "Parent" then item[k] = v; return end
				parent = v
				if v then table.insert(v._children, proxy) end
			end,
		})
	end
	local function named(class, name, parent) local i = instance(class); i.Name = name; i.Parent = parent; return i end

	local workspace, lighting, storage = named("Workspace", "Workspace"), named("Lighting", "Lighting"), named("Folder", "ReplicatedStorage")
	local terrain = named("Terrain", "Terrain", workspace)
	local fills = {}
	function terrain:FillBlock(cf, size, material)
		local p = cf.Position
		table.insert(fills, { material = material, x0 = p.X - size.X / 2, x1 = p.X + size.X / 2, y0 = p.Y - size.Y / 2,
			y1 = p.Y + size.Y / 2, z0 = p.Z - size.Z / 2, z1 = p.Z + size.Z / 2 })
	end
	local centers = { 0, 450, 900, 1350, 1800 }
	local islands = {}
	for id, x in ipairs(centers) do
		islands[id] = { id = id, centerPosition = vec(x, 10, 0), theme = { waterColor = "water" } }
	end
	local modules = { Types = {}, AssetRegistry = {}, Islands = { List = islands } }
	local token
	function token(name) return { _module = name, WaitForChild = function(_, child) return token(child) end } end
	local env
	local function load(name)
		if modules[name] == nil then
			local run = assert(loadstring(assert(sources[name], "missing source " .. name), "@" .. name))
			setfenv(run, setmetatable(table.clone(env), { __index = getfenv() }))
			modules[name] = run()
		end
		return modules[name]
	end
	env = {
		game = { GetService = function(_, service)
			if service == "Workspace" then return workspace end
			if service == "Lighting" then return lighting end
			return { WaitForChild = function() return token("Shared") end }
		end },
		script = { Parent = setmetatable({}, { __index = function(_, name) return { _module = name } end }) },
		require = function(ref) return load(ref._module) end,
		Instance = { new = instance }, Vector3 = { new = vec }, CFrame = { new = cframe }, Enum = enumProxy,
		Color3 = { fromRGB = function(r, g, b) return { r, g, b } end },
	}
	return { load = load, workspace = workspace, lighting = lighting, terrain = terrain, fills = fills, islands = islands,
		instance = instance, named = named, vec = vec, cframe = cframe }
end

local function waterAt(fills, x, z)
	for _, f in ipairs(fills) do
		if f.material == "Material.Water" and x > f.x0 and x < f.x1 and z > f.z0 and z < f.z1 then return true end
	end
	return false
end
local function overlaps(a, b) return a.x0 < b.x1 and a.x1 > b.x0 and a.z0 < b.z1 and a.z1 > b.z0 end
local function area(r) return (r.x1 - r.x0) * (r.z1 - r.z0) end
local function partRect(part)
	local p, s = part.CFrame.Position, part.Size
	return { x0 = p.X - s.X / 2, x1 = p.X + s.X / 2, z0 = p.Z - s.Z / 2, z1 = p.Z + s.Z / 2 }
end

return function(sources)
	local passed, failed = 0, 0
	local function test(name, run)
		local ok, err = pcall(run)
		if ok then passed += 1; print("PASS ocean " .. name) else failed += 1; print("FAIL ocean " .. name .. ": " .. tostring(err)) end
	end

	test("free_rects_cover_everything_except_holes", function()
		local Layout = newWorld(sources).load("OceanLayout")
		local bounds = { x0 = -400, x1 = 2200, z0 = -480, z1 = 560 }
		local holes = { Layout.LandHole(0, 0), Layout.LandHole(450, 0), Layout.IslandBox(900, 0), { x0 = 1000, x1 = 1100, z0 = -600, z1 = -400 } }
		local free = Layout.Subtract(bounds, holes)
		local total = 0
		for i, r in ipairs(free) do
			check(r.x1 > r.x0 and r.z1 > r.z0, "empty rect")
			for _, v in ipairs({ r.x0, r.x1, r.z0, r.z1 }) do check(v % 4 == 0, "edge off the 4-stud voxel grid: " .. v) end
			for _, h in ipairs(holes) do check(not overlaps(r, h), "water rect enters a hole") end
			for j = i + 1, #free do check(not overlaps(r, free[j]), "two water rects overlap") end
			total += area(r)
		end
		local holeArea = area(holes[1]) + area(holes[2]) + area(holes[3]) + 100 * 80 -- hole 4 only partly inside bounds
		check(total == area(bounds) - holeArea, "free area " .. total .. " ~= " .. (area(bounds) - holeArea))
	end)

	test("split_keeps_parts_under_the_size_limit", function()
		local Layout = newWorld(sources).load("OceanLayout")
		local big = { x0 = -1920, x1 = 3724, z0 = -2016, z1 = 2096 }
		local total = 0
		for _, r in ipairs(Layout.Split(big, 2048)) do
			check(r.x1 - r.x0 <= 2048 and r.z1 - r.z0 <= 2048, "piece larger than a Part can be")
			check(r.x0 % 4 == 0 and r.z0 % 4 == 0, "cut off the voxel grid")
			total += area(r)
		end
		check(total == area(big), "split lost or duplicated area")
		check(#Layout.Split({ x0 = 0, x1 = 100, z0 = 0, z1 = 100 }, 2048) == 1, "small rect must stay whole")
	end)

	test("sea_surrounds_and_connects_islands_but_leaves_land_dry", function()
		local w = newWorld(sources)
		local root = w.named("Folder", "MightyWorld", w.workspace)
		w.load("TerrainWaterBuilder").BuildLagoonWater(w.named("Folder", "Island_1", root), w.islands[1])
		local lagoonTop
		for _, f in ipairs(w.fills) do if f.material == "Material.Water" then lagoonTop = f.y1 end end
		table.clear(w.fills)
		local ocean = w.load("OceanBuilder").Build(root)
		check(#w.fills > 0, "no water poured")
		for _, f in ipairs(w.fills) do
			check(f.material == "Material.Water", "ocean must only pour water")
			check(math.abs(f.y1 - lagoonTop) < 1e-6, "ocean surface " .. f.y1 .. " differs from lagoon surface " .. tostring(lagoonTop))
			check(f.x1 - f.x0 <= 1024 and f.z1 - f.z0 <= 1024, "fill block too large")
		end
		for _, island in ipairs(w.islands) do
			local x = island.centerPosition.X
			check(not waterAt(w.fills, x, 0), "plaza flooded on island " .. island.id)
			check(not waterAt(w.fills, x + 70, -60) and not waterAt(w.fills, x - 70, 40), "grass corner flooded on island " .. island.id)
			check(waterAt(w.fills, x + 82, 0) and waterAt(w.fills, x - 82, 0) and waterAt(w.fills, x, -79), "gap between sand rim and sea, island " .. island.id)
			check(waterAt(w.fills, x + 78.5, 0), "water must reach under the sand rim edge, island " .. island.id)
			check(waterAt(w.fills, x, 114) and waterAt(w.fills, x + 102, 172), "ocean must cover the lagoon, island " .. island.id)
		end
		check(waterAt(w.fills, 225, 0) and waterAt(w.fills, 1575, 50), "no sea between neighbouring islands")
		check(waterAt(w.fills, -400, 0) and waterAt(w.fills, 2200, 0) and waterAt(w.fills, 900, -400) and waterAt(w.fills, 900, 500), "sea does not extend around the chain")

		local floors, horizon = 0, 0
		for _, part in ipairs(ocean:GetChildren()) do
			check(part.Size.X <= 2048 and part.Size.Z <= 2048, part.Name .. " larger than 2048 studs")
			for _, banned in ipairs(TERRAIN_ONLY) do check(part.Material ~= "Material." .. banned, part.Name .. " uses terrain-only material") end
			local top = part.CFrame.Position.Y + part.Size.Y / 2
			if part.Name == "SeaFloor" then
				floors += 1
				check(math.abs(top - w.fills[1].y0) < 1e-6, "sea floor must sit exactly under the water")
			else
				horizon += 1
				check(top < lagoonTop and top > lagoonTop - 1, "horizon sea must sit just under the water surface")
				check(part.CanCollide == false and part.CanQuery == false, "horizon sea must not block players or fishing rays")
				check(not overlaps(partRect(part), { x0 = -490, x1 = 2290, z0 = -460, z1 = 550 }), "horizon plane covers the real water")
			end
		end
		check(floors == #w.fills and horizon >= 4, "expected one floor per water block and a horizon ring")
	end)

	test("hand_built_island_terrain_is_never_touched", function()
		local w = newWorld(sources)
		local root = w.named("Folder", "MightyWorld", w.workspace)
		local manual = w.named("Folder", "Island_2", w.named("Folder", "MightyWorldManual", w.workspace))
		local Layout, Ocean = w.load("OceanLayout"), w.load("OceanBuilder")
		local box = Layout.ManualBox(450, 0)
		for _, part in ipairs(Ocean.Build(root):GetChildren()) do
			check(part.Name ~= "SeaFloor" or not overlaps(partRect(part), box), "sea floor placed inside the hand-built island")
		end
		for _, f in ipairs(w.fills) do check(not overlaps(f, box), "terrain written inside the hand-built island") end
		check(waterAt(w.fills, box.x0 - 2, 0) and waterAt(w.fills, box.x1 + 2, 0), "sea must still reach the hand-built island's edge")
		check(not waterAt(w.fills, 0, 0) and waterAt(w.fills, 82, 0), "procedural islands unaffected")
		check(waterAt(w.fills, 225, 0) and waterAt(w.fills, 675, 0), "sea still connects the hand-built island to its neighbours")

		-- Phoi Sunny Shores (tools/generate_sunny_shores_terrain_draft.luau, tam 0,10,0) rong hon hop dao thu tuc:
		-- da ngam ban kinh 92 quanh Z=-4 (toi Z=-96), day cat ho 220 x 134 quanh Z=114 (toi Z=181, X=+-110),
		-- va vung phoi don sach 260 x 290 quanh Z=48. Bien khong duoc ghi vao bat ky vung nao trong so do.
		local draft = newWorld(sources)
		draft.named("Folder", "Island_1", draft.named("Folder", "MightyWorldManual", draft.workspace))
		local draftSea = draft.load("OceanBuilder").Build(draft.named("Folder", "MightyWorld", draft.workspace))
		local footprints = {
			rock = { x0 = -92, x1 = 92, z0 = -96, z1 = 88 },
			lagoonSand = { x0 = -110, x1 = 110, z0 = 47, z1 = 181 },
			cleared = { x0 = -130, x1 = 130, z0 = -97, z1 = 193 },
		}
		for name, rect in pairs(footprints) do
			for _, f in ipairs(draft.fills) do check(not overlaps(f, rect), "ocean overwrites the Sunny Shores draft: " .. name) end
			for _, part in ipairs(draftSea:GetChildren()) do
				check(part.Name ~= "SeaFloor" or not overlaps(partRect(part), rect), "sea floor inside the Sunny Shores draft: " .. name)
			end
		end
		check(waterAt(draft.fills, 0, -102) and waterAt(draft.fills, 134, 0) and waterAt(draft.fills, 0, 198), "sea must start right outside the draft's zone")

		-- Chu du an thu hep vung cam bang marker OceanHole: bien tien sat hon nhung van khong vao trong marker.
		table.clear(w.fills)
		local marker = w.named("Part", "OceanHole", w.named("Folder", "IslandMarkers", manual))
		marker.Position, marker.Size = w.vec(450, 10, 20), w.vec(121, 10, 161)
		Ocean.Build(root)
		local hole = { x0 = 389.5, x1 = 510.5, z0 = -60.5, z1 = 100.5 }
		for _, f in ipairs(w.fills) do check(not overlaps(f, hole), "terrain written inside the OceanHole marker") end
		check(waterAt(w.fills, 386, 20) and waterAt(w.fills, 450, 106), "sea should reach the OceanHole marker")
	end)

	test("sky_clouds_and_sun_rays_added_once_and_owner_sky_kept", function()
		local w = newWorld(sources)
		local Sky = w.load("SkyBuilder")
		Sky.Apply(); Sky.Apply()
		check(#w.lighting:GetChildren() == 2, "expected exactly one Sky and one SunRaysEffect")
		check(w.lighting:FindFirstChildOfClass("Sky") and w.lighting:FindFirstChildOfClass("SunRaysEffect"), "sky or sun rays missing")
		local clouds = w.terrain:FindFirstChildOfClass("Clouds")
		check(clouds and #w.terrain:GetChildren() == 1, "Clouds must be a single child of Terrain")
		check(clouds.Cover > 0 and clouds.Cover <= 1 and clouds.Density > 0 and clouds.Density <= 1, "cloud values out of range")

		local own = newWorld(sources)
		local ownerSky = own.named("Sky", "OwnerSky", own.lighting)
		own.load("SkyBuilder").Apply()
		check(own.lighting:FindFirstChildOfClass("Sky") == ownerSky and own.lighting:FindFirstChild("MightySky") == nil, "owner's Sky was replaced")
	end)

	print(string.format("OCEAN_SKY_SUITE passed=%d failed=%d", passed, failed))
	assert(failed == 0, "ocean and sky suite failed")
end
