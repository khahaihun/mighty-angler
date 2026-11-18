--!strict
-- FishingService.luau: Dieu phoi 4 Che do Quang Can, Vat ly Nay Dat, Auto-Fish Free/Pro, SizeTier, Auto-Lock & Drop VoidScythe

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
local catchRewardHooks: { (Player, Types.FishDef, Types.MutationName) -> () } = {}

function FishingService.OnFishCaught(callback: (Player, Types.FishDef, Types.MutationName) -> ())
	table.insert(catchRewardHooks, callback)
end

function FishingService.SetForcedRarityForDev(player: Player, rarity: string?)
	if rarity then
		forcedRarityDev[player] = rarity
	else
		forcedRarityDev[player] = nil
	end
end

local function isAutoCatchRarity(rarity: Types.Rarity): boolean
	return rarity == "Common" or rarity == "Uncommon"
end

local function checkVoidScytheWhirlpoolDrop(player: Player, profile: Types.PlayerProfile, sess: FishingSessionManager.CastSession)
	if not sess.inWhirlpool or sess.islandId < 4 then
		return
	end
	if math.random() > BountiesConfig.VOID_SCYTHE_WHIRLPOOL_CHANCE then
		return
	end
	if not profile.ownedRods["VoidScythe"] then
		profile.ownedRods["VoidScythe"] = true
		DataService.MarkDirty(player)
		ShopAndItemsService.PushInventory(player)
		Net.FireAllClients(Net.ServerToClient.Toast, {
			kind = "Epic",
			text = string.format("🌀 MYTHIC DROP! %s pulled the Void Reaper Exclusive Rod from a Whirlpool!", player.DisplayName),
		})
	else
		profile.enchantRelics += 2
		CurrencyService.AddGems(player, 350, true)
		DataService.MarkDirty(player)
		ShopAndItemsService.PushInventory(player)
		Net.FireClient(player, Net.ServerToClient.Toast, {
			kind = "Epic",
			text = "🌀 Duplicate Void Reaper converted to +350 Gems & +2 Enchant Relics!",
		})
	end
end

local function finalizeFishAward(player: Player, sess: FishingSessionManager.CastSession)
	local profile = DataService.Get(player)
	local fishDef = sess.rolledFish
	if not profile or not fishDef then
		return
	end

	local mutName = sess.rolledMutation
	local mutMult = FishingRoller.GetMutationMultiplier(mutName)
	local sizeTier, weight, tierValueMult = FishingRoller.RollSizeTierAndWeight(
		fishDef,
		sess.snapRod.maxWeight,
		sess.snapMults.titanWeightFactor
	)
	local avgWeight = (fishDef.minWeight + fishDef.maxWeight) * 0.5
	local weightFactor = math.clamp(weight / math.max(0.1, avgWeight), 0.75, 1.65)
	local midasBonus = sess.snapMults.midasSellBonus
	local sellValue = math.max(1, math.floor(fishDef.baseValue * weightFactor * tierValueMult * mutMult * midasBonus + 0.5))

	local rarityOrder = GameConfig.RarityOrder[fishDef.rarity] or 1
	local shouldAutoLock = (profile.autoLockRare and rarityOrder >= 5)
		or (profile.autoLockMutated and mutName ~= "None")
		or (sizeTier == "Titanic")

	local entry: Types.CaughtFish = {
		uid = Util.NewUid(),
		fishId = fishDef.id,
		weight = weight,
		mutation = mutName,
		sellValue = sellValue,
		originalValue = sellValue,
		sizeTier = sizeTier,
		locked = shouldAutoLock,
		soulbound = false,
		midasBonus = midasBonus,
	}
	table.insert(profile.fishBag, entry)

	profile.stats.fishCaught += 1
	if rarityOrder >= 3 then
		profile.stats.rareCaught += 1
	end
	if fishDef.rarity == "Boss" then
		profile.stats.bossCaught += 1
	end
	if mutName ~= "None" then
		profile.stats.mutationsCaught += 1
	end
	if weight > (profile.indexFish[fishDef.id] or 0) then
		profile.indexFish[fishDef.id] = weight
	end

	ShopAndItemsService.ConsumeGivenBaitOnCatch(player, profile, sess.snapBait)
	local gainedStr = CurrencyService.AddStrength(player, fishDef.strengthReward, true, false)
	checkVoidScytheWhirlpoolDrop(player, profile, sess)
	DataService.MarkDirty(player)

	PetAndFishVisuals.SpawnCaughtFishLeap(player, sess.waterPos, fishDef, mutName)
	RodVisuals.ClearBobber(player)

	Net.FireClient(player, Net.ServerToClient.BagUpdated, { fishBag = profile.fishBag })
	Net.FireClient(player, Net.ServerToClient.FishingCatchResult, {
		success = true,
		uid = entry.uid,
		fishId = fishDef.id,
		fishName = fishDef.name,
		rarity = fishDef.rarity,
		sizeTier = sizeTier,
		weight = weight,
		mutation = mutName,
		sellValue = sellValue,
		locked = shouldAutoLock,
		strengthGained = gainedStr,
		bagCount = #profile.fishBag,
		bagCap = GameConfig.BAG_CAPACITY,
	})

	if fishDef.rarity == "Boss" or fishDef.rarity == "Legendary" or mutName == "Cosmic" or sizeTier == "Titanic" then
		local prefix = if (mutName :: string) ~= "None" then (mutName .. " ") else ""
		local tierPrefix = if (sizeTier :: string) ~= "Normal" then (sizeTier .. " ") else ""
		Net.FireAllClients(Net.ServerToClient.Toast, {
			kind = "Epic",
			text = string.format("🔥 %s caught a %s%s%s (%s)!", player.DisplayName, prefix, tierPrefix, fishDef.name, Util.FormatWeight(weight)),
		})
	end

	for _, cb in ipairs(catchRewardHooks) do
		task.spawn(cb, player, fishDef, mutName)
	end
end

function FishingService.CancelSession(player: Player, silent: boolean?)
	FishingSessionManager.CloseSessionOnce(player, nil, "Cancel", silent)
end

local function resolveCastBonuses(player: Player, rawMode: any, rawHoldRatio: any): (string, number, number)
	local isAuto = (rawMode == "Auto") or (autoFishActive[player] == true and rawMode == nil)
	if isAuto then
		if PerkService.HasGamepass(player, "AutoFish") then
			return "AutoPro", GameConfig.PERFECT_CAST_LUCK_ADD, GameConfig.PERFECT_CAST_LURE_ADD
		end
		return "AutoFree", 0, 0
	end
	local hold = tonumber(rawHoldRatio) or 0
	if hold >= GameConfig.PERFECT_HOLD_MIN and hold <= GameConfig.PERFECT_HOLD_MAX then
		return "ManualPerfect", GameConfig.PERFECT_CAST_LUCK_ADD, GameConfig.PERFECT_CAST_LURE_ADD
	end
	return "ManualNormal", 0, 0
end

function FishingService.StartCast(player: Player, aimPayload: any?)
	local profile = DataService.Get(player)
	if not profile or FishingSessionManager.Get(player) ~= nil then
		return
	end

	-- Neu nguoi choi bam chuot quang phao trung Dat/Cau go/Da -> Nay tung 1-2 nhip roi thu ve, KHONG tru moi!
	if type(aimPayload) == "table" and aimPayload.hitWater == false then
		local hitPos = aimPayload.targetPos
		if typeof(hitPos) == "Vector3" then
			RodVisuals.PlayLandBounce(player, hitPos)
			Net.FireClient(player, Net.ServerToClient.FishingLandBounce, { hitPos = hitPos })
		end
		return
	end

	if profile.equippedHotbarSlot ~= 1 then
		ShopAndItemsService.SetHotbarSlot(player, 1)
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
		Net.FireClient(player, Net.ServerToClient.Toast, {
			kind = "Error",
			text = "Your rod is too weak for these waters! Equip a stronger rod!",
		})
		Net.FireClient(player, Net.ServerToClient.FishingStateReset, { weakRod = true })
		return
	end

	local waterPos = if type(aimPayload) == "table"
		then FishingRoller.ValidateAimedWaterPoint(player, islandId, aimPayload.targetPos)
		else nil
	if not waterPos then
		waterPos = FishingRoller.FindWaterCastPoint(player, islandId)
	end
	if not waterPos and player.Character then
		local pierSpot = islandDef.centerPosition + Vector3.new(0, 4.2, 112)
		player.Character:PivotTo(CFrame.new(pierSpot) * CFrame.Angles(0, math.rad(180), 0))
		waterPos = FishingRoller.FindWaterCastPoint(player, islandId)
	end
	if not waterPos then
		Net.FireClient(player, Net.ServerToClient.FishingStateReset, { tooFar = true })
		return
	end

	local rawMode = if type(aimPayload) == "table" then aimPayload.castMode else nil
	local rawHold = if type(aimPayload) == "table" then aimPayload.holdRatio else nil
	local castMode, castLuckAdd, castLureAdd = resolveCastBonuses(player, rawMode, rawHold)

	local snapMults = BuffAggregator.GetMultipliers(player, castLuckAdd, castLureAdd)
	local snapBait = if profile.activeBait and (profile.bait[profile.activeBait] or 0) > 0 then profile.activeBait else nil
	local inWhirlpool = WhirlpoolManager.IsPointInWhirlpool(islandId, waterPos)

	local rawWait = GameConfig.BASE_BITE_MIN_SEC + math.random() * (GameConfig.BASE_BITE_MAX_SEC - GameConfig.BASE_BITE_MIN_SEC)
	local biteDelay = math.max(GameConfig.MIN_BITE_FLOOR_SEC, rawWait / math.max(1, snapMults.biteSpeedMult))

	local sess = FishingSessionManager.CreateWaitingSession(player, islandId, waterPos, inWhirlpool, castMode, effRod, snapBait, snapMults)
	RodVisuals.SpawnCastBobber(player, waterPos)
	Net.FireClient(player, Net.ServerToClient.FishingCastStarted, {
		sessionId = sess.sessionId,
		waterPos = waterPos,
		biteDelay = biteDelay,
		inWhirlpool = inWhirlpool,
		castMode = castMode,
	})

	local capturedId = sess.sessionId
	task.delay(biteDelay, function()
		local current = FishingSessionManager.Get(player)
		if not current or current.sessionId ~= capturedId or not DataService.Get(player) then
			return
		end
		local forced = forcedRarityDev[player]
		forcedRarityDev[player] = nil

		local fish = FishingRoller.RollFishSpecies(forced, islandDef, candidates, current.snapMults, current.inWhirlpool)
		local mutName, _ = FishingRoller.RollMutation(current.snapMults.mutationMult, current.snapMults.midasSellBonus)
		current.rolledFish = fish
		current.rolledMutation = mutName

		if isAutoCatchRarity(fish.rarity) then
			RodVisuals.PlayBiteSplash(player, false)
			local closed = FishingSessionManager.CloseSessionOnce(player, capturedId, "Win", true)
			if closed then
				finalizeFishAward(player, closed)
			end
		else
			RodVisuals.PlayBiteSplash(player, true)
			FishingSessionManager.BeginMinigame(player, current, fish, mutName)
		end
	end)
end

function FishingService.Init()
	local function bindCharacter(player: Player, char: Model)
		task.spawn(function()
			task.wait(0.2)
			ShopAndItemsService.SyncCharacterHandVisuals(player)
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hum then
				hum.Died:Connect(function()
					FishingSessionManager.CloseSessionOnce(player, nil, "Died", false)
				end)
			end
		end)
	end

	DataService.OnProfileLoaded(function(player: Player)
		if player.Character then
			bindCharacter(player, player.Character)
		end
		player.CharacterAdded:Connect(function(char: Model)
			bindCharacter(player, char)
		end)
	end)

	ShopAndItemsService.OnHotbarSlotChanged(function(player: Player, slot: number)
		if slot ~= 1 then
			FishingSessionManager.CloseSessionOnce(player, nil, "Unequip", false)
		end
	end)

	Net.OnServerEvent(Net.ClientToServer.FishingCast, function(player: Player) FishingService.StartCast(player, nil) end)
	Net.OnServerEvent(Net.ClientToServer.FishingCastWithAim, function(player: Player, payload: any) FishingService.StartCast(player, payload) end)
	Net.OnServerEvent(Net.ClientToServer.FishingCancel, function(player: Player) FishingService.CancelSession(player, false) end)
	Net.OnServerEvent(Net.ClientToServer.FishingMinigameStrike, function(player: Player, sid: any, r: any, elapsed: any)
		FishingSessionManager.HandleStrike(player, sid, r, elapsed, finalizeFishAward)
	end)
	Net.OnServerEvent(Net.ClientToServer.SetAutoFish, function(player: Player, rawEnable: any)
		autoFishActive[player] = (rawEnable == true) -- Auto-Fish Free mo cho moi nguoi!
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		forcedRarityDev[player] = nil
		autoFishActive[player] = nil
	end)

	PetAndFishVisuals.InitFollowLoop()
end

return FishingService
