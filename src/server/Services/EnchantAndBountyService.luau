--!strict
-- EnchantAndBountyService.luau: Xoay Enchant, Mo Khoa Exclusive (chan Trophy/Lock), Appraise (giu SizeTier + ceil 85%) & Bounty

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local RodsConfig = require(Shared:WaitForChild("Config"):WaitForChild("RodsConfig"))
local EnchantsConfig = require(Shared:WaitForChild("Config"):WaitForChild("EnchantsConfig"))
local BountiesConfig = require(Shared:WaitForChild("Config"):WaitForChild("BountiesConfig"))

local DataService = require(script.Parent.DataService)
local PerkService = require(script.Parent.PerkService)
local BuffAggregator = require(script.Parent.BuffAggregator)
local CurrencyService = require(script.Parent.CurrencyService)
local ShopAndItemsService = require(script.Parent.ShopAndItemsService)
local FishingRoller = require(script.Parent.FishingRoller)
local ProfileMigrator = require(script.Parent.ProfileMigrator)

local EnchantAndBountyService = {}

local WorldPromptAccess = require(script.Parent.WorldPromptAccess)

local function checkNearCollector(player: Player, islandId: number): boolean
 if WorldPromptAccess.IsNear(player, islandId, { NpcCollector = true }) then return true end
 Net.FireClient(player, Net.ServerToClient.Toast, { kind = "Info", text = "Walk up to Old Man Finn to Appraise or trade Bounties!" })
 return false
end

local function checkNearAltarOrCrafter(player: Player, islandId: number): boolean
 if WorldPromptAccess.IsNear(player, islandId, { NpcShop = true, OpenEnchantAltar = true }) then return true end
 Net.FireClient(player, Net.ServerToClient.Toast, { kind = "Info", text = "Stand near the Ancient Enchant Altar or Master Kaito to roll Enchants!" })
 return false
end

local function getSizeTierValueMult(tierName: string): number
	for _, st in ipairs(GameConfig.SizeTiers) do
		if st.name == tierName then
			return st.valueMult
		end
	end
	return 1.0
end

local function handleRollEnchant(player: Player, rodId: string, payWithGems: boolean)
	local profile = DataService.Get(player)
	local rodDef = RodsConfig.ById[rodId]
	if not profile or not rodDef or DataService.IsTransactionLocked(player, true) then
		return
	end
	if not checkNearAltarOrCrafter(player, profile.currentIsland) then
		return
	end
	if not rodDef.isExclusive or not profile.ownedRods[rodId] then
		Net.FireClient(player, Net.ServerToClient.Toast, { kind = "Error", text = "Only owned Exclusive Rods can be enchanted!" })
		return
	end

	if payWithGems then
		if PerkService.ArePaidRandomItemsRestricted(player) then
			local st = PerkService.GetPolicyState(player)
			local msg = if st == "Loading"
				then "Verifying regional policy — please wait 1 second and try again!"
				else "Regional policy restricts paid random Gem rolls — use Enchant Relics from Bounties!"
			Net.FireClient(player, Net.ServerToClient.Toast, { kind = "Error", text = msg })
			return
		end
		if not CurrencyService.SpendGems(player, EnchantsConfig.ROLL_GEM_COST) then
			Net.FireClient(player, Net.ServerToClient.Toast, { kind = "Error", text = string.format("Need %d Gems (or 1 Relic)!", EnchantsConfig.ROLL_GEM_COST) })
			return
		end
	else
		if profile.enchantRelics < EnchantsConfig.ROLL_REL_COST then
			Net.FireClient(player, Net.ServerToClient.Toast, { kind = "Error", text = "Need 1 Enchant Relic! Earn Relics from Fish Bounties or Playtime Gifts!" })
			return
		end
		profile.enchantRelics -= EnchantsConfig.ROLL_REL_COST
	end

	local rolled = EnchantsConfig.RollEnchant(profile.rodEnchants[rodId])
	profile.rodEnchants[rodId] = rolled.id
	DataService.MarkDirty(player)
	ShopAndItemsService.PushInventory(player)

	Net.FireClient(player, Net.ServerToClient.EnchantAndRelicsUpdated, {
		rodEnchants = profile.rodEnchants,
		enchantRelics = profile.enchantRelics,
		lastRolledEnchant = rolled.id,
	})
	Net.FireClient(player, Net.ServerToClient.Toast, { kind = "Epic", text = string.format("🔮 Rolled [%s] %s on %s!", rolled.rarity, rolled.name, rodDef.name) })
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
			Net.FireClient(player, Net.ServerToClient.Toast, { kind = "Error", text = string.format("Need %s Gems to unlock Void Reaper Rod!", Util.FormatNumber(BountiesConfig.VOID_SCYTHE_GEM_COST)) })
			return
		end
	elseif rodId == "RelicTrident" then
		if not checkNearCollector(player, profile.currentIsland) then
			return
		end
		if not profile.unlockedIslands[tostring(BountiesConfig.RELIC_TRIDENT_MIN_BOSS_ISLAND)] then
			Net.FireClient(player, Net.ServerToClient.Toast, { kind = "Error", text = "Unlock Island 3 (Mystic Swamp) in this cycle first!" })
			return
		end
		if type(bossFishUid) ~= "string" or bossFishUid == "" then
			Net.FireClient(player, Net.ServerToClient.Toast, { kind = "Info", text = "Select a specific unlocked Boss fish (Island 3+) to exchange!" })
			return
		end
		local foundIdx: number? = nil
		for idx, entry in ipairs(profile.fishBag) do
			if entry.uid == bossFishUid then
				if entry.soulbound or entry.locked then
					Net.FireClient(player, Net.ServerToClient.Toast, { kind = "Error", text = "🔒 Protected! Unlock a non-Trophy Boss fish to exchange for Relic Trident!" })
					return
				end
				local fDef = ProfileMigrator.GetFishDef(entry.fishId)
				if fDef and fDef.rarity == "Boss" and fDef.islandId >= BountiesConfig.RELIC_TRIDENT_MIN_BOSS_ISLAND then
					foundIdx = idx
				end
				break
			end
		end
		if not foundIdx then
			Net.FireClient(player, Net.ServerToClient.Toast, { kind = "Error", text = "Selected fish is no longer an eligible unlocked Island 3+ Boss!" })
			return
		end
		if not CurrencyService.SpendGems(player, BountiesConfig.RELIC_TRIDENT_GEM_COST) then
			Net.FireClient(player, Net.ServerToClient.Toast, { kind = "Error", text = "Need 800 Gems + 1 unlocked Boss Fish (Island 3+)!" })
			return
		end
		table.remove(profile.fishBag, foundIdx)
		CurrencyService.NotifyBagAndHotbarChanged(player, profile)
	else
		Net.FireClient(player, Net.ServerToClient.Toast, { kind = "Info", text = "Unlock Seraphim Sovereign Rod via the Gamepass!" })
		return
	end

	profile.ownedRods[rodId] = true
	profile.rodId = rodId
	profile.equippedHotbarSlot = 1
	DataService.MarkDirty(player)
	ShopAndItemsService.PushInventory(player)
	ShopAndItemsService.SyncCharacterHandVisuals(player)
	Net.FireAllClients(Net.ServerToClient.Toast, { kind = "Epic", text = string.format("⚡ %s unlocked the Exclusive %s!", player.DisplayName, rodDef.name) })
end

local function handleAppraiseFish(player: Player, targetUid: string?)
	local profile = DataService.Get(player)
	if not profile or DataService.IsTransactionLocked(player, true) or not checkNearCollector(player, profile.currentIsland) then
		return
	end

	local uid = targetUid
	if (not uid or uid == "") and profile.equippedHotbarSlot >= 2 and profile.equippedHotbarSlot <= 5 then
		uid = profile.pinnedFishUids[tostring(profile.equippedHotbarSlot)]
	end
	if not uid or uid == "" then
		Net.FireClient(player, Net.ServerToClient.Toast, { kind = "Info", text = "Hold a fish in your hands (Hotbar 2–5) to Appraise!" })
		return
	end

	local entry: Types.CaughtFish? = nil
	for _, f in ipairs(profile.fishBag) do
		if f.uid == uid then entry = f; break end
	end
	local fishDef = if entry then ProfileMigrator.GetFishDef(entry.fishId) else nil
	if not entry or not fishDef then return end

	local cost = math.max(100, math.floor(fishDef.baseValue * 0.35))
	if not CurrencyService.SpendGold(player, cost) then
		Net.FireClient(player, Net.ServerToClient.Toast, { kind = "Error", text = string.format("Need %s Gold to Appraise %s!", Util.FormatNumber(cost), fishDef.name) })
		return
	end

	local effRod = RodsConfig.GetEffectiveStats(profile.rodId, profile.ownedRods, profile.rodEnchants)
	local mults = BuffAggregator.GetMultipliers(player)
	local rolledTier, rolledW, _ = FishingRoller.RollSizeTierAndWeight(fishDef, effRod.maxWeight, mults.titanWeightFactor)

	-- San can nang >= 85% lam tron len 0.1kg & KHONG BAO GIO ha bac SizeTier (tranh ca Titanic bi teo nho!)
	local floorKg = math.ceil(entry.weight * 0.85 * 10 - 1e-6) / 10
	local newWeight = math.max(floorKg, rolledW)
	local oldTierRank = GameConfig.SizeTierRank[entry.sizeTier] or 1
	local rolledTierRank = GameConfig.SizeTierRank[rolledTier] or 1
	local finalTier = if rolledTierRank > oldTierRank then rolledTier else entry.sizeTier
	local finalTierMult = getSizeTierValueMult(finalTier)

	local rolledMut, _ = FishingRoller.RollMutation(mults.mutationMult, 1.0)
	local finalMut = if (GameConfig.MutationRank[rolledMut] or 1) > (GameConfig.MutationRank[entry.mutation] or 1) then rolledMut else entry.mutation
	local mutMult = FishingRoller.GetMutationMultiplier(finalMut)

	local avgWeight = (fishDef.minWeight + fishDef.maxWeight) * 0.5
	local weightFactor = math.clamp(newWeight / math.max(0.1, avgWeight), 0.75, 1.65)
	local midas = tonumber(entry.midasBonus) or 1.0
	local recalcValue = math.max(1, math.floor(fishDef.baseValue * weightFactor * finalTierMult * mutMult * midas + 0.5))

	entry.sizeTier = finalTier
	entry.weight = newWeight
	entry.mutation = finalMut
	entry.originalValue = recalcValue
	entry.sellValue = if entry.soulbound then 0 else recalcValue

	local recordUpdated = false
	if newWeight > (profile.indexFish[fishDef.id] or 0) then
		profile.indexFish[fishDef.id] = newWeight
		recordUpdated = true
	end

	DataService.MarkDirty(player)
	CurrencyService.NotifyBagAndHotbarChanged(player, profile)
	Net.FireClient(player, Net.ServerToClient.AppraiseResult, {
		fish = entry,
		indexFish = if recordUpdated then profile.indexFish else nil,
	})
	Net.FireClient(player, Net.ServerToClient.Toast, {
		kind = "Success",
		text = string.format("⚖️ Appraised: [%s] %s %s (%s)!", finalMut, finalTier, fishDef.name, Util.FormatWeight(newWeight)),
	})
end

local function handleTurnInBounty(player: Player, bountyId: string, fishUid: string)
	local profile = DataService.Get(player)
	local bDef = BountiesConfig.ById[bountyId]
	if not profile or not bDef or DataService.IsTransactionLocked(player, true) or not checkNearCollector(player, profile.currentIsland) then
		return
	end
	if not profile.unlockedIslands[tostring(bDef.islandReq)] then
		Net.FireClient(player, Net.ServerToClient.Toast, { kind = "Error", text = string.format("Unlock Island %d in this Rebirth cycle first!", bDef.islandReq) })
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
		Net.FireClient(player, Net.ServerToClient.Toast, { kind = "Error", text = "Selected fish no longer meets this Bounty requirement!" })
		return
	end

	table.remove(profile.fishBag, foundIdx)
	profile.enchantRelics += bDef.relicReward
	CurrencyService.AddGems(player, bDef.gemReward, true)
	if bDef.potionReward then
		ShopAndItemsService.GrantPotion(player, bDef.potionReward, 1, false)
	end

	DataService.MarkDirty(player)
	ShopAndItemsService.PushInventory(player)
	CurrencyService.NotifyBagAndHotbarChanged(player, profile)
	Net.FireClient(player, Net.ServerToClient.Toast, { kind = "Success", text = string.format("📜 Bounty Complete: +%d Gems & +%d Enchant Relic!", bDef.gemReward, bDef.relicReward) })
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
