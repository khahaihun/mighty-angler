--!strict
-- Islands/init.luau: Registry tap hop day du 5 Dao ban Launch v1.0 (de dang mo rong Dao 6+ o cac ban Update)

local Types = require(script.Parent.Parent.Types)
local Island1 = require(script.Island1_SunnyShores)
local Island2 = require(script.Island2_CoralDepths)
local Island3 = require(script.Island3_MysticSwamp)
local Island4 = require(script.Island4_EmberIsle)
local Island5 = require(script.Island5_CelestialDeep)

local IslandsRegistry = {}

IslandsRegistry.List = {
	Island1,
	Island2,
	Island3,
	Island4,
	Island5,
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
