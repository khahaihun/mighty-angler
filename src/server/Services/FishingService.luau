--!strict
-- FishingService.luau: 4 Che do Quang Can (Server Verify Hold & Recast Cooldown), Raycast Nay Dat & Snapshot Strength

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local RodsConfig = require(Shared:WaitForChild("Config"):WaitForChild("RodsConfig"))
local BountiesConfig = require(Shared:WaitForChild("Config"):WaitForChild("BountiesConfig"))
local IslandsRegistry = require(Shared:WaitForChild("Config"):WaitForChild("Islands"))

local DataService = require(script.Parent.DataService)
local PerkService = require(script.Parent.PerkService)
local BuffAggregator = require(script.Parent.BuffAggregator)
local CurrencyService = require(script.Parent.CurrencyService)
local ShopAndItemsService = require(script.Parent.ShopAndItemsService)
local FishingRoller = require(script.Parent.FishingRoller)
local FishingSessionManager = require(script.Parent.FishingSessionManager)

local RodVisuals = require(script.Parent.Parent.World.RodVisuals)
local PetAndFishVisuals = require(script.Parent.Parent.World.PetAndFishVisuals)
local WhirlpoolManager = require(script.Parent.Parent.World.WhirlpoolManager)

local FishingService = {}

local forcedRarityDev: { [Player]: string } = {}
local autoFishActive: { [Player]: boolean } = {}
local chargeStartedAt: { [Player]: number } = {}
local nextAllowedAutoCastAt: { [Player]: number } = {}
local catchRewardHooks: { (Player, Types.FishDef, Types.MutationName) -> () } = {}

function FishingService.OnFishCaught(callback: (Player, Types.FishDef, Types.MutationName) -> ())
	table.insert(catchRewardHooks, callback)
end

function FishingService.SetForcedRarityForDev(player: Player, rarity: string?)
	if rarity then forcedRarityDev[player] = rarity else forcedRarityDev[player] = nil end
end

local function markAutoCooldownOnEnd(player: Player)
	local cd = if PerkService.HasGamepass(player, "AutoFish")
		then (GameConfig.AUTO_FISH_PRO_RECAST_SEC - 0.06)
		else (GameConfig.AUTO_FISH_FREE_RECAST_SEC - 0.08)
	nextAllowedAutoCastAt[player] = os.clock() + math.max(0.25, cd)
end

local function checkVoidScytheWhirlpoolDrop(player: Player, profile: Types.PlayerProfile, sess: FishingSessionManager.CastSession)
	if not sess.inWhirlpool or sess.islandId < 4 or math.random() > BountiesConfig.VOID_SCYTHE_WHIRLPOOL_CHANCE then
		return
	end
	if not profile.ownedRods["VoidScythe"] then
		profile.ownedRods["VoidScythe"] = true
		DataService.MarkDirty(player); ShopAndItemsService.PushInventory(player)
		Net.FireAllClients(Net.ServerToClient.Toast, { kind = "Epic", text = string.format("🌀 MYTHIC DROP! %s pulled the Void Reaper Exclusive Rod from a Whirlpool!", player.DisplayName) })
	else
		profile.enchantRelics += 2; CurrencyService.AddGems(player, 350, true)
		DataService.MarkDirty(player); ShopAndItemsService.PushInventory(player)
		Net.FireClient(player, Net.ServerToClient.Toast, { kind = "Epic", text = "🌀 Duplicate Void Reaper converted to +350 Gems & +2 Enchant Relics!" })
	end
end

local function finalizeFishAward(player: Player, sess: FishingSessionManager.CastSession)
	markAutoCooldownOnEnd(player)
	local profile = DataService.Get(player)
	local fishDef = sess.rolledFish
	if not profile or not fishDef then return end

	local mutName = sess.rolledMutation
	local mutMult = FishingRoller.GetMutationMultiplier(mutName)
	local sizeTier, weight, tierValueMult = FishingRoller.RollSizeTierAndWeight(fishDef, sess.snapRod.maxWeight, sess.snapMults.titanWeightFactor)
	local avgWeight = (fishDef.minWeight + fishDef.maxWeight) * 0.5
	local weightFactor = math.clamp(weight / math.max(0.1, avgWeight), 0.75, 1.65)
	local midasBonus = sess.snapMults.midasSellBonus
	local sellValue = math.max(1, math.floor(fishDef.baseValue * weightFactor * tierValueMult * mutMult * midasBonus + 0.5))

	local rarityOrder = GameConfig.RarityOrder[fishDef.rarity] or 1
	local shouldAutoLock = (profile.autoLockRare and rarityOrder >= 5) or (profile.autoLockMutated and mutName ~= "None") or (sizeTier == "Titanic")

	local entry: Types.CaughtFish = {
		uid = Util.NewUid(), fishId = fishDef.id, weight = weight, mutation = mutName,
		sellValue = sellValue, originalValue = sellValue, sizeTier = sizeTier,
		locked = shouldAutoLock, soulbound = false, midasBonus = midasBonus,
	}
	table.insert(profile.fishBag, entry)

	profile.stats.fishCaught += 1
	if rarityOrder >= 3 then profile.stats.rareCaught += 1 end
	if fishDef.rarity == "Boss" then profile.stats.bossCaught += 1 end
	if mutName ~= "None" then profile.stats.mutationsCaught += 1 end
	if weight > (profile.indexFish[fishDef.id] or 0) then profile.indexFish[fishDef.id] = weight end

	ShopAndItemsService.ConsumeGivenBaitOnCatch(player, profile, sess.snapBait)
	local snapStrAmount = fishDef.strengthReward * math.max(1.0, sess.snapMults.strengthMult)
	local gainedStr = CurrencyService.AddStrength(player, snapStrAmount, false, false)
	checkVoidScytheWhirlpoolDrop(player, profile, sess)
	DataService.MarkDirty(player)

	PetAndFishVisuals.SpawnCaughtFishLeap(player, sess.waterPos, fishDef, mutName)
	RodVisuals.ClearBobber(player)

	Net.FireClient(player, Net.ServerToClient.BagUpdated, { fishBag = profile.fishBag })
	Net.FireClient(player, Net.ServerToClient.FishingCatchResult, {
		success = true, uid = entry.uid, fishId = fishDef.id, fishName = fishDef.name,
		rarity = fishDef.rarity, sizeTier = sizeTier, weight = weight, mutation = mutName,
		sellValue = sellValue, locked = shouldAutoLock, strengthGained = gainedStr,
		bagCount = #profile.fishBag, bagCap = GameConfig.BAG_CAPACITY,
	})

	if fishDef.rarity == "Boss" or fishDef.rarity == "Legendary" or mutName == "Cosmic" or sizeTier == "Titanic" then
		local prefix = if (mutName :: string) ~= "None" then (mutName .. " ") else ""
		local tierPrefix = if (sizeTier :: string) ~= "Normal" then (sizeTier .. " ") else ""
		Net.FireAllClients(Net.ServerToClient.Toast, { kind = "Epic", text = string.format("🔥 %s caught a %s%s%s (%s)!", player.DisplayName, prefix, tierPrefix, fishDef.name, Util.FormatWeight(weight)) })
	end

	for _, cb in ipairs(catchRewardHooks) do task.spawn(cb, player, fishDef, mutName) end
end

function FishingService.CancelSession(player: Player, silent: boolean?, customReason: string?)
	FishingSessionManager.CloseSessionOnce(player, nil, customReason or "Cancel", silent)
end

local function triggerValidatedLandBounce(player: Player, rawHitPos: any)
	local hitPos = FishingRoller.IsWithinLandBounceRange(player, rawHitPos)
	if not hitPos then return end
	RodVisuals.PlayLandBounce(player, hitPos)
	Net.FireClient(player, Net.ServerToClient.FishingLandBounce, { hitPos = hitPos })
end

function FishingService.StartCast(player: Player, aimPayload: any?)
	local profile = DataService.Get(player)
	if not profile or FishingSessionManager.Get(player) ~= nil then return end

	local isAuto = (type(aimPayload) == "table" and aimPayload.castMode == "Auto")
	if isAuto then
		if not autoFishActive[player] or os.clock() < (nextAllowedAutoCastAt[player] or 0) then return end
		if profile.equippedHotbarSlot ~= 1 then ShopAndItemsService.SetHotbarSlot(player, 1) end
	elseif profile.equippedHotbarSlot ~= 1 then
		return
	end

	if type(aimPayload) == "table" and aimPayload.hitWater == false then
		chargeStartedAt[player] = nil
		triggerValidatedLandBounce(player, aimPayload.targetPos)
		return
	end

	if #profile.fishBag >= GameConfig.BAG_CAPACITY then
		Net.FireClient(player, Net.ServerToClient.Toast, { kind = "Error", text = "Fish Bag is full! Talk to Captain Barnaby to sell fish!" })
		Net.FireClient(player, Net.ServerToClient.FishingStateReset, { bagFull = true })
		return
	end

	local islandId = profile.currentIsland
	local islandDef = IslandsRegistry.Get(islandId)
	local effRod = RodsConfig.GetEffectiveStats(profile.rodId, profile.ownedRods, profile.rodEnchants)
	local candidates = FishingRoller.GetEligibleCandidates(islandDef, effRod.power, effRod.maxWeight)
	if #candidates == 0 and forcedRarityDev[player] == nil then
		Net.FireClient(player, Net.ServerToClient.Toast, { kind = "Error", text = "Your rod is too weak for these waters! Equip a stronger rod!" })
		Net.FireClient(player, Net.ServerToClient.FishingStateReset, { weakRod = true })
		return
	end

	local waterPos: Vector3? = nil
	if isAuto then
		waterPos = FishingRoller.FindWaterCastPoint(player, islandId)
	else
		local aimedWater, bounceObstaclePos = FishingRoller.ValidateAimedWaterPoint(
			player, islandId, if type(aimPayload) == "table" then aimPayload.targetPos else nil
		)
		if bounceObstaclePos then
			chargeStartedAt[player] = nil
			triggerValidatedLandBounce(player, bounceObstaclePos)
			return
		end
		waterPos = aimedWater
	end

	if not waterPos then
		chargeStartedAt[player] = nil
		Net.FireClient(player, Net.ServerToClient.Toast, {
			kind = "Info",
			text = if isAuto then "Walk closer to the pier or beach to use Auto-Fish!" else "Stand near the ocean & aim directly at open water to cast!",
		})
		Net.FireClient(player, Net.ServerToClient.FishingStateReset, { tooFar = true })
		return
	end

	local castMode, castLuckAdd, castLureAdd = "ManualNormal", 0, 0
	if isAuto then
		if PerkService.HasGamepass(player, "AutoFish") then
			castMode, castLuckAdd, castLureAdd = "AutoPro", GameConfig.PERFECT_CAST_LUCK_ADD, GameConfig.PERFECT_CAST_LURE_ADD
		else
			castMode = "AutoFree"
		end
	else
		local started = chargeStartedAt[player]
		chargeStartedAt[player] = nil
		castMode, castLuckAdd, castLureAdd = FishingRoller.ResolveManualHoldBonuses(
			started, if type(aimPayload) == "table" then aimPayload.holdRatio else nil
		)
	end

	local snapMults = BuffAggregator.GetMultipliers(player, castLuckAdd, castLureAdd)
	local snapBait = if profile.activeBait and (profile.bait[profile.activeBait] or 0) > 0 then profile.activeBait else nil
	local inWhirlpool = WhirlpoolManager.IsPointInWhirlpool(islandId, waterPos)
	local rawWait = GameConfig.BASE_BITE_MIN_SEC + math.random() * (GameConfig.BASE_BITE_MAX_SEC - GameConfig.BASE_BITE_MIN_SEC)
	local biteDelay = math.max(GameConfig.MIN_BITE_FLOOR_SEC, rawWait / math.max(1, snapMults.biteSpeedMult))

	local sess = FishingSessionManager.CreateWaitingSession(player, islandId, waterPos, inWhirlpool, castMode, effRod, snapBait, snapMults)
	RodVisuals.SpawnCastBobber(player, waterPos)
	Net.FireClient(player, Net.ServerToClient.FishingCastStarted, {
		sessionId = sess.sessionId, waterPos = waterPos, biteDelay = biteDelay, inWhirlpool = inWhirlpool, castMode = castMode,
	})

	local capturedId = sess.sessionId
	task.delay(biteDelay, function()
		local current = FishingSessionManager.Get(player)
		if not current or current.sessionId ~= capturedId or not DataService.Get(player) then return end
		local forced = forcedRarityDev[player]; forcedRarityDev[player] = nil
		local fish = FishingRoller.RollFishSpecies(forced, islandDef, candidates, current.snapMults, current.inWhirlpool)
		local mutName, _ = FishingRoller.RollMutation(current.snapMults.mutationMult, current.snapMults.midasSellBonus)
		current.rolledFish = fish; current.rolledMutation = mutName

		if fish.rarity == "Common" or fish.rarity == "Uncommon" then
			RodVisuals.PlayBiteSplash(player, false)
			local closed = FishingSessionManager.CloseSessionOnce(player, capturedId, "Win", true)
			if closed then finalizeFishAward(player, closed) end
		else
			RodVisuals.PlayBiteSplash(player, true)
			FishingSessionManager.BeginMinigame(player, current, fish, mutName)
		end
	end)
end

function FishingService.Init()
	local function bindCharacter(player: Player, char: Model)
		task.spawn(function()
			local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 5)
			if hum and hum:IsA("Humanoid") then
				if hum.Health <= 0 then FishingSessionManager.CloseSessionOnce(player, nil, "Died", false)
				else hum.Died:Connect(function() FishingSessionManager.CloseSessionOnce(player, nil, "Died", false) end) end
			end
			task.wait(0.15)
			ShopAndItemsService.SyncCharacterHandVisuals(player)
		end)
	end

	DataService.OnProfileLoaded(function(player: Player)
		if player.Character then bindCharacter(player, player.Character) end
		player.CharacterAdded:Connect(function(char: Model) bindCharacter(player, char) end)
	end)

	ShopAndItemsService.OnHotbarSlotChanged(function(player: Player, slot: number)
		if slot ~= 1 then
			autoFishActive[player] = false
			FishingSessionManager.CloseSessionOnce(player, nil, "Unequip", false)
		end
	end)

	Net.OnServerEvent(Net.ClientToServer.FishingChargeStart, function(p: Player) chargeStartedAt[p] = os.clock() end)
	Net.OnServerEvent(Net.ClientToServer.FishingCast, function(p: Player) FishingService.StartCast(p, { castMode = "Auto", hitWater = true }) end)
	Net.OnServerEvent(Net.ClientToServer.FishingCastWithAim, function(p: Player, payload: any) FishingService.StartCast(p, payload) end)
	Net.OnServerEvent(Net.ClientToServer.FishingCancel, function(p: Player)
		autoFishActive[p] = false
		FishingService.CancelSession(p, false, "ManualCancel")
	end)
	Net.OnServerEvent(Net.ClientToServer.FishingMinigameStrike, function(p: Player, sid: any, r: any, elapsed: any)
		FishingSessionManager.HandleStrike(p, sid, r, elapsed, finalizeFishAward)
		if FishingSessionManager.Get(p) == nil then markAutoCooldownOnEnd(p) end
	end)
	Net.OnServerEvent(Net.ClientToServer.SetAutoFish, function(p: Player, rawEnable: any) autoFishActive[p] = (rawEnable == true) end)

	Players.PlayerRemoving:Connect(function(p: Player)
		forcedRarityDev[p] = nil; autoFishActive[p] = nil; chargeStartedAt[p] = nil; nextAllowedAutoCastAt[p] = nil
	end)
end

return FishingService
