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
local FishingCastState = require(script.Parent.FishingCastState)
local FishingSessionManager = require(script.Parent.FishingSessionManager)
local RemoteRateLimiter = require(script.Parent.RemoteRateLimiter)

local RodVisuals = require(script.Parent.Parent.World.RodVisuals)
local PetAndFishVisuals = require(script.Parent.Parent.World.PetAndFishVisuals)
local WhirlpoolManager = require(script.Parent.Parent.World.WhirlpoolManager)

local FishingService = {}

local forcedRarityDev: { [Player]: string } = {}
local catchRewardHooks: { (Player, Types.FishDef, Types.MutationName) -> () } = {}

function FishingService.OnFishCaught(callback: (Player, Types.FishDef, Types.MutationName) -> ())
	table.insert(catchRewardHooks, callback)
end

function FishingService.SetForcedRarityForDev(player: Player, rarity: string?)
	if rarity then forcedRarityDev[player] = rarity else forcedRarityDev[player] = nil end
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
	local profile = DataService.Get(player)
 if not profile or DataService.IsTransactionLocked(player, true) then
  FishingCastState.Reset(player, "ReadOnly")
  return
 end
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

	-- Chi gui con ca vua cau; Client tu noi vao tui (xem Shared/BagDelta).
	Net.FireClient(player, Net.ServerToClient.BagUpdated, { added = { entry }, count = #profile.fishBag })
	Net.FireClient(player, Net.ServerToClient.FishingCatchResult, {
		sessionId = sess.sessionId, success = true, uid = entry.uid, fishId = fishDef.id, fishName = fishDef.name,
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
 FishingCastState.TakeCharge(player)
 local reason = customReason or "Cancel"
 local closed = FishingSessionManager.CloseSessionOnce(player, nil, reason, silent)
 if not closed then FishingCastState.Reset(player, reason) end
end

local function triggerValidatedLandBounce(player: Player, hitPos: Vector3)
	RodVisuals.PlayLandBounce(player, hitPos)
	Net.FireClient(player, Net.ServerToClient.FishingLandBounce, { hitPos = hitPos })
	FishingCastState.Reset(player, "LandBounce")
end

function FishingService.StartCast(player: Player, aimPayload: any?)
	local profile = DataService.Get(player)
	if not profile or FishingSessionManager.Get(player) ~= nil then return end
 if DataService.IsTransactionLocked(player, true) then
  FishingCastState.SetAuto(player, false)
  FishingCastState.Reset(player, "ReadOnly")
  return
 end

 local character = player.Character
 local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
 if not character or (humanoid and humanoid.Health <= 0) then FishingCastState.Reset(player, "Died"); return end
	local isAuto = (type(aimPayload) == "table" and aimPayload.castMode == "Auto")
	if isAuto then
		if not FishingCastState.CanAutoCast(player) then FishingCastState.Reply(player); return end
		if profile.equippedHotbarSlot ~= 1 then FishingCastState.SetAuto(player, false); FishingCastState.Reply(player); return end
	elseif profile.equippedHotbarSlot ~= 1 then
		return
	elseif not FishingCastState.CanManualCast(player) then
		FishingCastState.TakeCharge(player)
		FishingCastState.Reset(player, "CastCooldown")
		return
	end


	if #profile.fishBag >= GameConfig.BAG_CAPACITY then
		Net.FireClient(player, Net.ServerToClient.Toast, { kind = "Error", text = "Fish Bag is full! Talk to Captain Barnaby to sell fish!" })
		FishingCastState.Reset(player, "BagFull")
		return
	end

	local islandId = profile.currentIsland
	local islandDef = IslandsRegistry.Get(islandId)
	local effRod = RodsConfig.GetEffectiveStats(profile.rodId, profile.ownedRods, profile.rodEnchants)
	local candidates = FishingRoller.GetEligibleCandidates(islandDef, effRod.power, effRod.maxWeight)
	if #candidates == 0 and forcedRarityDev[player] == nil then
		Net.FireClient(player, Net.ServerToClient.Toast, { kind = "Error", text = "Your rod is too weak for these waters! Equip a stronger rod!" })
		FishingCastState.Reset(player, "WeakRod")
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
			FishingCastState.TakeCharge(player)
			triggerValidatedLandBounce(player, bounceObstaclePos)
			return
		end
		waterPos = aimedWater
	end

	if not waterPos then
		FishingCastState.TakeCharge(player)
		Net.FireClient(player, Net.ServerToClient.Toast, {
			kind = "Info",
			text = if isAuto then "Walk closer to the pier or beach to use Auto-Fish!" else "No fish out there! Stand near the pier & aim at the fishing waters!",
		})
		FishingCastState.Reset(player, "NoWater")
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
		local started = FishingCastState.TakeCharge(player)
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
			if RemoteRateLimiter.IsActive(player) and hum and hum:IsA("Humanoid") then
				if hum.Health <= 0 then
					FishingService.CancelSession(player, false, "Died")
				else
					hum.Died:Connect(function()
						if RemoteRateLimiter.IsActive(player) then FishingService.CancelSession(player, false, "Died") end
					end)
				end
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
		if RemoteRateLimiter.IsActive(player) and slot ~= 1 then
			FishingCastState.SetAuto(player, false)
			FishingSessionManager.CloseSessionOnce(player, nil, "Unequip", false)
		end
	end)

	RemoteRateLimiter.Connect(Net.ClientToServer.FishingChargeStart, function(p: Player)
		local profile = DataService.Get(p)
		if profile and profile.equippedHotbarSlot == 1 and not FishingSessionManager.Get(p) then FishingCastState.StartCharge(p) end
	end)
	RemoteRateLimiter.Connect(Net.ClientToServer.FishingCast, function(p: Player) FishingService.StartCast(p, { castMode = "Auto", hitWater = true }) end)
	RemoteRateLimiter.Connect(Net.ClientToServer.FishingCastWithAim, FishingService.StartCast)
	RemoteRateLimiter.Connect(Net.ClientToServer.FishingCancel, function(p: Player)
		FishingCastState.SetAuto(p, false)
		FishingService.CancelSession(p, false, "ManualCancel")
	end)
	RemoteRateLimiter.Connect(Net.ClientToServer.FishingMinigameStrike, function(p: Player, sid: string, r: number, elapsed: number)
		FishingSessionManager.HandleStrike(p, sid, r, elapsed, finalizeFishAward)
	end)
	RemoteRateLimiter.Connect(Net.ClientToServer.SetAutoFish, function(p: Player, rawEnable: boolean, requestId: number)
  local profile = DataService.Get(p)
  local active = rawEnable == true and profile ~= nil
  local accepted = FishingCastState.ApplyRequest(p, active, requestId)
  if accepted and active and profile and profile.equippedHotbarSlot ~= 1 then ShopAndItemsService.SetHotbarSlot(p, 1) end
  FishingCastState.Reply(p)
 end)

	Players.PlayerRemoving:Connect(function(p: Player)
		forcedRarityDev[p] = nil; FishingCastState.Forget(p)
	end)
end

return FishingService
