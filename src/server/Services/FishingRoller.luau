--!strict
-- FishingRoller.luau: Kiem tra vung nuoc, loc cong kep (Power + MaxKg), roll Ca/Boss/Whirlpool, SizeTier & Mutation

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Util = require(Shared:WaitForChild("Util"))
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))

local FishingRoller = {}

local function getIslandWaterPart(islandId: number): BasePart?
	local worldRoot = Workspace:FindFirstChild("MightyWorld")
	local islandFolder = if worldRoot then worldRoot:FindFirstChild("Island_" .. tostring(islandId)) else nil
	local waterPart = if islandFolder then islandFolder:FindFirstChild("FishingWater") else nil
	if waterPart and waterPart:IsA("BasePart") then
		return waterPart
	end
	return nil
end

function FishingRoller.ValidateAimedWaterPoint(player: Player, islandId: number, rawTarget: any): Vector3?
	if typeof(rawTarget) ~= "Vector3" then
		return nil
	end
	local char = player.Character
	local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
	local waterPart = getIslandWaterPart(islandId)
	if not (root and root:IsA("BasePart")) or not waterPart then
		return nil
	end

	local target = rawTarget :: Vector3
	local pPos = root.Position
	local horizDist = Vector3.new(pPos.X - target.X, 0, pPos.Z - target.Z).Magnitude
	if horizDist > GameConfig.FISHING_MAX_WATER_DIST then
		return nil
	end

	local half = waterPart.Size * 0.5
	local wCenter = waterPart.Position
	if math.abs(target.X - wCenter.X) > half.X or math.abs(target.Z - wCenter.Z) > half.Z then
		return nil
	end
	return Vector3.new(target.X, wCenter.Y + half.Y, target.Z)
end

function FishingRoller.FindWaterCastPoint(player: Player, islandId: number): Vector3?
	local char = player.Character
	local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
	local waterPart = getIslandWaterPart(islandId)
	if not (root and root:IsA("BasePart")) or not waterPart then
		return nil
	end

	local pPos = root.Position
	local forwardTarget = pPos + root.CFrame.LookVector * 20
	local half = waterPart.Size * 0.5
	local wCenter = waterPart.Position

	local clampedX = math.clamp(forwardTarget.X, wCenter.X - half.X + 4, wCenter.X + half.X - 4)
	local clampedZ = math.clamp(forwardTarget.Z, wCenter.Z - half.Z + 4, wCenter.Z + half.Z - 4)

	local relX = clampedX - wCenter.X
	local dockEndZ = wCenter.Z + 10
	if math.abs(relX) < 15.5 and clampedZ < dockEndZ then
		if pPos.Z > (wCenter.Z - 18) then
			clampedZ = dockEndZ + 4
		else
			local side = if relX >= 0 then 1 else -1
			clampedX = wCenter.X + side * 16.5
		end
	end

	local nearestWater = Vector3.new(clampedX, wCenter.Y + half.Y, clampedZ)
	local horizDist = Vector3.new(pPos.X - nearestWater.X, 0, pPos.Z - nearestWater.Z).Magnitude
	if horizDist > GameConfig.FISHING_MAX_WATER_DIST then
		return nil
	end
	return nearestWater
end

function FishingRoller.GetEligibleCandidates(
	islandDef: Types.IslandDef,
	effPower: number,
	effMaxWeight: number
): { Types.FishDef }
	local list: { Types.FishDef } = {}
	for _, f in ipairs(islandDef.fishPool) do
		if effPower >= f.minRodPower and f.minWeight <= effMaxWeight then
			table.insert(list, f)
		end
	end
	return list
end

function FishingRoller.RollFishSpecies(
	forcedRarity: string?,
	islandDef: Types.IslandDef,
	candidates: { Types.FishDef },
	mults: Types.AggregatedMultipliers,
	inWhirlpool: boolean?
): Types.FishDef
	if forcedRarity then
		for _, f in ipairs(islandDef.fishPool) do
			if f.rarity == forcedRarity then
				return f
			end
		end
	end
	if #candidates == 0 then
		return islandDef.fishPool[1]
	end

	local wpMult = if inWhirlpool then 2.0 else 1.0
	local effectiveLuck = mults.luckMult * wpMult

	return Util.PickWeighted(candidates, function(f: Types.FishDef): number
		local w = f.weightChance
		local order = GameConfig.RarityOrder[f.rarity] or 1
		if f.rarity == "Boss" then
			w = w * mults.bossChanceMult * wpMult * (1 + 0.25 * math.max(0, effectiveLuck - 1))
		elseif order >= 3 then
			w = w * effectiveLuck
		end
		return w
	end)
end

function FishingRoller.RollSizeTierAndWeight(
	fishDef: Types.FishDef,
	effMaxWeight: number,
	titanWeightFactor: number
): (Types.SizeTier, number, number)
	local boostBig = (titanWeightFactor > 1.01)
	local pickedTier = Util.PickWeighted(GameConfig.SizeTiers, function(t: any): number
		if boostBig and t.name ~= "Normal" then
			return t.chance * 2.5
		end
		return t.chance
	end)

	local baseKg = fishDef.minWeight + (fishDef.maxWeight - fishDef.minWeight) * math.random()
	local scaledKg = baseKg * pickedTier.weightMult * titanWeightFactor
	local capMult = if boostBig then 1.25 else 1.15
	local finalCap = math.max(fishDef.maxWeight, effMaxWeight * capMult)
	local weight = math.max(0.1, math.floor(math.min(scaledKg, finalCap) * 10 + 0.5) / 10)
	return pickedTier.name, weight, pickedTier.valueMult
end

function FishingRoller.RollMutation(mutationMult: number, midasSellBonus: number?): (Types.MutationName, number)
	local r = math.random()
	local cosmicChance = math.min(0.18, GameConfig.Mutations.Cosmic.chance * mutationMult)
	local goldenChance = math.min(0.32, GameConfig.Mutations.Golden.chance * mutationMult)
	local shinyChance = math.min(0.45, GameConfig.Mutations.Shiny.chance * mutationMult)

	local mut: Types.MutationName = "None"
	if r <= cosmicChance then
		mut = "Cosmic"
	elseif r <= cosmicChance + goldenChance then
		mut = "Golden"
	elseif r <= cosmicChance + goldenChance + shinyChance then
		mut = "Shiny"
	end

	-- Midas Sovereign: 20% co hoi nang None/Shiny len Golden (khong bao gio ghi de Cosmic/Golden!)
	if (midasSellBonus or 1.0) > 1.01 and (mut == "None" or mut == "Shiny") then
		if math.random() <= 0.20 then
			mut = "Golden"
		end
	end

	return mut, FishingRoller.GetMutationMultiplier(mut)
end

function FishingRoller.GetMutationMultiplier(mutation: Types.MutationName): number
	if mutation == "Shiny" then
		return GameConfig.Mutations.Shiny.multiplier
	elseif mutation == "Golden" then
		return GameConfig.Mutations.Golden.multiplier
	elseif mutation == "Cosmic" then
		return GameConfig.Mutations.Cosmic.multiplier
	end
	return 1
end

return FishingRoller
