--!strict
-- Islands/init.luau: Registry tap hop cau hinh cac Dao (bat dau voi Dao 1, mo rong du 5 Dao o Chang 2)

local Types = require(script.Parent.Parent.Types)
local Island1 = require(script.Island1_SunnyShores)

local IslandsRegistry = {}

IslandsRegistry.List = {
	Island1,
} :: { Types.IslandDef }

IslandsRegistry.ById = {} :: { [number]: Types.IslandDef }
IslandsRegistry.FishById = {} :: { [string]: Types.FishDef }

local function rebuildIndexes()
	table.clear(IslandsRegistry.ById)
	table.clear(IslandsRegistry.FishById)
	for _, island in ipairs(IslandsRegistry.List) do
		IslandsRegistry.ById[island.id] = island
		for _, fish in ipairs(island.fishPool) do
			IslandsRegistry.FishById[fish.id] = fish
		end
	end
end

rebuildIndexes()

function IslandsRegistry.Get(islandId: number): Types.IslandDef
	return IslandsRegistry.ById[islandId] or Island1
end

function IslandsRegistry.GetFish(fishId: string): Types.FishDef?
	return IslandsRegistry.FishById[fishId]
end

function IslandsRegistry.GetTotalIslands(): number
	return #IslandsRegistry.List
end

return IslandsRegistry
