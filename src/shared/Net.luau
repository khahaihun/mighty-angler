--!strict
-- Net.luau: Manifest duy nhat quan ly toan bo RemoteEvent giua Client va Server

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "MightyAnglerRemotes"

local Net = {}

Net.ClientToServer = {
	RequestInitialState = "C2S_RequestInitialState",
	FishingCast = "C2S_FishingCast",
	FishingCancel = "C2S_FishingCancel",
	FishingMinigameResult = "C2S_FishingMinigameResult",
	SellAllFish = "C2S_SellAllFish",
	SellSingleFish = "C2S_SellSingleFish",
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
	CurrencyUpdated = "S2C_CurrencyUpdated",
	BagUpdated = "S2C_BagUpdated",
	InventoryUpdated = "S2C_InventoryUpdated",
	PetsUpdated = "S2C_PetsUpdated",
	ProgressionUpdated = "S2C_ProgressionUpdated",
	PerksUpdated = "S2C_PerksUpdated",
	FishingCastStarted = "S2C_FishingCastStarted",
	FishingMinigamePrompt = "S2C_FishingMinigamePrompt",
	FishingCatchResult = "S2C_FishingCatchResult",
	FishingStateReset = "S2C_FishingStateReset",
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

function Net.GetEvent(remoteName: string): RemoteEvent
	if RunService:IsServer() then
		local folder = Net.InitServer()
		local ev = folder:FindFirstChild(remoteName)
		assert(ev and ev:IsA("RemoteEvent"), "Missing RemoteEvent: " .. remoteName)
		return ev
	else
		local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME, 15)
		assert(folder and folder:IsA("Folder"), "Remote folder not found: " .. FOLDER_NAME)
		local ev = folder:WaitForChild(remoteName, 15)
		assert(ev and ev:IsA("RemoteEvent"), "RemoteEvent not found: " .. remoteName)
		return ev
	end
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

function Net.OnServerEvent(remoteName: string, callback: (Player, ...any) -> ()): RBXScriptConnection
	return Net.GetEvent(remoteName).OnServerEvent:Connect(callback)
end

function Net.OnClientEvent(remoteName: string, callback: (...any) -> ()): RBXScriptConnection
	return Net.GetEvent(remoteName).OnClientEvent:Connect(callback)
end

return Net
