--!strict
-- Types.luau: Dinh nghia kieu du lieu dung chung toan du an Mighty Angler v2.0

export type Rarity = string
export type MutationName = string
export type SizeTier = string

export type FishDef = {
	id: string,
	name: string,
	islandId: number,
	rarity: Rarity,
	baseValue: number,
	minWeight: number,
	maxWeight: number,
	weightChance: number,
	minRodPower: number,
	strengthReward: number,
	primaryColor: Color3,
	secondaryColor: Color3,
	scale: number,
}

export type CaughtFish = {
	uid: string,
	fishId: string,
	weight: number,
	mutation: MutationName,
	sellValue: number,
	originalValue: number,
	sizeTier: SizeTier,
	locked: boolean,
	soulbound: boolean,
	midasBonus: number,
}

export type GymStationDef = {
	stationType: "Dumbbells" | "Treadmill" | "BenchPress",
	name: string,
	multiplier: number,
	minStrength: number,
	offset: Vector3,
}

export type IslandTheme = {
	grassColor: Color3,
	sandColor: Color3,
	cliffColor: Color3,
	waterColor: Color3,
	accentColor: Color3,
	ambientOutdoor: Color3,
	clockTime: number,
	sceneryStyle: "Sunny" | "Coral" | "Swamp" | "Volcano" | "Celestial",
}

export type IslandDef = {
	id: number,
	name: string,
	subtitle: string,
	unlockCostGold: number,
	baseGymGain: number,
	economyMultiplier: number,
	centerPosition: Vector3,
	theme: IslandTheme,
	gymStations: { GymStationDef },
	fishPool: { FishDef },
	goldEggId: string,
	gemEggId: string,
	hasComingSoonGate: boolean?,
}

export type RodDef = {
	id: string,
	order: number,
	name: string,
	priceGold: number,
	strengthReq: number,
	power: number,
	maxWeight: number,
	lureSpeed: number,
	luckBonus: number,
	controlBonus: number,
	steadiness: number,
	rodColor: Color3,
	accentColor: Color3,
	description: string,
	isExclusive: boolean?,
	scaleFactor: number?,
	flatLure: number?,
	flatLuck: number?,
	flatControl: number?,
	flatSteadiness: number?,
	unlockHint: string?,
}

export type EffectiveRodStats = {
	id: string,
	name: string,
	power: number,
	equipStrengthReq: number,
	masteryBaselineStrength: number,
	maxWeight: number,
	lureSpeed: number,
	luckBonus: number,
	controlBonus: number,
	steadiness: number,
	isExclusive: boolean,
	enchantId: string?,
	sourceBaseRodName: string?,
}

export type EnchantDef = {
	id: string,
	name: string,
	rarity: Rarity,
	chance: number,
	color: Color3,
	lureBonus: number,
	luckBonus: number,
	controlBonus: number,
	steadinessBonus: number,
	mutationBonus: number,
	titanWeightFactor: number,
	midasSellBonus: number,
	description: string,
}

export type BountyDef = {
	id: string,
	title: string,
	islandReq: number,
	rarityReq: Rarity,
	minWeight: number,
	mutationReq: MutationName?,
	gemReward: number,
	relicReward: number,
	potionReward: string?,
	description: string,
}

export type BaitDef = {
	id: string,
	order: number,
	name: string,
	priceGold: number,
	packSize: number,
	luckBonus: number,
	bossChanceMult: number,
	mutationBonus: number,
	color: Color3,
	description: string,
}

export type GymGearDef = {
	level: number,
	id: string,
	name: string,
	priceGold: number,
	strengthBonus: number,
	color: Color3,
	description: string,
}

export type PotionKind = string

export type PotionDef = {
	id: string,
	name: string,
	kind: PotionKind,
	tier: number,
	bonus: number,
	durationSec: number,
	color: Color3,
	description: string,
}

export type PetArchetype = string

export type PetDef = {
	id: string,
	name: string,
	eggId: string,
	islandId: number,
	rarity: Rarity,
	archetype: PetArchetype,
	weightChance: number,
	sellBonus: number,
	strengthBonus: number,
	luckBonus: number,
	mutationBonus: number,
	primaryColor: Color3,
	secondaryColor: Color3,
}

export type EggDef = {
	id: string,
	name: string,
	islandId: number,
	currency: "Gold" | "Gems",
	cost: number,
	eggColor: Color3,
	accentColor: Color3,
	pets: { PetDef },
}

export type PetInstance = {
	uid: string,
	petId: string,
}

export type ActivePotionState = {
	potionId: string,
	tier: number,
	expiresAt: number,
}

export type QuestEntry = {
	id: string,
	progress: number,
	claimed: boolean,
}

export type PlayerStats = {
	fishCaught: number,
	rareCaught: number,
	bossCaught: number,
	mutationsCaught: number,
	gymReps: number,
	goldEarned: number,
	eggsHatched: number,
	eventsJoined: number,
	playTimeSec: number,
}

export type PlayerProfile = {
	dataVersion: number,
	activeSessionId: string?,
	lockTimestamp: number,
	saveSeq: number,
	gold: number,
	gems: number,
	strength: number,
	totalStrength: number,
	rebirths: number,
	rodId: string,
	ownedRods: { [string]: boolean },
	rodEnchants: { [string]: string },
	enchantRelics: number,
	equippedHotbarSlot: number,
	pinnedFishUids: { [string]: string },
	unlockedIslands: { [string]: boolean },
	currentIsland: number,
	fishBag: { CaughtFish },
	potions: { [string]: number },
	activePotions: { [string]: ActivePotionState },
	bait: { [string]: number },
	activeBait: string?,
	gymGearLevel: number,
	pets: { PetInstance },
	equippedPetUids: { string },
	indexFish: { [string]: number },
	indexPets: { [string]: number },
	claimedIndexRewards: { [string]: boolean },
	claimedAchievements: { [string]: boolean },
	dailyStreak: number,
	lastDailyClaimDay: number,
	questDay: number,
	dailyQuests: { [string]: QuestEntry },
	playtimeDay: number,
	playtimeTodaySec: number,
	playtimeClaimedToday: { [string]: boolean },
	autoLockRare: boolean,
	autoLockMutated: boolean,
	lowGfx: boolean,
	muteSfx: boolean,
	stats: PlayerStats,
}

export type AggregatedMultipliers = {
	luckMult: number,
	bossChanceMult: number,
	sellMult: number,
	strengthMult: number,
	mutationMult: number,
	biteSpeedMult: number,
	minigameWidthBonus: number,
	minigameSpeedDivisor: number,
	titanWeightFactor: number,
	midasSellBonus: number,
	maxEquippedPets: number,
}

return {}
