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
local GamepassOwnership = require(script.Parent.GamepassOwnership)

local PerkService = {}

local ownedPassesCache: { [Player]: { [string]: boolean } } = {}
local groupMemberCache: { [Player]: boolean } = {}
local groupRetryAt: { [Player]: number } = {}
local groupAnswerOwed: { [Player]: boolean } = {}
local verifyingPass: { [Player]: { [string]: boolean } } = {}
local paidRandomPolicyState: { [Player]: string } = {}
local devSimulatedFreeMode: { [Player]: boolean } = {}
local devGrantedPasses: { [Player]: { [string]: boolean } } = {}
local GROUP_RETRY_SEC = 30
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
	-- Loi API khong duoc nho thanh "khong o trong Group": hoi lai sau GROUP_RETRY_SEC.
	if os.clock() < (groupRetryAt[player] or 0) then
		groupAnswerOwed[player] = true
		return false
	end
	groupRetryAt[player] = os.clock() + GROUP_RETRY_SEC
	local ok, inGroup = pcall(function()
		return player:IsInGroupAsync(GameConfig.ROBLOX_GROUP_ID)
	end)
	if not player:IsDescendantOf(Players) then
		groupRetryAt[player] = nil
		return false
	end
	if not ok then
		groupAnswerOwed[player] = true
		return false
	end
	groupMemberCache[player] = inGroup == true
	-- Client da tung nhan "chua co quyen" luc chua hoi duoc Roblox: gui lai quyen moi de nut Auto-Train khop server.
	if inGroup == true and groupAnswerOwed[player] then
		task.spawn(PerkService.PushPerks, player)
	end
	groupAnswerOwed[player] = nil
	return inGroup == true
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
			paidRandomPolicyState[player] = if info.ArePaidRandomItemsRestricted == false then "Allowed" else "Restricted"
			PerkService.PushPerks(player)
			return
		end
		if attempt < 3 then
			task.wait(1.0)
		end
	end
	-- Never infer permission from an unavailable or malformed policy response.
	paidRandomPolicyState[player] = "Restricted"
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

-- Tra ve true khi moi pass da co cau tra loi chac chan tu Roblox (khong con "Unknown").
local function loadGamepassOwnership(player: Player): boolean
	local allKnown = true
	for _, gp in ipairs(GamepassesConfig.List) do
		local map = ownedPassesCache[player]
		if gp.id > 0 and not (map and map[gp.key]) then
			local result = GamepassOwnership.QueryPass(player, gp.id)
			if not player:IsDescendantOf(Players) then
				return true
			end
			if result == "Owned" then
				local owned: { [string]: boolean } = ownedPassesCache[player] or {}
				ownedPassesCache[player] = owned
				owned[gp.key] = true
			elseif result == "Unknown" then
				allKnown = false
			end
		end
	end
	ownedPassesCache[player] = ownedPassesCache[player] or {}
	syncExclusivePassRodIfNeeded(player)
	return allKnown
end

local function loadOwnershipWithRetry(player: Player)
	if loadGamepassOwnership(player) then
		return
	end
	-- Roblox loi luc vao game: nguoi da mua khong bi mat quyen ca phien, hoi lai o nen.
	GamepassOwnership.RetryInBackground(player, function(_isLast: boolean): boolean
		local done = loadGamepassOwnership(player)
		PerkService.PushPerks(player)
		return done
	end)
end

local function grantPurchasedPass(player: Player, gp: GamepassesConfig.GamepassDef)
	local map = ownedPassesCache[player] or {}
	ownedPassesCache[player] = map
	if map[gp.key] then
		return
	end
	map[gp.key] = true
	Net.FireClient(player, Net.ServerToClient.Toast, {
		kind = "Success",
		text = "Unlocked Gamepass: " .. gp.name .. "!",
	})
	for _, cb in ipairs(passUnlockedCallbacks) do
		task.spawn(cb, player, gp.key)
	end
	PerkService.PushPerks(player)
end

-- Tin hieu "mua xong" chi la goi y: chi cap quyen khi Roblox xac nhan nguoi choi that su so huu pass.
local function confirmPurchase(player: Player, gp: GamepassesConfig.GamepassDef)
	local busy = verifyingPass[player] or {}
	verifyingPass[player] = busy
	local map = ownedPassesCache[player]
	if busy[gp.key] or (map and map[gp.key]) then
		return
	end
	busy[gp.key] = true
	if GamepassOwnership.QueryPass(player, gp.id) == "Owned" then
		busy[gp.key] = nil
		if player:IsDescendantOf(Players) then
			grantPurchasedPass(player, gp)
		end
		return
	end
	if not player:IsDescendantOf(Players) then
		return
	end
	warn(string.format("[PerkService] Purchase signal not confirmed yet user=%d pass=%d", player.UserId, gp.id))
	Net.FireClient(player, Net.ServerToClient.Toast, {
		kind = "Info",
		text = "Confirming your " .. gp.name .. " purchase with Roblox...",
	})
	GamepassOwnership.RetryInBackground(player, function(isLast: boolean): boolean
		local owned = GamepassOwnership.QueryPass(player, gp.id) == "Owned"
		if owned or isLast then
			busy[gp.key] = nil
		end
		if owned and player:IsDescendantOf(Players) then
			grantPurchasedPass(player, gp)
		end
		return owned
	end)
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
		loadOwnershipWithRetry(player)
		if player:IsDescendantOf(Players) then
			PerkService.PushPerks(player)
		end
	end)
	for _, p in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			loadPolicyForPlayer(p)
			loadOwnershipWithRetry(p)
			PerkService.PushPerks(p)
		end)
	end

	Players.PlayerRemoving:Connect(function(player: Player)
		ownedPassesCache[player] = nil
		groupMemberCache[player] = nil
		groupRetryAt[player] = nil
		groupAnswerOwed[player] = nil
		verifyingPass[player] = nil
		paidRandomPolicyState[player] = nil
		devSimulatedFreeMode[player] = nil
		devGrantedPasses[player] = nil
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, gamePassId: number, wasPurchased: boolean)
		if not wasPurchased then
			return
		end
		for _, gp in ipairs(GamepassesConfig.List) do
			-- ID 0 la pass chua cau hinh: khong bao gio khop, ke ca khi tin hieu mang ID 0.
			if gp.id > 0 and gp.id == gamePassId then
				confirmPurchase(player, gp)
			end
		end
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
