--!strict

local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))

type Validator = (any) -> boolean
type Policy = { rate: number, burst: number, args: { Validator } }
type Bucket = { tokens: number, updatedAt: number }

local RemoteRateLimiter = {}
local buckets: { [Player]: { [string]: Bucket } } = {}

local function finite(value: any): boolean
	return type(value) == "number" and value > -math.huge and value < math.huge
end

local function integer(min: number, max: number): Validator
	return function(value: any): boolean
		return finite(value) and value >= min and value <= max and value % 1 == 0
	end
end

local function shortString(value: any): boolean
	return type(value) == "string" and #value <= 128
end

local function boolean(value: any): boolean
	return type(value) == "boolean"
end

local function optional(check: Validator): Validator
	return function(value: any): boolean
		return value == nil or check(value)
	end
end

local function record(value: any, fields: { [string]: Validator }): boolean
	if type(value) ~= "table" then return false end
	for key, item in pairs(value) do
		local check = fields[key]
		if not check or not check(item) then return false end
	end
	return true
end

local aimFields = {
	castMode = function(value: any): boolean return value == "Auto" or value == "Manual" end,
	hitWater = boolean,
	targetPos = function(value: any): boolean
		return typeof(value) == "Vector3" and finite(value.X) and finite(value.Y) and finite(value.Z)
	end,
	holdRatio = function(value: any): boolean return finite(value) and value >= 0 and value <= 1 end,
}
local function aim(value: any): boolean
	return record(value, aimFields) and (value.castMode == "Auto" or value.targetPos ~= nil)
end

local settingsFields = { autoLockRare = boolean, autoLockMutated = boolean, lowGfx = boolean, muteSfx = boolean }
local function settings(value: any): boolean
	return record(value, settingsFields) and next(value) ~= nil
end

local function fishSelection(value: any): boolean
	if type(value) ~= "table" or #value > GameConfig.BAG_CAPACITY then return false end
	local count, highest = 0, 0
	for key, uid in pairs(value) do
		if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > GameConfig.BAG_CAPACITY or not shortString(uid) then
			return false
		end
		count += 1
		highest = math.max(highest, key)
	end
	return count > 0 and count == highest
end

local function policy(rate: number, burst: number, ...: Validator): Policy
	return { rate = rate, burst = burst, args = { ... } }
end

local C2S = Net.ClientToServer
local positiveId = integer(1, math.huge)
local optionalString = optional(shortString)
local policies: { [string]: Policy } = {
	[C2S.FishingChargeStart] = policy(6, 8),
	[C2S.FishingCast] = policy(4, 5),
	[C2S.FishingCastWithAim] = policy(4, 5, aim),
	[C2S.FishingCancel] = policy(6, 8),
	[C2S.FishingMinigameStrike] = policy(10, 8, shortString, positiveId, function(value: any): boolean
		return finite(value) and value >= 0
	end),
	[C2S.SetAutoFish] = policy(6, 8, boolean, integer(1, 1e9)),
	[C2S.HatchEgg] = policy(3, 4, shortString),
	[C2S.EquipPet] = policy(8, 10, shortString),
	[C2S.UnequipPet] = policy(8, 10, shortString),
	[C2S.EquipBestPets] = policy(3, 4),
	[C2S.DeletePet] = policy(6, 8, shortString),
	[C2S.SellAllFish] = policy(2, 3),
	[C2S.SellHeldFish] = policy(4, 5),
	[C2S.SellSingleFish] = policy(6, 8, shortString),
	[C2S.SellSelectedFish] = policy(3, 4, fishSelection),
	[C2S.RequestBagSync] = policy(1, 1),
	[C2S.ToggleLockFish] = policy(8, 10, shortString),
	[C2S.BuyRod] = policy(3, 4, shortString),
	[C2S.EquipRod] = policy(6, 8, shortString),
	[C2S.SelectHotbarSlot] = policy(8, 10, integer(0, 5)),
	[C2S.PinFishToSlot] = policy(6, 8, function(value: any): boolean
		return value == "2" or value == "3" or value == "4" or value == "5"
	end, shortString),
	[C2S.BuyBait] = policy(6, 8, shortString),
	[C2S.SelectBait] = policy(6, 8, shortString),
	[C2S.BuyGymGear] = policy(3, 4, positiveId),
	[C2S.UsePotion] = policy(4, 5, shortString),
	[C2S.GymRep] = policy(12, 12),
	[C2S.SetAutoTrain] = policy(4, 5, boolean),
	[C2S.RollEnchant] = policy(3, 4, shortString, boolean),
	[C2S.UnlockExclusiveRod] = policy(2, 3, shortString, optionalString),
	[C2S.AppraiseFish] = policy(3, 4, optionalString),
	[C2S.TurnInBounty] = policy(3, 4, shortString, shortString),
	[C2S.UnlockIsland] = policy(2, 3, positiveId),
	[C2S.TravelIsland] = policy(3, 4, positiveId),
	[C2S.RequestInitialState] = policy(1, 2),
	[C2S.DoRebirth] = policy(1, 2),
	[C2S.ClaimDailyReward] = policy(2, 3),
	[C2S.ClaimQuest] = policy(4, 6, shortString),
	[C2S.ClaimPlaytimeGift] = policy(5, 6, positiveId),
	[C2S.UpdateSettings] = policy(6, 8, settings),
}

function RemoteRateLimiter.IsActive(player: Player): boolean
	return buckets[player] ~= nil and player.Parent == Players
end

function RemoteRateLimiter.Allow(player: Player, actionKey: string): boolean
	local limits = policies[actionKey]
	local playerBuckets = buckets[player]
	if not limits or not playerBuckets or player.Parent ~= Players then return false end

	local now = os.clock()
	local bucket = playerBuckets[actionKey]
	if not bucket then
		playerBuckets[actionKey] = { tokens = limits.burst - 1, updatedAt = now }
		return true
	end

	bucket.tokens = math.min(limits.burst, bucket.tokens + (now - bucket.updatedAt) * limits.rate)
	bucket.updatedAt = now
	if bucket.tokens < 1 then return false end
	bucket.tokens -= 1
	return true
end

function RemoteRateLimiter.IsValidPayload(actionKey: string, ...: any): boolean
	local limits = policies[actionKey]
	if not limits or select("#", ...) > #limits.args then return false end
	for index, check in ipairs(limits.args) do
		local value = select(index, ...)
		if not check(value) then return false end
	end
	return true
end

function RemoteRateLimiter.Connect(actionKey: string, handler: (Player, ...any) -> ())
	assert(policies[actionKey], "Missing remote policy: " .. actionKey)
	Net.OnServerEvent(actionKey, function(player: Player, ...: any)
		if RemoteRateLimiter.Allow(player, actionKey) and RemoteRateLimiter.IsValidPayload(actionKey, ...) then
			handler(player, ...)
		end
	end)
end

local function trackPlayer(player: Player)
	if not buckets[player] then buckets[player] = {} end
end

Players.PlayerAdded:Connect(trackPlayer)
Players.PlayerRemoving:Connect(function(player: Player)
	buckets[player] = nil
end)
for _, player in ipairs(Players:GetPlayers()) do trackPlayer(player) end

return RemoteRateLimiter
