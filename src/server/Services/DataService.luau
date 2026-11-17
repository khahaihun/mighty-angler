--!strict
-- DataService.luau: Quan ly luu/tai PlayerProfile qua DataStore kem che do Fallback muot trong Studio

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Util = require(Shared:WaitForChild("Util"))
local Net = require(Shared:WaitForChild("Net"))
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))

local DataService = {}

local profiles: { [Player]: Types.PlayerProfile } = {}
local dirtyFlags: { [Player]: boolean } = {}
local profileLoadedCallbacks: { (Player, Types.PlayerProfile) -> () } = {}
local dataStore: DataStore? = nil
local studioMemoryFallback = false

local function tryGetDataStore(): DataStore?
	if studioMemoryFallback then
		return nil
	end
	if dataStore then
		return dataStore
	end
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(GameConfig.DATASTORE_NAME)
	end)
	if ok and result then
		dataStore = result
		return dataStore
	else
		studioMemoryFallback = true
		return nil
	end
end

local function setupLeaderstats(player: Player, profile: Types.PlayerProfile)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	ls.Parent = player

	local strVal = Instance.new("StringValue")
	strVal.Name = "Strength"
	strVal.Value = Util.FormatNumber(profile.strength)
	strVal.Parent = ls

	local goldVal = Instance.new("StringValue")
	goldVal.Name = "Gold"
	goldVal.Value = Util.FormatNumber(profile.gold)
	goldVal.Parent = ls

	local rebVal = Instance.new("IntValue")
	rebVal.Name = "Rebirths"
	rebVal.Value = profile.rebirths
	rebVal.Parent = ls
end

function DataService.SyncLeaderstats(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	local ls = player:FindFirstChild("leaderstats")
	if not ls then
		return
	end
	local strVal = ls:FindFirstChild("Strength")
	if strVal and strVal:IsA("StringValue") then
		strVal.Value = Util.FormatNumber(profile.strength)
	end
	local goldVal = ls:FindFirstChild("Gold")
	if goldVal and goldVal:IsA("StringValue") then
		goldVal.Value = Util.FormatNumber(profile.gold)
	end
	local rebVal = ls:FindFirstChild("Rebirths")
	if rebVal and rebVal:IsA("IntValue") then
		rebVal.Value = profile.rebirths
	end
end

local function sanitizeLoadedProfile(raw: any): Types.PlayerProfile
	local defaults = GameConfig.CreateDefaultProfile()
	if type(raw) ~= "table" then
		return defaults
	end
	local merged = Util.Reconcile(raw, defaults :: any) :: Types.PlayerProfile
	merged.unlockedIslands["1"] = true
	merged.ownedRods["Twig"] = true
	return merged
end

local function loadPlayerProfile(player: Player)
	local key = "Player_" .. tostring(player.UserId)
	local loadedData: any = nil
	local store = tryGetDataStore()

	if store then
		local ok, res = pcall(function()
			return store:GetAsync(key)
		end)
		if ok then
			loadedData = res
		else
			studioMemoryFallback = true
		end
	end

	if not player:IsDescendantOf(Players) then
		return
	end

	local profile = sanitizeLoadedProfile(loadedData)
	profiles[player] = profile
	dirtyFlags[player] = false
	setupLeaderstats(player, profile)

	for _, cb in ipairs(profileLoadedCallbacks) do
		task.spawn(cb, player, profile)
	end
end

function DataService.SaveProfile(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	local store = tryGetDataStore()
	if not store then
		return
	end

	local key = "Player_" .. tostring(player.UserId)
	local snapshot = Util.DeepCopy(profile)
	local ok = pcall(function()
		store:UpdateAsync(key, function(_oldValue)
			return snapshot
		end)
	end)
	if ok then
		dirtyFlags[player] = false
	end
end

function DataService.Get(player: Player): Types.PlayerProfile?
	return profiles[player]
end

function DataService.WaitForProfile(player: Player, timeoutSec: number?): Types.PlayerProfile?
	local deadline = os.clock() + (timeoutSec or 10)
	while player:IsDescendantOf(Players) and os.clock() < deadline do
		local p = profiles[player]
		if p then
			return p
		end
		task.wait(0.05)
	end
	return profiles[player]
end

function DataService.MarkDirty(player: Player)
	if profiles[player] then
		dirtyFlags[player] = true
	end
end

function DataService.ResetProfileForDev(player: Player): Types.PlayerProfile?
	if not RunService:IsStudio() then
		return nil
	end
	if not profiles[player] then
		return nil
	end
	local fresh = GameConfig.CreateDefaultProfile()
	profiles[player] = fresh
	dirtyFlags[player] = true
	DataService.SyncLeaderstats(player)
	DataService.PushFullSnapshot(player)
	return fresh
end

function DataService.OnProfileLoaded(callback: (Player, Types.PlayerProfile) -> ())
	table.insert(profileLoadedCallbacks, callback)
	for player, profile in pairs(profiles) do
		task.spawn(callback, player, profile)
	end
end

function DataService.PushFullSnapshot(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	Net.FireClient(player, Net.ServerToClient.StateSnapshot, {
		profile = profile,
		serverNow = os.time(),
		studioFallback = studioMemoryFallback,
	})
end

function DataService.Init()
	Net.OnServerEvent(Net.ClientToServer.RequestInitialState, function(player: Player)
		local profile = DataService.WaitForProfile(player, 8)
		if profile then
			DataService.PushFullSnapshot(player)
		end
	end)

	Players.PlayerAdded:Connect(loadPlayerProfile)
	for _, existingPlayer in ipairs(Players:GetPlayers()) do
		task.spawn(loadPlayerProfile, existingPlayer)
	end

	Players.PlayerRemoving:Connect(function(player: Player)
		DataService.SaveProfile(player)
		profiles[player] = nil
		dirtyFlags[player] = nil
	end)

	game:BindToClose(function()
		for player, _ in pairs(profiles) do
			DataService.SaveProfile(player)
		end
	end)

	-- Vong lap autosave & cong thoi gian choi moi giay
	task.spawn(function()
		local accSave = 0
		while true do
			task.wait(1)
			accSave += 1
			for player, profile in pairs(profiles) do
				profile.stats.playTimeSec += 1
				if accSave >= GameConfig.AUTOSAVE_INTERVAL_SEC and dirtyFlags[player] then
					task.spawn(DataService.SaveProfile, player)
				end
			end
			if accSave >= GameConfig.AUTOSAVE_INTERVAL_SEC then
				accSave = 0
			end
		end
	end)
end

return DataService
