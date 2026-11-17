--!strict
-- FishingService.luau: He thong Cau ca Server-Authoritative (Ca thuong tu giat len, Ca Hiem/Boss bat Minigame)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local RodsConfig = require(Shared:WaitForChild("Config"):WaitForChild("RodsConfig"))
local IslandsRegistry = require(Shared:WaitForChild("Config"):WaitForChild("Islands"))

local DataService = require(script.Parent.DataService)
local PerkService = require(script.Parent.PerkService)
local BuffAggregator = require(script.Parent.BuffAggregator)
local CurrencyService = require(script.Parent.CurrencyService)
local ShopAndItemsService = require(script.Parent.ShopAndItemsService)
local FishingRoller = require(script.Parent.FishingRoller)

local RodVisuals = require(script.Parent.Parent.World.RodVisuals)
local PetAndFishVisuals = require(script.Parent.Parent.World.PetAndFishVisuals)

type CastSession = {
	sessionId: string,
	state: "Waiting" | "Minigame",
	islandId: number,
	waterPos: Vector3,
	rolledFish: Types.FishDef?,
	rolledMutation: Types.MutationName,
	expiresAt: number,
}

local FishingService = {}

local sessions: { [Player]: CastSession } = {}
local forcedRarityDev: { [Player]: string } = {}
local autoFishActive: { [Player]: boolean } = {}
local catchRewardHooks: { (Player, Types.FishDef, Types.MutationName) -> () } = {}
local consumeBaitHook: ((Player, Types.PlayerProfile) -> ())? = nil

function FishingService.OnFishCaught(callback: (Player, Types.FishDef, Types.MutationName) -> ())
	table.insert(catchRewardHooks, callback)
end

function FishingService.SetConsumeBaitHook(hook: (Player, Types.PlayerProfile) -> ())
	consumeBaitHook = hook
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

local function finalizeFishAward(
	player: Player,
	fishDef: Types.FishDef,
	mutation: Types.MutationName,
	waterPos: Vector3
)
	local profile = DataService.Get(player)
	if not profile then
		return
	end

	local mutMult = FishingRoller.GetMutationMultiplier(mutation)
	local weightAlpha = math.random()
	local weight = math.floor((fishDef.minWeight + (fishDef.maxWeight - fishDef.minWeight) * weightAlpha) * 10 + 0.5) / 10
	local avgWeight = (fishDef.minWeight + fishDef.maxWeight) * 0.5
	local weightFactor = math.clamp(weight / math.max(0.1, avgWeight), 0.75, 1.55)
	local sellValue = math.max(1, math.floor(fishDef.baseValue * weightFactor * mutMult + 0.5))

	local entry: Types.CaughtFish = {
		uid = Util.NewUid(),
		fishId = fishDef.id,
		weight = weight,
		mutation = mutation,
		sellValue = sellValue,
	}
	table.insert(profile.fishBag, entry)

	profile.stats.fishCaught += 1
	if (GameConfig.RarityOrder[fishDef.rarity] or 1) >= 3 then
		profile.stats.rareCaught += 1
	end
	if fishDef.rarity == "Boss" then
		profile.stats.bossCaught += 1
	end
	if mutation ~= "None" then
		profile.stats.mutationsCaught += 1
	end

	local prevBest = profile.indexFish[fishDef.id] or 0
	if weight > prevBest then
		profile.indexFish[fishDef.id] = weight
	end

	if consumeBaitHook then
		consumeBaitHook(player, profile)
	end

	local gainedStr = CurrencyService.AddStrength(player, fishDef.strengthReward, true, false)
	DataService.MarkDirty(player)

	PetAndFishVisuals.SpawnCaughtFishLeap(player, waterPos, fishDef, mutation)
	RodVisuals.ClearBobber(player)

	Net.FireClient(player, Net.ServerToClient.BagUpdated, {
		fishBag = profile.fishBag,
	})
	Net.FireClient(player, Net.ServerToClient.FishingCatchResult, {
		success = true,
		fishId = fishDef.id,
		fishName = fishDef.name,
		rarity = fishDef.rarity,
		weight = weight,
		mutation = mutation,
		sellValue = sellValue,
		strengthGained = gainedStr,
		bagCount = #profile.fishBag,
		bagCap = GameConfig.BAG_CAPACITY,
	})

	local prefix = if (mutation :: string) ~= "None" then (mutation .. " ") else ""
	if fishDef.rarity == "Boss" or fishDef.rarity == "Legendary" or mutation == "Cosmic" then
		Net.FireAllClients(Net.ServerToClient.Toast, {
			kind = "Epic",
			text = string.format("🔥 %s caught a %s%s (%s)!", player.DisplayName, prefix, fishDef.name, Util.FormatWeight(weight)),
		})
	end

	for _, cb in ipairs(catchRewardHooks) do
		task.spawn(cb, player, fishDef, mutation)
	end
end

function FishingService.CancelSession(player: Player, silent: boolean?)
	sessions[player] = nil
	RodVisuals.ClearBobber(player)
	if not silent then
		Net.FireClient(player, Net.ServerToClient.FishingStateReset, {})
	end
end

function FishingService.StartCast(player: Player)
	local profile = DataService.Get(player)
	if not profile or sessions[player] ~= nil then
		return
	end

	if #profile.fishBag >= GameConfig.BAG_CAPACITY then
		Net.FireClient(player, Net.ServerToClient.Toast, {
			kind = "Error",
			text = "Fish Bag is full! Visit the Fish Market to Sell All!",
		})
		Net.FireClient(player, Net.ServerToClient.FishingStateReset, { bagFull = true })
		return
	end

	local islandId = profile.currentIsland
	local waterPos = FishingRoller.FindWaterCastPoint(player, islandId)
	if not waterPos then
		Net.FireClient(player, Net.ServerToClient.Toast, {
			kind = "Info",
			text = "Walk closer to the Fishing Pier or Ocean Water to cast!",
		})
		Net.FireClient(player, Net.ServerToClient.FishingStateReset, { tooFar = true })
		return
	end

	local sessionId = Util.NewUid()
	local mults = BuffAggregator.GetMultipliers(player)
	local rawWait = GameConfig.BASE_BITE_MIN_SEC
		+ math.random() * (GameConfig.BASE_BITE_MAX_SEC - GameConfig.BASE_BITE_MIN_SEC)
	local biteDelay = math.max(0.65, rawWait / math.max(1, mults.biteSpeedMult))

	sessions[player] = {
		sessionId = sessionId,
		state = "Waiting",
		islandId = islandId,
		waterPos = waterPos,
		rolledFish = nil,
		rolledMutation = "None",
		expiresAt = os.clock() + biteDelay + 20,
	}

	RodVisuals.SpawnCastBobber(player, waterPos)
	Net.FireClient(player, Net.ServerToClient.FishingCastStarted, {
		sessionId = sessionId,
		waterPos = waterPos,
		biteDelay = biteDelay,
	})

	task.delay(biteDelay, function()
		local current = sessions[player]
		if not current or current.sessionId ~= sessionId then
			return
		end
		local latestProfile = DataService.Get(player)
		if not latestProfile then
			FishingService.CancelSession(player, true)
			return
		end

		local latestMults = BuffAggregator.GetMultipliers(player)
		local rod = RodsConfig.Get(latestProfile.rodId)
		local islandDef = IslandsRegistry.Get(current.islandId)
		local forced = forcedRarityDev[player]
		forcedRarityDev[player] = nil
		local fish = FishingRoller.RollFishSpecies(forced, islandDef, rod.power, latestMults)
		local rawMut, _ = FishingRoller.RollMutation(latestMults.mutationMult)
		local mutName = (rawMut :: any) :: Types.MutationName

		current.rolledFish = fish
		current.rolledMutation = mutName

		if isAutoCatchRarity(fish.rarity) then
			RodVisuals.PlayBiteSplash(player, false)
			sessions[player] = nil
			finalizeFishAward(player, fish, mutName, current.waterPos)
		else
			RodVisuals.PlayBiteSplash(player, true)
			current.state = "Minigame"
			local rounds = if fish.rarity == "Boss"
				then 3
				elseif fish.rarity == "Legendary" or fish.rarity == "Epic" then 2
				else 1
			local baseZone = if fish.rarity == "Boss" then 0.22 else 0.28
			local zoneWidth = math.clamp(baseZone + latestMults.minigameWidthBonus, 0.20, 0.56)
			local speed = if fish.rarity == "Boss" then 1.45 elseif fish.rarity == "Legendary" then 1.25 else 1.05
			current.expiresAt = os.clock() + 18

			Net.FireClient(player, Net.ServerToClient.FishingMinigamePrompt, {
				sessionId = sessionId,
				fishName = fish.name,
				rarity = fish.rarity,
				mutation = mutName,
				rounds = rounds,
				zoneWidth = zoneWidth,
				speed = speed,
			})
		end
	end)
end

function FishingService.Init()
	local function setupCharacterRod(player: Player, _char: Model)
		task.wait(0.2)
		local p = DataService.Get(player)
		if p then
			RodVisuals.EquipRodOnCharacter(player, p.rodId)
		end
	end

	DataService.OnProfileLoaded(function(player: Player, profile: Types.PlayerProfile)
		if player.Character then
			RodVisuals.EquipRodOnCharacter(player, profile.rodId)
		end
		player.CharacterAdded:Connect(function(char: Model)
			setupCharacterRod(player, char)
		end)
	end)

	ShopAndItemsService.OnRodChanged(function(player: Player, rodId: string)
		RodVisuals.EquipRodOnCharacter(player, rodId)
	end)

	Net.OnServerEvent(Net.ClientToServer.FishingCast, function(player: Player)
		FishingService.StartCast(player)
	end)

	Net.OnServerEvent(Net.ClientToServer.FishingCancel, function(player: Player)
		FishingService.CancelSession(player, false)
	end)

	Net.OnServerEvent(Net.ClientToServer.FishingMinigameResult, function(player: Player, rawSessionId: any, rawSuccess: any)
		local sess = sessions[player]
		if not sess or sess.state ~= "Minigame" or type(rawSessionId) ~= "string" or sess.sessionId ~= rawSessionId then
			return
		end
		sessions[player] = nil
		if os.clock() > sess.expiresAt or rawSuccess ~= true or not sess.rolledFish then
			RodVisuals.ClearBobber(player)
			Net.FireClient(player, Net.ServerToClient.FishingCatchResult, { success = false })
			Net.FireClient(player, Net.ServerToClient.Toast, {
				kind = "Error",
				text = "The rare fish slipped off the hook! Train Strength for a wider catch bar!",
			})
			return
		end
		finalizeFishAward(player, sess.rolledFish, sess.rolledMutation, sess.waterPos)
	end)

	Net.OnServerEvent(Net.ClientToServer.SetAutoFish, function(player: Player, rawEnable: any)
		local want = (rawEnable == true)
		if want and not PerkService.HasGamepass(player, "AutoFish") then
			autoFishActive[player] = false
			Net.FireClient(player, Net.ServerToClient.Toast, {
				kind = "Info",
				text = "Auto-Fish requires the Auto-Fish Gamepass!",
			})
			PerkService.PushPerks(player)
			return
		end
		autoFishActive[player] = want
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		sessions[player] = nil
		forcedRarityDev[player] = nil
		autoFishActive[player] = nil
	end)

	PetAndFishVisuals.InitFollowLoop()
end

return FishingService
