--!strict
-- FishingRoller.luau: Xac dinh diem mat nuoc, roll loai ca theo Luck/Boss va roll dot bien (Mutation)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Util = require(Shared:WaitForChild("Util"))
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))

local FishingRoller = {}

function FishingRoller.FindWaterCastPoint(player: Player, islandId: number): Vector3?
	local char = player.Character
	local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
	if not (root and root:IsA("BasePart")) then
		return nil
	end

	local worldRoot = Workspace:FindFirstChild("MightyWorld")
	local islandFolder = if worldRoot then worldRoot:FindFirstChild("Island_" .. tostring(islandId)) else nil
	local waterPart = if islandFolder then islandFolder:FindFirstChild("FishingWater") else nil
	if not (waterPart and waterPart:IsA("BasePart")) then
		return nil
	end

	local pPos = root.Position
	local forwardTarget = pPos + root.CFrame.LookVector * 18
	local half = waterPart.Size * 0.5
	local wCenter = waterPart.Position

	local clampedX = math.clamp(forwardTarget.X, wCenter.X - half.X + 4, wCenter.X + half.X - 4)
	local clampedZ = math.clamp(forwardTarget.Z, wCenter.Z - half.Z + 4, wCenter.Z + half.Z - 4)

	-- Dam bao phao cau luon roi ra mat nuoc thoang ngoai ria cau go (khong bi khuat gam cau)
	local relX = clampedX - wCenter.X
	local dockEndZ = wCenter.Z + 10 -- Tuong ung Z ~ 124 so voi tam dao
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

function FishingRoller.RollFishSpecies(
	forcedRarity: string?,
	islandDef: Types.IslandDef,
	rodPower: number,
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

	local candidates: { Types.FishDef } = {}
	for _, f in ipairs(islandDef.fishPool) do
		if rodPower >= f.minRodPower then
			table.insert(candidates, f)
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

function FishingRoller.RollMutation(mutationMult: number): (Types.MutationName, number)
	local r = math.random()
	local cosmicChance = math.min(0.18, GameConfig.Mutations.Cosmic.chance * mutationMult)
	local goldenChance = math.min(0.32, GameConfig.Mutations.Golden.chance * mutationMult)
	local shinyChance = math.min(0.45, GameConfig.Mutations.Shiny.chance * mutationMult)

	if r <= cosmicChance then
		return "Cosmic" :: Types.MutationName, GameConfig.Mutations.Cosmic.multiplier
	elseif r <= cosmicChance + goldenChance then
		return "Golden" :: Types.MutationName, GameConfig.Mutations.Golden.multiplier
	elseif r <= cosmicChance + goldenChance + shinyChance then
		return "Shiny" :: Types.MutationName, GameConfig.Mutations.Shiny.multiplier
	end
	return "None" :: Types.MutationName, 1
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
