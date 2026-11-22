--!strict
-- Net.luau: Manifest duy nhat quan ly toan bo RemoteEvent giua Client va Server

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "MightyAnglerRemotes"

local Net = {}

Net.ClientToServer = {
	RequestInitialState = "C2S_RequestInitialState",
	FishingChargeStart = "C2S_FishingChargeStart",
	FishingCast = "C2S_FishingCast",
	FishingCastWithAim = "C2S_FishingCastWithAim",
	FishingCancel = "C2S_FishingCancel",
	FishingMinigameResult = "C2S_FishingMinigameResult",
	FishingMinigameStrike = "C2S_FishingMinigameStrike",
	SelectHotbarSlot = "C2S_SelectHotbarSlot",
	PinFishToSlot = "C2S_PinFishToSlot",
	ToggleLockFish = "C2S_ToggleLockFish",
	RequestBagSync = "C2S_RequestBagSync",
	SellAllFish = "C2S_SellAllFish",
	SellSingleFish = "C2S_SellSingleFish",
	SellSelectedFish = "C2S_SellSelectedFish",
	SellHeldFish = "C2S_SellHeldFish",
	AppraiseFish = "C2S_AppraiseFish",
	TurnInBounty = "C2S_TurnInBounty",
	RollEnchant = "C2S_RollEnchant",
	UnlockExclusiveRod = "C2S_UnlockExclusiveRod",
	ClaimPlaytimeGift = "C2S_ClaimPlaytimeGift",
	UpdateSettings = "C2S_UpdateSettings",
	GymRep = "C2S_GymRep",
	SetAutoTrain = "C2S_SetAutoTrain",
	SetAutoFish = "C2S_SetAutoFish",
	BuyRod = "C2S_BuyRod",
	EquipRod = "C2S_EquipRod",
	BuyBait = "C2S_BuyBait",
	SelectBait = "C2S_SelectBait",
	BuyGymGear = "C2S_BuyGymGear",
	UsePotion = "C2S_UsePotion",
	UnlockIsland = "C2S_UnlockIsland",
	TravelIsland = "C2S_TravelIsland",
	HatchEgg = "C2S_HatchEgg",
	EquipPet = "C2S_EquipPet",
	UnequipPet = "C2S_UnequipPet",
	EquipBestPets = "C2S_EquipBestPets",
	DeletePet = "C2S_DeletePet",
	DoRebirth = "C2S_DoRebirth",
	ClaimDailyReward = "C2S_ClaimDailyReward",
	ClaimQuest = "C2S_ClaimQuest",
	PromptGamepass = "C2S_PromptGamepass",
	DevAction = "C2S_DevAction",
}

Net.ServerToClient = {
	StateSnapshot = "S2C_StateSnapshot",
	ProfileAccessChanged = "S2C_ProfileAccessChanged",
	CurrencyUpdated = "S2C_CurrencyUpdated",
	BagUpdated = "S2C_BagUpdated",
	InventoryUpdated = "S2C_InventoryUpdated",
	HotbarUpdated = "S2C_HotbarUpdated",
	EnchantAndRelicsUpdated = "S2C_EnchantAndRelicsUpdated",
	PlaytimeUpdated = "S2C_PlaytimeUpdated",
	SettingsUpdated = "S2C_SettingsUpdated",
	AppraiseResult = "S2C_AppraiseResult",
	PetsUpdated = "S2C_PetsUpdated",
	ProgressionUpdated = "S2C_ProgressionUpdated",
	PerksUpdated = "S2C_PerksUpdated",
	FishingCastStarted = "S2C_FishingCastStarted",
	FishingLandBounce = "S2C_FishingLandBounce",
	FishingMinigamePrompt = "S2C_FishingMinigamePrompt",
	FishingMinigameStep = "S2C_FishingMinigameStep",
	FishingCatchResult = "S2C_FishingCatchResult",
	FishingStateReset = "S2C_FishingStateReset",
	FishingSessionClosed = "S2C_FishingSessionClosed",
	FishingAutoState = "S2C_FishingAutoState",
	GymRepFeedback = "S2C_GymRepFeedback",
	IslandChanged = "S2C_IslandChanged",
	EggHatched = "S2C_EggHatched",
	ServerEventChanged = "S2C_ServerEventChanged",
	Toast = "S2C_Toast",
	FloatingGain = "S2C_FloatingGain",
}

local function getAllEventNames(): { string }
	local list: { string } = {}
	for _, remoteName in pairs(Net.ClientToServer) do
		table.insert(list, remoteName)
	end
	for _, remoteName in pairs(Net.ServerToClient) do
		table.insert(list, remoteName)
	end
	return list
end

function Net.InitServer(): Folder
	local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	local folder: Folder
	if existing and existing:IsA("Folder") then
		folder = existing
	else
		folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
	end

	for _, remoteName in ipairs(getAllEventNames()) do
		local found = folder:FindFirstChild(remoteName)
		if not (found and found:IsA("RemoteEvent")) then
			local ev = Instance.new("RemoteEvent")
			ev.Name = remoteName
			ev.Parent = folder
		end
	end
	return folder
end

-- Nho san tham chieu RemoteEvent: moi lan gui tin khong phai quet lai toan bo manifest va thu muc.
local eventCache: { [string]: RemoteEvent } = {}

local function findEvent(remoteName: string): RemoteEvent
	if RunService:IsServer() then
		local ev = Net.InitServer():FindFirstChild(remoteName)
		assert(ev and ev:IsA("RemoteEvent"), "Missing RemoteEvent: " .. remoteName)
		return ev
	end
	local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME, 15)
	assert(folder and folder:IsA("Folder"), "Remote folder not found: " .. FOLDER_NAME)
	local ev = folder:WaitForChild(remoteName, 15)
	assert(ev and ev:IsA("RemoteEvent"), "RemoteEvent not found: " .. remoteName)
	return ev
end

function Net.GetEvent(remoteName: string): RemoteEvent
	local cached = eventCache[remoteName]
	if cached and cached.Parent ~= nil then
		return cached
	end
	local ev = findEvent(remoteName)
	eventCache[remoteName] = ev
	return ev
end

function Net.FireServer(remoteName: string, ...: any)
	Net.GetEvent(remoteName):FireServer(...)
end

function Net.FireClient(player: Player, remoteName: string, ...: any)
	Net.GetEvent(remoteName):FireClient(player, ...)
end

function Net.FireAllClients(remoteName: string, ...: any)
	Net.GetEvent(remoteName):FireAllClients(...)
end

local rateBuckets: { [Player]: { windowStart: number, count: number } } = {}
local MAX_REMOTE_CALLS_PER_SEC = 40

if RunService:IsServer() then
	Players.PlayerRemoving:Connect(function(player: Player)
		rateBuckets[player] = nil
	end)
end

function Net.OnServerEvent(remoteName: string, callback: (Player, ...any) -> ()): RBXScriptConnection
	return Net.GetEvent(remoteName).OnServerEvent:Connect(function(player: Player, ...: any)
		local now = os.clock()
		local bucket = rateBuckets[player]
		if not bucket or (now - bucket.windowStart) >= 1.0 then
			rateBuckets[player] = { windowStart = now, count = 1 }
		else
			bucket.count += 1
			if bucket.count > MAX_REMOTE_CALLS_PER_SEC then
				return
			end
		end
		callback(player, ...)
	end)
end

function Net.OnClientEvent(remoteName: string, callback: (...any) -> ()): RBXScriptConnection
	return Net.GetEvent(remoteName).OnClientEvent:Connect(callback)
end

return Net
