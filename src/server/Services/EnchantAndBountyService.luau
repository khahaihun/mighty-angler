--!strict
-- EnchantAndBountyService.luau: Xoay Dong Phu Phep (3 Exclusive Rods), Mo Khoa Exclusive, Appraise Ca & Nop Fish Bounty

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local RodsConfig = require(Shared:WaitForChild("Config"):WaitForChild("RodsConfig"))
local EnchantsConfig = require(Shared:WaitForChild("Config"):WaitForChild("EnchantsConfig"))
local BountiesConfig = require(Shared:WaitForChild("Config"):WaitForChild("BountiesConfig"))
local IslandsRegistry = require(Shared:WaitForChild("Config"):WaitForChild("Islands"))

local DataService = require(script.Parent.DataService)
local PerkService = require(script.Parent.PerkService)
local BuffAggregator = require(script.Parent.BuffAggregator)
local CurrencyService = require(script.Parent.CurrencyService)
local ShopAndItemsService = require(script.Parent.ShopAndItemsService)
local FishingRoller = require(script.Parent.FishingRoller)
local ProfileMigrator = require(script.Parent.ProfileMigrator)

local EnchantAndBountyService = {}

local function isNearIslandCenterOrCollector(player: Player, islandId: number): boolean
	local char = player.Character
	local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
	local islDef = IslandsRegistry.ById[islandId]
	if not (root and root:IsA("BasePart")) or not islDef then
		return false
	end
	return (root.Position - islDef.centerPosition).Magnitude <= 145
end

local function handleRollEnchant(player: Player, rodId: string, payWithGems: boolean)
	local profile = DataService.Get(player)
	local rodDef = RodsConfig.ById[rodId]
	if not profile or not rodDef or DataService.IsTransactionLocked(player, true) then
		return
	end
	if not rodDef.isExclusive or not profile.ownedRods[rodId] then
		Net.FireClient(player, Net.ServerToClient.Toast, {
			kind = "Error",
			text = "Only owned Exclusive Rods can be enchanted at the Ancient Altar!",
		})
		return
	end

	if payWithGems then
		if PerkService.ArePaidRandomItemsRestricted(player) then
			Net.FireClient(player, Net.ServerToClient.Toast, {
				kind = "Error",
				text = "Regional policy restricts paid random Gem rolls — use Enchant Relics earned from Bounties!",
			})
			return
		end
		if not CurrencyService.SpendGems(player, EnchantsConfig.ROLL_GEM_COST) then
			Net.FireClient(player, Net.ServerToClient.Toast, {
				kind = "Error",
				text = string.format("Need %d Gems (or 1 Enchant Relic) to roll an Enchant!", EnchantsConfig.ROLL_GEM_COST),
			})
			return
		end
	else
		if profile.enchantRelics < EnchantsConfig.ROLL_REL_COST then
			Net.FireClient(player, Net.ServerToClient.Toast, {
				kind = "Error",
				text = "You need 1 Enchant Relic! Earn Relics from Fish Bounties or Playtime Gifts!",
			})
			return
		end
		profile.enchantRelics -= EnchantsConfig.ROLL_REL_COST
	end

	local prevEnchant = profile.rodEnchants[rodId]
	local rolled = EnchantsConfig.RollEnchant(prevEnchant)
	profile.rodEnchants[rodId] = rolled.id
	DataService.MarkDirty(player)
	ShopAndItemsService.PushInventory(player)

	Net.FireClient(player, Net.ServerToClient.EnchantAndRelicsUpdated, {
		rodEnchants = profile.rodEnchants,
		enchantRelics = profile.enchantRelics,
		lastRolledEnchant = rolled.id,
	})
	Net.FireClient(player, Net.ServerToClient.Toast, {
		kind = "Epic",
		text = string.format("🔮 Rolled [%s] %s on %s!", rolled.rarity, rolled.name, rodDef.name),
	})
end

local function handleUnlockExclusiveRod(player: Player, rodId: string, bossFishUid: string?)
	local profile = DataService.Get(player)
	local rodDef = RodsConfig.ById[rodId]
	if not profile or not rodDef or not rodDef.isExclusive or DataService.IsTransactionLocked(player, true) then
		return
	end
	if profile.ownedRods[rodId] then
		ShopAndItemsService.HandleEquipRod(player, rodId)
		return
	end

	if rodId == "VoidScythe" then
		if not CurrencyService.SpendGems(player, BountiesConfig.VOID_SCYTHE_GEM_COST) then
			Net.FireClient(player, Net.ServerToClient.Toast, {
				kind = "Error",
				text = string.format("Need %s Gems to unlock Void Reaper Rod!", Util.FormatNumber(BountiesConfig.VOID_SCYTHE_GEM_COST)),
			})
			return
		end
	elseif rodId == "RelicTrident" then
		if not profile.unlockedIslands[tostring(BountiesConfig.RELIC_TRIDENT_MIN_BOSS_ISLAND)] then
			Net.FireClient(player, Net.ServerToClient.Toast, {
				kind = "Error",
				text = "Unlock Island 3 (Mystic Swamp) first to exchange for Abyssal Relic Trident!",
			})
			return
		end
		local foundIdx: number? = nil
		for idx, entry in ipairs(profile.fishBag) do
			if bossFishUid == nil or entry.uid == bossFishUid then
				local fDef = ProfileMigrator.GetFishDef(entry.fishId)
				if fDef and fDef.rarity == "Boss" and fDef.islandId >= BountiesConfig.RELIC_TRIDENT_MIN_BOSS_ISLAND then
					foundIdx = idx
					break
				end
			end
		end
		if not foundIdx then
			Net.FireClient(player, Net.ServerToClient.Toast, {
				kind = "Error",
				text = "Need 1 Boss Fish from Island 3+ in your Bag (plus 800 Gems)!",
			})
			return
		end
		if not CurrencyService.SpendGems(player, BountiesConfig.RELIC_TRIDENT_GEM_COST) then
			Net.FireClient(player, Net.ServerToClient.Toast, {
				kind = "Error",
				text = "Need 800 Gems + 1 Boss Fish (Island 3+) for Abyssal Relic Trident!",
			})
			return
		end
		table.remove(profile.fishBag, foundIdx)
		CurrencyService.NotifyBagAndHotbarChanged(player, profile)
	elseif rodId == "SeraphimDragon" then
		Net.FireClient(player, Net.ServerToClient.Toast, {
			kind = "Info",
			text = "Unlock Seraphim Sovereign Rod via the Seraphim Dragon Rod Gamepass!",
		})
		return
	else
		return
	end

	profile.ownedRods[rodId] = true
	profile.rodId = rodId
	profile.equippedHotbarSlot = 1
	DataService.MarkDirty(player)
	ShopAndItemsService.PushInventory(player)
	ShopAndItemsService.SyncCharacterHandVisuals(player)

	Net.FireAllClients(Net.ServerToClient.Toast, {
		kind = "Epic",
		text = string.format("⚡ %s unlocked the Exclusive %s!", player.DisplayName, rodDef.name),
	})
end

local function handleAppraiseFish(player: Player, targetUid: string?)
	local profile = DataService.Get(player)
	if not profile or DataService.IsTransactionLocked(player, true) then
		return
	end
	if not isNearIslandCenterOrCollector(player, profile.currentIsland) then
		Net.FireClient(player, Net.ServerToClient.Toast, { kind = "Error", text = "Stand near Old Man Finn on the island to Appraise!" })
		return
	end

	local uid = targetUid
	if (not uid or uid == "") and profile.equippedHotbarSlot >= 2 and profile.equippedHotbarSlot <= 5 then
		uid = profile.pinnedFishUids[tostring(profile.equippedHotbarSlot)]
	end
	if not uid or uid == "" then
		Net.FireClient(player, Net.ServerToClient.Toast, {
			kind = "Info",
			text = "Hold a fish in your hands (Hotbar 2–5) or select one to Appraise!",
		})
		return
	end

	local entry: Types.CaughtFish? = nil
	for _, f in ipairs(profile.fishBag) do
		if f.uid == uid then
			entry = f
			break
		end
	end
	local fishDef = if entry then ProfileMigrator.GetFishDef(entry.fishId) else nil
	if not entry or not fishDef then
		return
	end

	local cost = math.max(100, math.floor(fishDef.baseValue * 0.35))
	if not CurrencyService.SpendGold(player, cost) then
		Net.FireClient(player, Net.ServerToClient.Toast, {
			kind = "Error",
			text = string.format("Need %s Gold to Appraise %s!", Util.FormatNumber(cost), fishDef.name),
		})
		return
	end

	local effRod = RodsConfig.GetEffectiveStats(profile.rodId, profile.ownedRods, profile.rodEnchants)
	local mults = BuffAggregator.GetMultipliers(player)
	local newTier, rolledW, tierValMult = FishingRoller.RollSizeTierAndWeight(fishDef, effRod.maxWeight, mults.titanWeightFactor)
	local newWeight = math.max(math.floor(entry.weight * 0.85 * 10 + 0.5) / 10, rolledW)

	local rolledMut, _ = FishingRoller.RollMutation(mults.mutationMult, 1.0)
	local curRank = GameConfig.MutationRank[entry.mutation] or 1
	local newRank = GameConfig.MutationRank[rolledMut] or 1
	local finalMut = if newRank > curRank then rolledMut else entry.mutation
	local mutMult = FishingRoller.GetMutationMultiplier(finalMut)

	local avgWeight = (fishDef.minWeight + fishDef.maxWeight) * 0.5
	local weightFactor = math.clamp(newWeight / math.max(0.1, avgWeight), 0.75, 1.65)
	local midas = tonumber(entry.midasBonus) or 1.0
	local recalcValue = math.max(1, math.floor(fishDef.baseValue * weightFactor * tierValMult * mutMult * midas + 0.5))

	entry.sizeTier = newTier
	entry.weight = newWeight
	entry.mutation = finalMut
	entry.originalValue = recalcValue
	-- Giu nguyen co soulbound == true va sellValue == 0 neu day la Soulbound Trophy!
	entry.sellValue = if entry.soulbound then 0 else recalcValue

	if newWeight > (profile.indexFish[fishDef.id] or 0) then
		profile.indexFish[fishDef.id] = newWeight
	end

	DataService.MarkDirty(player)
	CurrencyService.NotifyBagAndHotbarChanged(player, profile)
	Net.FireClient(player, Net.ServerToClient.AppraiseResult, { fish = entry })
	Net.FireClient(player, Net.ServerToClient.Toast, {
		kind = "Success",
		text = string.format("⚖️ Appraised: [%s] %s %s (%s)!", finalMut, newTier, fishDef.name, Util.FormatWeight(newWeight)),
	})
end

local function handleTurnInBounty(player: Player, bountyId: string, fishUid: string)
	local profile = DataService.Get(player)
	local bDef = BountiesConfig.ById[bountyId]
	if not profile or not bDef or DataService.IsTransactionLocked(player, true) then
		return
	end
	if not profile.unlockedIslands[tostring(bDef.islandReq)] then
		Net.FireClient(player, Net.ServerToClient.Toast, {
			kind = "Error",
			text = string.format("Unlock Island %d in this Rebirth cycle first!", bDef.islandReq),
		})
		return
	end

	local foundIdx: number? = nil
	for idx, entry in ipairs(profile.fishBag) do
		if entry.uid == fishUid then
			local fDef = ProfileMigrator.GetFishDef(entry.fishId)
			if fDef then
				local rOrder = GameConfig.RarityOrder[fDef.rarity] or 1
				local reqOrder = GameConfig.RarityOrder[bDef.rarityReq] or 1
				local mutOk = (bDef.mutationReq == nil) or (bDef.mutationReq == "AnyMutated" and entry.mutation ~= "None") or (entry.mutation == bDef.mutationReq)
				if rOrder >= reqOrder and entry.weight >= bDef.minWeight and mutOk then
					foundIdx = idx
				end
			end
			break
		end
	end
	if not foundIdx then
		Net.FireClient(player, Net.ServerToClient.Toast, {
			kind = "Error",
			text = "Selected fish does not meet this Bounty's Rarity, Weight, or Mutation requirement!",
		})
		return
	end

	-- Tieu thu nguyen tu dung 1 lan TRƯỚC KHI cong thuong (cho phep nop ca Soulbound Trophy!)
	table.remove(profile.fishBag, foundIdx)
	profile.enchantRelics += bDef.relicReward
	CurrencyService.AddGems(player, bDef.gemReward, true)
	if bDef.potionReward then
		ShopAndItemsService.GrantPotion(player, bDef.potionReward, 1, false)
	end

	DataService.MarkDirty(player)
	ShopAndItemsService.PushInventory(player)
	CurrencyService.NotifyBagAndHotbarChanged(player, profile)
	Net.FireClient(player, Net.ServerToClient.Toast, {
		kind = "Success",
		text = string.format("📜 Bounty Complete: +%d Gems & +%d Enchant Relic!", bDef.gemReward, bDef.relicReward),
	})
end

function EnchantAndBountyService.Init()
	Net.OnServerEvent(Net.ClientToServer.RollEnchant, function(p: Player, rId: any, useGems: any)
		if type(rId) == "string" then handleRollEnchant(p, rId, useGems == true) end
	end)
	Net.OnServerEvent(Net.ClientToServer.UnlockExclusiveRod, function(p: Player, rId: any, fUid: any)
		if type(rId) == "string" then handleUnlockExclusiveRod(p, rId, if type(fUid) == "string" then fUid else nil) end
	end)
	Net.OnServerEvent(Net.ClientToServer.AppraiseFish, function(p: Player, fUid: any)
		handleAppraiseFish(p, if type(fUid) == "string" then fUid else nil)
	end)
	Net.OnServerEvent(Net.ClientToServer.TurnInBounty, function(p: Player, bId: any, fUid: any)
		if type(bId) == "string" and type(fUid) == "string" then handleTurnInBounty(p, bId, fUid) end
	end)
end

return EnchantAndBountyService
