--!strict
-- FishingRoller.luau: Server Raycast xac thuc Mat Nuoc vs Vat Can, Cong kep (Power + MaxKg), Titan Cap & Roll Ca

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local OddsCalculator = require(Shared:WaitForChild("OddsCalculator"))
local Util = require(Shared:WaitForChild("Util"))
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

local function buildServerWaterRayParams(): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = false
	local exclude: { Instance } = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(exclude, p.Character)
		end
	end
	local wp = Workspace:FindFirstChild("OceanWhirlpools")
	if wp then table.insert(exclude, wp) end
	params.FilterDescendantsInstances = exclude
	return params
end

-- Tra ve: (waterPos: Vector3?, obstacleBouncePos: Vector3?)
function FishingRoller.ValidateAimedWaterPoint(player: Player, islandId: number, rawTarget: any): (Vector3?, Vector3?)
	if not FishingRoller.IsFiniteVector3(rawTarget) then
		return nil, nil
	end
	local char = player.Character
	local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
	local waterPart = getIslandWaterPart(islandId)
	if not (root and root:IsA("BasePart")) or not waterPart then
		return nil, nil
	end

	local target = rawTarget :: Vector3
	local pPos = root.Position
	local horizDist = Vector3.new(pPos.X - target.X, 0, pPos.Z - target.Z).Magnitude
	if horizDist > GameConfig.FISHING_MAX_WATER_DIST then
		return nil, nil
	end

	local half = waterPart.Size * 0.5
	local wCenter = waterPart.Position
	if math.abs(target.X - wCenter.X) > half.X or math.abs(target.Z - wCenter.Z) > half.Z then
		return nil, nil
	end

	local surfacePos = Vector3.new(target.X, wCenter.Y + half.Y, target.Z)
	local params = buildServerWaterRayParams()

	-- 1. Kiem tra duong nem tu vai nguoi choi toi diem nuoc: neu trung Cau go / Da truoc -> nay phao!
	local origin = pPos + Vector3.new(0, 2.2, 0)
	local toSurface = (surfacePos - Vector3.new(0, 0.25, 0)) - origin
	local lineHit = Workspace:Raycast(origin, toSurface, params)
	if lineHit and lineHit.Material ~= Enum.Material.Water then
		return nil, lineHit.Position
	end

	-- 2. Kiem tra thang dung tu tren xuong dam bao diem roi thuc su la Terrain Water (khong bi che gam cau!)
	local skyCheck = Workspace:Raycast(surfacePos + Vector3.new(0, 18, 0), Vector3.new(0, -24, 0), params)
	if skyCheck and skyCheck.Material ~= Enum.Material.Water then
		return nil, skyCheck.Position
	end
	if not skyCheck then
		return nil, nil
	end

	return Vector3.new(surfacePos.X, skyCheck.Position.Y, surfacePos.Z), nil
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
	-- Kep tran dung theo tai trong can (1.25x khi co Titan Line, lam tron xuong 0.1kg de khong bao gio vuot tran!)
	local capMult = if boostBig then 1.25 else 1.15
	local finalCap = effMaxWeight * capMult
	local clamped = math.min(scaledKg, finalCap)
	local weight = math.max(0.1, math.floor(clamped * 10 + 1e-6) / 10)
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

function FishingRoller.ResolveManualHoldBonuses(startedAt: number?, rawHoldRatio: any): (string, number, number)
	if not startedAt then
		return "ManualNormal", 0, 0
	end
	local serverHoldElapsed = os.clock() - startedAt
	if serverHoldElapsed < 0.55 then
		return "ManualNormal", 0, 0
	end
	local clientHold = tonumber(rawHoldRatio) or 0
	local serverRatio = FishingRoller.ComputeChargeRatio(serverHoldElapsed)
	local trustedRatio = if math.abs(clientHold - serverRatio) <= 0.24 then clientHold else serverRatio
	if trustedRatio >= GameConfig.PERFECT_HOLD_MIN and trustedRatio <= GameConfig.PERFECT_HOLD_MAX then
		return "ManualPerfect", GameConfig.PERFECT_CAST_LUCK_ADD, GameConfig.PERFECT_CAST_LURE_ADD
	end
	return "ManualNormal", 0, 0
end

function FishingRoller.IsWithinLandBounceRange(player: Player, rawHitPos: any): Vector3?
	if not FishingRoller.IsFiniteVector3(rawHitPos) then
		return nil
	end
	local char = player.Character
	local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
	if not (root and root:IsA("BasePart")) then
		return nil
	end
	local hitPos = rawHitPos :: Vector3
	if (hitPos - root.Position).Magnitude > (GameConfig.FISHING_MAX_WATER_DIST + 45) then
		return nil
	end
	return hitPos
end

return FishingRoller
