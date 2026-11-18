--!strict
-- FishingRoller.luau: Server Raycast xac thuc Mat Nuoc vs Vat Can, Cong kep (Power + MaxKg), Titan Cap & Roll Ca

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local OddsCalculator = require(Shared:WaitForChild("OddsCalculator"))
local Util = require(Shared:WaitForChild("Util"))
local FishingRayFilter = require(Shared:WaitForChild("FishingRayFilter"))
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))

local FishingRoller = {}

function FishingRoller.IsFiniteVector3(v: any): boolean
	if typeof(v) ~= "Vector3" then
		return false
	end
	local vec = v :: Vector3
	return vec.X == vec.X and vec.Y == vec.Y and vec.Z == vec.Z
		and math.abs(vec.X) < 100000 and math.abs(vec.Y) < 100000 and math.abs(vec.Z) < 100000
end

local function getIslandWaterPart(islandId: number): BasePart?
	local worldRoot = Workspace:FindFirstChild("MightyWorld")
	local islandFolder = if worldRoot then worldRoot:FindFirstChild("Island_" .. tostring(islandId)) else nil
	local waterPart = if islandFolder then islandFolder:FindFirstChild("FishingWater") else nil
	if waterPart and waterPart:IsA("BasePart") then
		return waterPart
	end
	return nil
end

-- All casts use the first real server hit. Client material and bounce position are never trusted.
function FishingRoller.ValidateAimedWaterPoint(player: Player, islandId: number, rawTarget: any): (Vector3?, Vector3?)
 if not FishingRoller.IsFiniteVector3(rawTarget) then return nil, nil end
 local char = player.Character
 local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
 local water = getIslandWaterPart(islandId)
 if not root or not root:IsA("BasePart") or not water then return nil, nil end
 local origin = root.Position + Vector3.new(0, 2.2, 0)
 local target = rawTarget :: Vector3
 local delta = target - origin
 if delta.Magnitude < 0.1 or delta.Magnitude > GameConfig.FISHING_MAX_WATER_DIST or target.Y > origin.Y then return nil, nil end
 local hit = Workspace:Raycast(origin, delta + delta.Unit * 0.5, FishingRayFilter.Create())
 if not hit then return nil, nil end
 if hit.Material ~= Enum.Material.Water then return nil, hit.Position end
 local half, center = water.Size * 0.5, water.Position
 local pos = hit.Position
 if math.abs(pos.X - center.X) > half.X or math.abs(pos.Z - center.Z) > half.Z
  or math.abs(pos.Y - (center.Y + half.Y)) > 2 then return nil, nil end
 return pos, nil
end

function FishingRoller.FindWaterCastPoint(player: Player, islandId: number): Vector3?
 local char = player.Character
 local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
 local water = getIslandWaterPart(islandId)
 if not root or not root:IsA("BasePart") or not water then return nil end
 local surfaceY = water.Position.Y + water.Size.Y * 0.5
 local forward = root.Position + root.CFrame.LookVector * 24
 local first = FishingRoller.ValidateAimedWaterPoint(player, islandId, Vector3.new(forward.X, surfaceY, forward.Z))
 if first then return first end
 -- Deterministic bounded search, validated by exactly the same first-hit path as manual casts.
 for _, radius in ipairs({16, 24, 36, 52, 72}) do
  for angle = 0, 11 do
   local theta = angle * math.pi / 6
   local target = Vector3.new(root.Position.X + math.cos(theta) * radius, surfaceY, root.Position.Z + math.sin(theta) * radius)
   local pos = FishingRoller.ValidateAimedWaterPoint(player, islandId, target)
   if pos then return pos end
  end
 end
 return nil
end

function FishingRoller.GetEligibleCandidates(
	islandDef: Types.IslandDef,
	effPower: number,
	effMaxWeight: number
): { Types.FishDef }
	return OddsCalculator.GetEligibleCandidates(islandDef, effPower, effMaxWeight)
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

	return Util.PickWeighted(candidates, function(fish: Types.FishDef): number
		return OddsCalculator.GetFishWeight(fish, mults.luckMult, mults.bossChanceMult, inWhirlpool == true)
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
	local finalCap = if boostBig then effMaxWeight * 1.25 else math.max(fishDef.maxWeight, effMaxWeight * 1.15)
	local clamped = math.min(scaledKg, finalCap)
	local weight = math.max(0.1, if boostBig then math.floor(clamped * 10 + 1e-6) / 10 else math.floor(clamped * 10 + 0.5) / 10)
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

local CHARGE_CYCLE_SEC = 1.15

function FishingRoller.ComputeChargeRatio(elapsed: number): number
	local u = (elapsed / CHARGE_CYCLE_SEC) % 2.0
	return if u <= 1.0 then u else (2.0 - u)
end

function FishingRoller.ResolveManualHoldBonuses(startedAt: number?, _rawHoldRatio: any): (string, number, number)
	if not startedAt then
		return "ManualNormal", 0, 0
	end
	local serverHoldElapsed = os.clock() - startedAt
	if serverHoldElapsed < 0.55 then
		return "ManualNormal", 0, 0
	end
	local trustedRatio = FishingRoller.ComputeChargeRatio(serverHoldElapsed)
	if trustedRatio >= GameConfig.PERFECT_HOLD_MIN and trustedRatio <= GameConfig.PERFECT_HOLD_MAX then
		return "ManualPerfect", GameConfig.PERFECT_CAST_LUCK_ADD, GameConfig.PERFECT_CAST_LURE_ADD
	end
	return "ManualNormal", 0, 0
end

return FishingRoller
