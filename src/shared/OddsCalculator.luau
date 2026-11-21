--!strict
-- OddsCalculator.luau: Tinh bang xac suat % Goc vs % Thuc Te (Re-normalized) dung chung cho Server & UI Minh Bach

local Types = require(script.Parent.Types)
local GameConfig = require(script.Parent.Config.GameConfig)
local RodsConfig = require(script.Parent.Config.RodsConfig)
local EnchantsConfig = require(script.Parent.Config.EnchantsConfig)
local BaitConfig = require(script.Parent.Config.BaitConfig)
local PotionsConfig = require(script.Parent.Config.PotionsConfig)
local PetsConfig = require(script.Parent.Config.PetsConfig)
local EventsConfig = require(script.Parent.Config.EventsConfig)
local IslandsRegistry = require(script.Parent.Config.Islands)

export type EnchantOddsEntry = {
	enchant: Types.EnchantDef,
	basePct: number,
	effectivePct: number,
}

export type FishOddsEntry = {
	fish: Types.FishDef,
	basePct: number,
	effectivePct: number,
}

local OddsCalculator = {}

function OddsCalculator.ComputeEnchantOdds(currentEnchantId: string?): { EnchantOddsEntry }
	local baseTotal = 0
	local effTotal = 0
	for _, e in ipairs(EnchantsConfig.List) do
		baseTotal += e.chance
		if e.id ~= currentEnchantId then
			effTotal += e.chance
		end
	end
	if effTotal <= 0 then
		effTotal = baseTotal
	end

	local out: { EnchantOddsEntry } = {}
	for _, e in ipairs(EnchantsConfig.List) do
		local bPct = (e.chance / math.max(0.0001, baseTotal)) * 100
		local ePct = if e.id == currentEnchantId and #EnchantsConfig.List > 1
			then 0
			else (e.chance / math.max(0.0001, effTotal)) * 100
		table.insert(out, {
			enchant = e,
			basePct = bPct,
			effectivePct = ePct,
		})
	end
	return out
end

function OddsCalculator.GetEligibleCandidates(islandDef: Types.IslandDef, power: number, maxWeight: number): { Types.FishDef }
	local eligible: { Types.FishDef } = {}
	for _, fish in ipairs(islandDef.fishPool) do
		if power >= fish.minRodPower and fish.minWeight <= maxWeight then table.insert(eligible, fish) end
	end
	return eligible
end

function OddsCalculator.GetFishWeight(fish: Types.FishDef, luck: number, bossMult: number, whirlpool: boolean): number
	local wp = if whirlpool then 2 else 1
	local effectiveLuck = luck * wp
	if fish.rarity == "Boss" then return fish.weightChance * bossMult * wp * (1 + 0.25 * math.max(0, effectiveLuck - 1)) end
	return fish.weightChance * (if (GameConfig.RarityOrder[fish.rarity] or 1) >= 3 then effectiveLuck else 1)
end

function OddsCalculator.ComputeFishOdds(
	islandDef: Types.IslandDef, effPower: number, effMaxWeight: number,
	luckMult: number, bossChanceMult: number, inWhirlpool: boolean
): { FishOddsEntry }
	local eligible = OddsCalculator.GetEligibleCandidates(islandDef, effPower, effMaxWeight)
	local allowed: { [string]: boolean } = {}
	local baseSum, effectiveSum = 0, 0
	for _, fish in ipairs(eligible) do
		allowed[fish.id] = true
		baseSum += fish.weightChance
		effectiveSum += OddsCalculator.GetFishWeight(fish, luckMult, bossChanceMult, inWhirlpool)
	end
	local out: { FishOddsEntry } = {}
	for _, fish in ipairs(islandDef.fishPool) do
		table.insert(out, {
			fish = fish,
			basePct = if allowed[fish.id] then fish.weightChance / math.max(0.0001, baseSum) * 100 else 0,
			effectivePct = if allowed[fish.id] then OddsCalculator.GetFishWeight(fish, luckMult, bossChanceMult, inWhirlpool) / math.max(0.0001, effectiveSum) * 100 else 0,
		})
	end
	return out
end

function OddsCalculator.ComputeEggOdds(egg: Types.EggDef): { { pet: Types.PetDef, pct: number } }
	local total = 0
	for _, pet in ipairs(egg.pets) do total += pet.weightChance end
	local out = {}
	for _, pet in ipairs(egg.pets) do table.insert(out, { pet = pet, pct = pet.weightChance / math.max(0.0001, total) * 100 }) end
	return out
end

function OddsCalculator.ComputeMutationSummary(mutationMult: number, midasActive: boolean): string
	local m = math.max(1.0, mutationMult)
	local cosmic = math.min(0.18, GameConfig.Mutations.Cosmic.chance * m)
	local golden = math.min(0.32, GameConfig.Mutations.Golden.chance * m)
	local shiny = math.min(0.45, GameConfig.Mutations.Shiny.chance * m)
	if midasActive then
		local nonGoldOrCosmic = math.max(0, 1.0 - cosmic - golden)
		golden += nonGoldOrCosmic * 0.20
		shiny = shiny * 0.80
	end
	return string.format("Shiny %.1f%% • Golden %.1f%% • Cosmic %.2f%%", shiny * 100, golden * 100, cosmic * 100)
end

local eventsById: { [string]: EventsConfig.ServerEventDef } = {}
for _, ev in ipairs(EventsConfig.List) do
	eventsById[ev.id] = ev
end

function OddsCalculator.ComputeLiveOdds(
	islandId: number,
	rodId: string,
	ownedRods: { [string]: boolean },
	rodEnchants: { [string]: string },
	activeBait: any,
	baitMap: any,
	activePotions: any,
	petsList: { any },
	equippedPetUids: { string },
	castLuckAdd: number,
	activeEventId: string?,
	nowSec: number
)
	local islDef = IslandsRegistry.Get(islandId)
	local effRod = RodsConfig.GetEffectiveStats(rodId, ownedRods, rodEnchants)
	local ench = if effRod.isExclusive and effRod.enchantId then EnchantsConfig.ById[effRod.enchantId] else nil

	local itemLuckAdd, itemMutAdd, bossMult = 0, 0, 1.0
	if type(activeBait) == "string" and activeBait ~= "" then
		local bDef = BaitConfig.ById[activeBait]
		local cnt = if type(baitMap) == "table" then (tonumber(baitMap[activeBait]) or 0) else 0
		if bDef and cnt > 0 then
			itemLuckAdd += bDef.luckBonus; bossMult *= bDef.bossChanceMult; itemMutAdd += bDef.mutationBonus
		end
	end
	if type(activePotions) == "table" then
		for _, st in pairs(activePotions) do
			if type(st) == "table" and (tonumber(st.expiresAt) or 0) > nowSec then
				local pDef = PotionsConfig.ById[tostring(st.potionId or "")]
				if pDef and pDef.kind == "Luck" then itemLuckAdd += pDef.bonus
				elseif pDef and pDef.kind == "Mutation" then itemMutAdd += pDef.bonus end
			end
		end
	end

	local petLuckAdd, petMutAdd = 0, 0
	local eqSet: { [string]: boolean } = {}
	for _, u in ipairs(equippedPetUids) do eqSet[tostring(u)] = true end
	for _, inst in ipairs(petsList) do
		if type(inst) == "table" and eqSet[tostring(inst.uid)] then
			local pDef = PetsConfig.PetsById[tostring(inst.petId)]
			if pDef then
				local eff = PetsConfig.GetEffectivePetStats(pDef, petsList)
				petLuckAdd += eff.luckBonus
				petMutAdd += eff.mutationBonus
			end
		end
	end

	local ev = if activeEventId then eventsById[activeEventId] else nil
	local evLuck = if ev then ev.luckAdd else 0
	local evMut = if ev then ev.mutationAdd else 0

	local luckMult = (1 + effRod.luckBonus + (if ench then ench.luckBonus else 0) + castLuckAdd) * (1 + itemLuckAdd) * (1 + petLuckAdd) * (1 + evLuck)
	local mutMult = (1 + (if ench then ench.mutationBonus else 0)) * (1 + itemMutAdd) * (1 + petMutAdd) * (1 + evMut)
	local midasActive = (ench ~= nil and ench.midasSellBonus > 1.01)

	local fishOdds = OddsCalculator.ComputeFishOdds(islDef, effRod.power, effRod.maxWeight, luckMult, bossMult, false)
	local wpOdds = OddsCalculator.ComputeFishOdds(islDef, effRod.power, effRod.maxWeight, luckMult, bossMult, true)
	return { fishOdds = fishOdds, wpOdds = wpOdds, mutationSummary = OddsCalculator.ComputeMutationSummary(mutMult, midasActive) }
end

function OddsCalculator.BuildHudLiveOddsSummary(
	islandId: number, rodId: string, ownedRods: { [string]: boolean }, rodEnchants: { [string]: string },
	activeBait: any, baitMap: any, activePotions: any, petsList: { any }, equippedPetUids: { string },
	castLuckAdd: number, activeEventId: string?, nowSec: number
): string
	local live = OddsCalculator.ComputeLiveOdds(islandId, rodId, ownedRods, rodEnchants, activeBait, baitMap, activePotions, petsList, equippedPetUids, castLuckAdd, activeEventId, nowSec)
	local fishOdds, wpOdds = live.fishOdds, live.wpOdds
	local baseRare, effRare, baseBoss, effBoss, wpBoss = 0, 0, 0, 0, 0
	for i, fo in ipairs(fishOdds) do
		local ord = GameConfig.RarityOrder[fo.fish.rarity] or 1
		if fo.fish.rarity == "Boss" then
			baseBoss += fo.basePct; effBoss += fo.effectivePct
			if wpOdds[i] then wpBoss += wpOdds[i].effectivePct end
		end
		if ord >= 3 then
			baseRare += fo.basePct; effRare += fo.effectivePct
		end
	end
	local mutTxt = live.mutationSummary
	return string.format(
		"📊 Odds (Base → Live): Rare+ %.1f%% → %.1f%% • Boss %.2f%% → %.2f%% (🌀 Whirlpool %.2f%%)  |  Mutations: %s",
		baseRare, effRare, baseBoss, effBoss, wpBoss, mutTxt
	)
end

return OddsCalculator
