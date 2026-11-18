--!strict
-- PerkService.luau: Quan ly Auto-Train (Join Group mien phi), 5 Gamepasses & PolicyService (PaidRandomItems)

local MarketplaceService = game:GetService("MarketplaceService")
local PolicyService = game:GetService("PolicyService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local GamepassesConfig = require(Shared:WaitForChild("Config"):WaitForChild("GamepassesConfig"))

local DataService = require(script.Parent.DataService)

local PerkService = {}

local ownedPassesCache: { [Player]: { [string]: boolean } } = {}
local groupMemberCache: { [Player]: boolean } = {}
local paidRandomPolicyState: { [Player]: string } = {}
local devSimulatedFreeMode: { [Player]: boolean } = {}
local devGrantedPasses: { [Player]: { [string]: boolean } } = {}
local passUnlockedCallbacks: { (Player, string) -> () } = {}

function PerkService.OnGamepassUnlocked(callback: (Player, string) -> ())
	table.insert(passUnlockedCallbacks, callback)
end

local function checkIsInGroup(player: Player): boolean
	if GameConfig.ROBLOX_GROUP_ID <= 0 then
		return false
	end
	local cached = groupMemberCache[player]
	if cached ~= nil then
		return cached
	end
	local ok, inGroup = pcall(function()
		return player:IsInGroupAsync(GameConfig.ROBLOX_GROUP_ID)
	end)
	local res = ok and inGroup == true
	groupMemberCache[player] = res
	return res
end

local function loadPolicyForPlayer(player: Player)
	paidRandomPolicyState[player] = "Loading"
	for attempt = 1, 3 do
		if not player:IsDescendantOf(Players) then
			return
		end
		local ok, info = pcall(function()
			return PolicyService:GetPolicyInfoForPlayerAsync(player)
		end)
		if ok and type(info) == "table" then
			paidRandomPolicyState[player] = if info.ArePaidRandomItemsRestricted == true then "Restricted" else "Allowed"
			PerkService.PushPerks(player)
			return
		end
		if attempt < 3 then
			task.wait(1.0)
		end
	end
	-- Fail-closed tren server publish; chi cho phep trong Studio offline PlaceId == 0
	paidRandomPolicyState[player] = if RunService:IsStudio() and game.PlaceId == 0 then "Allowed" else "Restricted"
	PerkService.PushPerks(player)
end

-- Fail-closed: Tra ve true khi dang "Loading" (chua xac minh xong) hoac "Restricted"!
function PerkService.ArePaidRandomItemsRestricted(player: Player): boolean
	return paidRandomPolicyState[player] ~= "Allowed"
end

function PerkService.GetPolicyState(player: Player): string
	return paidRandomPolicyState[player] or "Loading"
end

local function syncExclusivePassRodIfNeeded(player: Player)
	if not PerkService.HasGamepass(player, "ExclusiveDragonRod") then
		return
	end
	local profile = DataService.Get(player)
	if profile and not profile.ownedRods["SeraphimDragon"] then
		profile.ownedRods["SeraphimDragon"] = true
		DataService.MarkDirty(player)
		for _, cb in ipairs(passUnlockedCallbacks) do
			task.spawn(cb, player, "ExclusiveDragonRod")
		end
	end
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
	syncExclusivePassRodIfNeeded(player)
end

function PerkService.IsStudioPerkUnlocked(player: Player): boolean
	if not RunService:IsStudio() or devSimulatedFreeMode[player] then
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
		exclusiveDragonRod = PerkService.HasGamepass(player, "ExclusiveDragonRod"),
		paidRandomRestricted = PerkService.ArePaidRandomItemsRestricted(player),
		policyState = PerkService.GetPolicyState(player),
		simFreeMode = devSimulatedFreeMode[player] == true,
	}
end

function PerkService.PushPerks(player: Player)
	syncExclusivePassRodIfNeeded(player)
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
		ExclusiveDragonRod = true,
	}
	PerkService.PushPerks(player)
end

function PerkService.Init()
	DataService.OnProfileLoaded(function(player: Player)
		syncExclusivePassRodIfNeeded(player)
		PerkService.PushPerks(player)
	end)

	Players.PlayerAdded:Connect(function(player: Player)
		loadPolicyForPlayer(player)
		loadGamepassOwnership(player)
		PerkService.PushPerks(player)
	end)
	for _, p in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			loadPolicyForPlayer(p)
			loadGamepassOwnership(p)
			PerkService.PushPerks(p)
		end)
	end

	Players.PlayerRemoving:Connect(function(player: Player)
		ownedPassesCache[player] = nil
		groupMemberCache[player] = nil
		paidRandomPolicyState[player] = nil
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
				for _, cb in ipairs(passUnlockedCallbacks) do
					task.spawn(cb, player, gp.key)
				end
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
				then ("Studio Mode: Use [DEV] Grant All Passes or set Gamepass ID for '" .. gp.name .. "' before publishing!")
				else (gp.name .. " will be available shortly!")
			Net.FireClient(player, Net.ServerToClient.Toast, {
				kind = "Info",
				text = hint,
			})
		end
	end)
end

return PerkService
