--!strict
-- PerkService.luau: Quan ly quyen loi Auto-Train (Join Group mien phi) va Gamepasses (Auto-Fish, 2x...)

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local GamepassesConfig = require(Shared:WaitForChild("Config"):WaitForChild("GamepassesConfig"))

local PerkService = {}

local ownedPassesCache: { [Player]: { [string]: boolean } } = {}
local groupMemberCache: { [Player]: boolean } = {}
local devSimulatedFreeMode: { [Player]: boolean } = {}
local devGrantedPasses: { [Player]: { [string]: boolean } } = {}

local function checkIsInGroup(player: Player): boolean
	if GameConfig.ROBLOX_GROUP_ID <= 0 then
		return false
	end
	local cached = groupMemberCache[player]
	if cached ~= nil then
		return cached
	end
	local ok, inGroup = pcall(function()
		return player:IsInGroup(GameConfig.ROBLOX_GROUP_ID)
	end)
	local res = ok and inGroup == true
	groupMemberCache[player] = res
	return res
end

local function loadGamepassOwnership(player: Player)
	local map: { [string]: boolean } = {}
	for _, gp in ipairs(GamepassesConfig.List) do
		if gp.id > 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, gp.id)
			end)
			if ok and owns then
				map[gp.key] = true
			end
		end
	end
	ownedPassesCache[player] = map
end

function PerkService.IsStudioPerkUnlocked(player: Player): boolean
	if not RunService:IsStudio() then
		return false
	end
	if devSimulatedFreeMode[player] then
		return false
	end
	return GameConfig.DEV_UNLOCK_PERKS_IN_STUDIO
end

function PerkService.CanAutoTrain(player: Player): boolean
	if PerkService.IsStudioPerkUnlocked(player) then
		return true
	end
	return checkIsInGroup(player)
end

function PerkService.HasGamepass(player: Player, key: GamepassesConfig.GamepassKey): boolean
	local devMap = devGrantedPasses[player]
	if devMap and devMap[key] then
		return true
	end
	if key == "AutoFish" and PerkService.IsStudioPerkUnlocked(player) then
		return true
	end
	local map = ownedPassesCache[player]
	return (map ~= nil) and (map[key] == true)
end

function PerkService.GetPerkSnapshot(player: Player)
	return {
		canAutoTrain = PerkService.CanAutoTrain(player),
		autoFish = PerkService.HasGamepass(player, "AutoFish"),
		doubleGold = PerkService.HasGamepass(player, "DoubleGold"),
		doubleStrength = PerkService.HasGamepass(player, "DoubleStrength"),
		extraPets = PerkService.HasGamepass(player, "ExtraPets"),
		simFreeMode = devSimulatedFreeMode[player] == true,
	}
end

function PerkService.PushPerks(player: Player)
	Net.FireClient(player, Net.ServerToClient.PerksUpdated, PerkService.GetPerkSnapshot(player))
end

function PerkService.ToggleDevFreeMode(player: Player)
	if not RunService:IsStudio() then
		return
	end
	devSimulatedFreeMode[player] = not devSimulatedFreeMode[player]
	PerkService.PushPerks(player)
end

function PerkService.GrantAllPassesInStudio(player: Player)
	if not RunService:IsStudio() then
		return
	end
	devGrantedPasses[player] = {
		AutoFish = true,
		DoubleGold = true,
		DoubleStrength = true,
		ExtraPets = true,
	}
	PerkService.PushPerks(player)
end

function PerkService.Init()
	Players.PlayerAdded:Connect(function(player: Player)
		loadGamepassOwnership(player)
		PerkService.PushPerks(player)
	end)
	for _, p in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			loadGamepassOwnership(p)
			PerkService.PushPerks(p)
		end)
	end

	Players.PlayerRemoving:Connect(function(player: Player)
		ownedPassesCache[player] = nil
		groupMemberCache[player] = nil
		devSimulatedFreeMode[player] = nil
		devGrantedPasses[player] = nil
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, gamePassId: number, wasPurchased: boolean)
		if not wasPurchased then
			return
		end
		local map = ownedPassesCache[player] or {}
		ownedPassesCache[player] = map
		for _, gp in ipairs(GamepassesConfig.List) do
			if gp.id == gamePassId then
				map[gp.key] = true
				Net.FireClient(player, Net.ServerToClient.Toast, {
					kind = "Success",
					text = "Unlocked Gamepass: " .. gp.name .. "!",
				})
			end
		end
		PerkService.PushPerks(player)
	end)

	Net.OnServerEvent(Net.ClientToServer.RequestInitialState, function(player: Player)
		PerkService.PushPerks(player)
	end)

	Net.OnServerEvent(Net.ClientToServer.PromptGamepass, function(player: Player, rawKey: any)
		if type(rawKey) ~= "string" then
			return
		end
		local gp = GamepassesConfig.ByKey[rawKey]
		if not gp then
			return
		end
		if gp.id > 0 then
			pcall(function()
				MarketplaceService:PromptGamePassPurchase(player, gp.id)
			end)
		else
			local hint = if RunService:IsStudio()
				then ("Studio Mode: Set real Gamepass ID for '" .. gp.name .. "' in GamepassesConfig before publishing!")
				else (gp.name .. " will be available shortly!")
			Net.FireClient(player, Net.ServerToClient.Toast, {
				kind = "Info",
				text = hint,
			})
		end
	end)
end

return PerkService
