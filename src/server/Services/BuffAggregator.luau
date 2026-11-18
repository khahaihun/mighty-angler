--!strict
-- BuffAggregator.luau: Noi DUY NHAT gop toan bo he so nhan (5-Stat Rod, Exclusive Scaling, Enchant, Cast, Pet, Potion, Bait, Event)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local RodsConfig = require(Shared:WaitForChild("Config"):WaitForChild("RodsConfig"))
local EnchantsConfig = require(Shared:WaitForChild("Config"):WaitForChild("EnchantsConfig"))

local DataService = require(script.Parent.DataService)
local PerkService = require(script.Parent.PerkService)

export type BonusContribution = {
	luckAdd: number?,
	bossChanceMult: number?,
	sellAdd: number?,
	strengthAdd: number?,
	mutationAdd: number?,
	biteSpeedAdd: number?,
}

local BuffAggregator = {}

local externalProviders: { (Player, Types.PlayerProfile) -> BonusContribution } = {}
local evaluatingPlayers: { [Player]: boolean } = {}

function BuffAggregator.RegisterProvider(provider: (Player, Types.PlayerProfile) -> BonusContribution)
	table.insert(externalProviders, provider)
end

function BuffAggregator.GetMaxEquippedPets(player: Player): number
	return GameConfig.BASE_PET_EQUIP_SLOTS
		+ (if PerkService.HasGamepass(player, "ExtraPets") then GameConfig.BONUS_PET_EQUIP_SLOTS else 0)
end

function BuffAggregator.ComputeStrengthMastery(strength: number, masteryBaseline: number): number
	local baseline = math.max(masteryBaseline, 300)
	local ratio = strength / baseline
	if ratio <= 0 then
		return 0
	end
	return math.clamp(math.log10(1 + ratio) / 2.0, 0, 1)
end

function BuffAggregator.GetMultipliers(
	player: Player,
	castLuckAdd: number?,
	castLureAdd: number?
): Types.AggregatedMultipliers
	local profile = DataService.Get(player)
	if not profile then
		return {
			luckMult = 1,
			bossChanceMult = 1,
			sellMult = 1,
			strengthMult = 1,
			mutationMult = 1,
			biteSpeedMult = 1,
			minigameWidthBonus = 0,
			minigameSpeedDivisor = 1,
			titanWeightFactor = 1,
			midasSellBonus = 1,
			maxEquippedPets = GameConfig.BASE_PET_EQUIP_SLOTS,
		}
	end

	local effRod = RodsConfig.GetEffectiveStats(profile.rodId, profile.ownedRods, profile.rodEnchants)
	local enchant = if effRod.isExclusive and effRod.enchantId then EnchantsConfig.ById[effRod.enchantId] else nil

	local enchantLuck = if enchant then enchant.luckBonus else 0
	local enchantLure = if enchant then enchant.lureBonus else 0
	local enchantCtrl = if enchant then enchant.controlBonus else 0
	local enchantStead = if enchant then enchant.steadinessBonus else 0
	local enchantMut = if enchant then enchant.mutationBonus else 0
	local titanWeightFactor = if enchant then enchant.titanWeightFactor else 1.0
	local midasSellBonus = if enchant then enchant.midasSellBonus else 1.0

	local mastery = BuffAggregator.ComputeStrengthMastery(profile.strength, effRod.masteryBaselineStrength)
	local strengthBiteBonus = mastery * GameConfig.STRENGTH_MAX_SPEED_BONUS
	local strengthWidthBonus = mastery * GameConfig.STRENGTH_MAX_BAR_BONUS

	local rebirthMult = 1 + (0.5 * profile.rebirths)
	local gpGoldMult = if PerkService.HasGamepass(player, "DoubleGold") then 2.0 else 1.0
	local gpStrMult = if PerkService.HasGamepass(player, "DoubleStrength") then 2.0 else 1.0
	local maxPets = BuffAggregator.GetMaxEquippedPets(player)

	-- Theo dung cong thuc 2.2(1):
	-- luckMult = (1 + rodLuck + enchantLuck + castLuckAdd) * (1 + baitLuck + potionLuck) * (1 + petLuck) * (1 + eventLuck)
	-- biteSpeedMult = (1 + rodLureSpeed + enchantLure + castLureAdd + strengthSpeedBonus) * (1 + potionSpeed) * (1 + eventSpeed)
	local luckFactor = 1 + effRod.luckBonus + enchantLuck + (castLuckAdd or 0)
	local bossMult = 1.0
	local sellFactor = 1.0
	local strengthFactor = 1.0
	local mutationFactor = 1 + enchantMut
	local biteSpeedFactor = 1 + effRod.lureSpeed + enchantLure + (castLureAdd or 0) + strengthBiteBonus

	if not evaluatingPlayers[player] then
		evaluatingPlayers[player] = true
		for _, provider in ipairs(externalProviders) do
			local c = provider(player, profile)
			if c.luckAdd and c.luckAdd > 0 then
				luckFactor *= (1 + c.luckAdd)
			end
			if c.bossChanceMult and c.bossChanceMult > 1 then
				bossMult *= c.bossChanceMult
			end
			if c.sellAdd and c.sellAdd > 0 then
				sellFactor *= (1 + c.sellAdd)
			end
			if c.strengthAdd and c.strengthAdd > 0 then
				strengthFactor *= (1 + c.strengthAdd)
			end
			if c.mutationAdd and c.mutationAdd > 0 then
				mutationFactor *= (1 + c.mutationAdd)
			end
			if c.biteSpeedAdd and c.biteSpeedAdd > 0 then
				biteSpeedFactor *= (1 + c.biteSpeedAdd)
			end
		end
		evaluatingPlayers[player] = nil
	end

	return {
		luckMult = luckFactor,
		bossChanceMult = bossMult,
		sellMult = sellFactor * rebirthMult * gpGoldMult,
		strengthMult = strengthFactor * rebirthMult * gpStrMult,
		mutationMult = mutationFactor,
		biteSpeedMult = biteSpeedFactor,
		minigameWidthBonus = effRod.controlBonus + enchantCtrl + strengthWidthBonus,
		minigameSpeedDivisor = math.max(1.0, 1.0 + effRod.steadiness + enchantStead),
		titanWeightFactor = titanWeightFactor,
		midasSellBonus = midasSellBonus,
		maxEquippedPets = maxPets,
	}
end

return BuffAggregator
