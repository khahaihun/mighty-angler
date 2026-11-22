--!strict
-- OceanLayout.luau: Tinh cac o chu nhat (truc X/Z) de do bien quanh dao. Thuan so hoc, khong dung API Roblox.
-- Moi canh duoc lam tron theo luoi voxel Terrain 4 studs de cac lan FillBlock ke nhau khong tao ranh nuoc.

local OceanLayout = {}

export type Rect = { x0: number, x1: number, z0: number, z1: number }

OceanLayout.GRID = 4
-- Kich thuoc dao thu tuc quanh tam dao (khop WorldBuilder): tuong vo hinh va vanh cat BeachRim.
OceanLayout.ISLAND_HALF_X = 108
OceanLayout.ISLAND_NORTH = -84
OceanLayout.ISLAND_SOUTH = 176
OceanLayout.LAND_HALF_X = 79
OceanLayout.LAND_NORTH = -76
OceanLayout.LAND_SOUTH = 56 -- ho bien phia nam bat dau tu day, bien phai phu len ca ho
OceanLayout.LAND_INSET = 1
-- Vung cua mot dao dung tay khi chua co marker OceanHole: bang vung ma phoi Terrain
-- (tools/generate_sunny_shores_terrain_draft.luau) don sach truoc khi dap dao, tuc X +-130, Z -97..193 quanh tam.
-- Da ngam cua phoi ra toi Z = -96 va day cat ho ra toi Z = 181, X = +-110: deu rong hon hop dao thu tuc.
OceanLayout.MANUAL_HALF_X = 130
OceanLayout.MANUAL_NORTH = -97
OceanLayout.MANUAL_SOUTH = 193

local function down(v: number): number
	return math.floor(v / OceanLayout.GRID) * OceanLayout.GRID
end

local function up(v: number): number
	return math.ceil(v / OceanLayout.GRID) * OceanLayout.GRID
end

-- No ra ngoai: dung cho vung cam cham (dao Terrain dung tay) va bien ngoai cung.
function OceanLayout.SnapOut(r: Rect): Rect
	return { x0 = down(r.x0), x1 = up(r.x1), z0 = down(r.z0), z1 = up(r.z1) }
end

-- Co vao trong: dung cho nen dao thu tuc, de nuoc luon lan vao duoi mep cat thay vi ho khe.
function OceanLayout.SnapIn(r: Rect): Rect
	return { x0 = up(r.x0), x1 = down(r.x1), z0 = up(r.z0), z1 = down(r.z1) }
end

function OceanLayout.IslandBox(cx: number, cz: number): Rect
	return OceanLayout.SnapOut({
		x0 = cx - OceanLayout.ISLAND_HALF_X, x1 = cx + OceanLayout.ISLAND_HALF_X,
		z0 = cz + OceanLayout.ISLAND_NORTH, z1 = cz + OceanLayout.ISLAND_SOUTH,
	})
end

function OceanLayout.ManualBox(cx: number, cz: number): Rect
	return OceanLayout.SnapOut({
		x0 = cx - OceanLayout.MANUAL_HALF_X, x1 = cx + OceanLayout.MANUAL_HALF_X,
		z0 = cz + OceanLayout.MANUAL_NORTH, z1 = cz + OceanLayout.MANUAL_SOUTH,
	})
end

function OceanLayout.LandHole(cx: number, cz: number): Rect
	local inset = OceanLayout.LAND_INSET
	return OceanLayout.SnapIn({
		x0 = cx - OceanLayout.LAND_HALF_X + inset, x1 = cx + OceanLayout.LAND_HALF_X - inset,
		z0 = cz + OceanLayout.LAND_NORTH + inset, z1 = cz + OceanLayout.LAND_SOUTH - inset,
	})
end

function OceanLayout.Bounds(boxes: { Rect }, margin: number): Rect
	local b: Rect = { x0 = math.huge, x1 = -math.huge, z0 = math.huge, z1 = -math.huge }
	for _, r in ipairs(boxes) do
		b.x0, b.x1 = math.min(b.x0, r.x0), math.max(b.x1, r.x1)
		b.z0, b.z1 = math.min(b.z0, r.z0), math.max(b.z1, r.z1)
	end
	return OceanLayout.SnapOut({ x0 = b.x0 - margin, x1 = b.x1 + margin, z0 = b.z0 - margin, z1 = b.z1 + margin })
end

-- Tra ve cac o khong chong nhau phu kin bounds tru di holes.
function OceanLayout.Subtract(bounds: Rect, holes: { Rect }): { Rect }
	local xs = { bounds.x0, bounds.x1 }
	for _, h in ipairs(holes) do
		for _, x in ipairs({ h.x0, h.x1 }) do
			if x > bounds.x0 and x < bounds.x1 then
				table.insert(xs, x)
			end
		end
	end
	table.sort(xs)

	local out: { Rect } = {}
	for i = 1, #xs - 1 do
		local xa, xb = xs[i], xs[i + 1]
		if xb > xa then
			-- Moi canh X cua hole deu la diem cat, nen hole nao cham dai nay thi phu het be ngang dai.
			local blocked: { { number } } = {}
			for _, h in ipairs(holes) do
				if h.x0 < xb and h.x1 > xa and h.z1 > bounds.z0 and h.z0 < bounds.z1 then
					table.insert(blocked, { math.max(h.z0, bounds.z0), math.min(h.z1, bounds.z1) })
				end
			end
			table.sort(blocked, function(a, b)
				return a[1] < b[1]
			end)
			local z = bounds.z0
			for _, span in ipairs(blocked) do
				if span[1] > z then
					table.insert(out, { x0 = xa, x1 = xb, z0 = z, z1 = span[1] })
				end
				z = math.max(z, span[2])
			end
			if z < bounds.z1 then
				table.insert(out, { x0 = xa, x1 = xb, z0 = z, z1 = bounds.z1 })
			end
		end
	end
	return out
end

-- Chia o lon thanh cac o canh <= maxSpan (Part toi da 2048 studs), diem chia van nam tren luoi.
function OceanLayout.Split(r: Rect, maxSpan: number): { Rect }
	local function cuts(a: number, b: number): { number }
		local pieces = math.max(1, math.ceil((b - a) / maxSpan))
		local step = math.min(down(maxSpan), up((b - a) / pieces))
		local list = { a }
		while list[#list] + step < b do
			table.insert(list, list[#list] + step)
		end
		table.insert(list, b)
		return list
	end
	local xCuts, zCuts = cuts(r.x0, r.x1), cuts(r.z0, r.z1)
	local out: { Rect } = {}
	for i = 1, #xCuts - 1 do
		for j = 1, #zCuts - 1 do
			table.insert(out, { x0 = xCuts[i], x1 = xCuts[i + 1], z0 = zCuts[j], z1 = zCuts[j + 1] })
		end
	end
	return out
end

return OceanLayout
