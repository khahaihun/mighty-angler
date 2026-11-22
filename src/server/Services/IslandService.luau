--!strict
-- IslandService.luau: Mo khoa Dao moi bang Gold, dich chuyen nhan vat giua 5 Dao & hoi sinh dung Dao

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))
local IslandsRegistry = require(Shared:WaitForChild("Config"):WaitForChild("Islands"))

local DataService = require(script.Parent.DataService)
local CurrencyService = require(script.Parent.CurrencyService)
local FishingService = require(script.Parent.FishingService)
local RemoteRateLimiter = require(script.Parent.RemoteRateLimiter)
local WorldBuilder = require(script.Parent.Parent.World.WorldBuilder)

local IslandService = {}

local islandUnlockedHooks: { (Player, number) -> () } = {}

function IslandService.OnIslandUnlocked(callback: (Player, number) -> ())
	table.insert(islandUnlockedHooks, callback)
end

function IslandService.TeleportCharacterToIsland(player: Player, islandId: number)
	local char = player.Character
	if not char then
		return
	end
	local spawnCf = WorldBuilder.GetIslandSpawnCFrame(islandId)
	char:PivotTo(spawnCf)
end

local function syncClientIsland(player: Player, profile: Types.PlayerProfile)
	Net.FireClient(player, Net.ServerToClient.IslandChanged, {
		islandId = profile.currentIsland,
		unlockedIslands = profile.unlockedIslands,
	})
end

function IslandService.HandleTravel(player: Player, targetIslandId: number)
	local profile = DataService.Get(player)
	local def = IslandsRegistry.ById[targetIslandId]
	if not profile or not def then
		return
	end

	local key = tostring(targetIslandId)
	if not profile.unlockedIslands[key] then
		IslandService.HandleUnlockOrTravel(player, targetIslandId)
		return
	end

	FishingService.CancelSession(player, false, "IslandChange")
	profile.currentIsland = targetIslandId
	DataService.MarkDirty(player)
	IslandService.TeleportCharacterToIsland(player, targetIslandId)
	syncClientIsland(player, profile)

	Net.FireClient(player, Net.ServerToClient.Toast, {
		kind = "Info",
		text = "Teleported to " .. def.name .. "!",
	})
end

function IslandService.HandleUnlockOrTravel(player: Player, targetIslandId: number)
	local profile = DataService.Get(player)
	local def = IslandsRegistry.ById[targetIslandId]
	if not profile or not def then
		return
	end

	local key = tostring(targetIslandId)
	if profile.unlockedIslands[key] then
		IslandService.HandleTravel(player, targetIslandId)
		return
	end

	-- Bat buoc mo theo thu tu Dao lien truoc
	if targetIslandId > 1 and not profile.unlockedIslands[tostring(targetIslandId - 1)] then
		local prevDef = IslandsRegistry.Get(targetIslandId - 1)
		Net.FireClient(player, Net.ServerToClient.Toast, {
			kind = "Error",
			text = "Unlock " .. prevDef.name .. " first!",
		})
		return
	end

	if not CurrencyService.SpendGold(player, def.unlockCostGold) then
		Net.FireClient(player, Net.ServerToClient.Toast, {
			kind = "Error",
			text = string.format("Need %s Gold to unlock %s!", Util.FormatNumber(def.unlockCostGold), def.name),
		})
		return
	end

	profile.unlockedIslands[key] = true
	profile.currentIsland = targetIslandId
	DataService.MarkDirty(player)

	FishingService.CancelSession(player, false, "IslandChange")
	IslandService.TeleportCharacterToIsland(player, targetIslandId)
	syncClientIsland(player, profile)

	Net.FireClient(player, Net.ServerToClient.Toast, {
		kind = "Success",
		text = "🏝️ Unlocked " .. def.name .. "!",
	})

	for _, cb in ipairs(islandUnlockedHooks) do
		task.spawn(cb, player, targetIslandId)
	end
end

function IslandService.Init()
	DataService.OnProfileLoaded(function(player: Player, profile: Types.PlayerProfile)
		if not IslandsRegistry.ById[profile.currentIsland] then
			profile.currentIsland = 1
		end
		if player.Character and profile.currentIsland > 1 then
			task.defer(function()
				IslandService.TeleportCharacterToIsland(player, profile.currentIsland)
			end)
		end
		player.CharacterAdded:Connect(function()
			task.wait(0.15)
			local latest = DataService.Get(player)
			if latest and latest.currentIsland > 1 then
				IslandService.TeleportCharacterToIsland(player, latest.currentIsland)
			end
		end)
	end)

	RemoteRateLimiter.Connect(Net.ClientToServer.UnlockIsland, IslandService.HandleUnlockOrTravel)
	RemoteRateLimiter.Connect(Net.ClientToServer.TravelIsland, IslandService.HandleTravel)
end

return IslandService
