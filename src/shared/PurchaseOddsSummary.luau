--!strict
local OddsCalculator = require(script.Parent.OddsCalculator)
local GameConfig = require(script.Parent.Config.GameConfig)
local PurchaseOddsSummary = {}

function PurchaseOddsSummary.BuildLines(context: any, key: string): { string }
	local lines = { "Each result: BEFORE → AFTER purchase. Same equipped bait, pets, potions and event." }
	local afterRod = if key == "ExclusiveDragonRod" then "SeraphimDragon" else context.rodId
	local modes = {
		{ name = "Manual normal", before = 0, after = 0 },
		{ name = "Manual Perfect", before = GameConfig.PERFECT_CAST_LUCK_ADD, after = GameConfig.PERFECT_CAST_LUCK_ADD },
		{ name = "Auto Free", before = 0, after = 0 },
		{ name = "Auto Pro", before = if context.hasAutoPro then GameConfig.PERFECT_CAST_LUCK_ADD else 0,
			after = if context.hasAutoPro or key == "AutoFish" then GameConfig.PERFECT_CAST_LUCK_ADD else 0 },
	}
	local function compute(rod: string, castLuck: number)
		return OddsCalculator.ComputeLiveOdds(context.islandId, rod, context.ownedRods, context.rodEnchants,
			context.activeBait, context.baitMap, context.activePotions, context.pets, context.equippedPets,
			castLuck, context.activeEventId, context.nowSec)
	end
	for _, mode in ipairs(modes) do
		local before = compute(context.rodId, mode.before)
		local after = compute(afterRod, mode.after)
		table.insert(lines, "\n" .. mode.name .. " · normal water / whirlpool")
		for idx, odds in ipairs(before.fishOdds) do
			local other = after.fishOdds[idx]
			table.insert(lines, string.format("%s: %.3f%% → %.3f%% | whirlpool %.3f%% → %.3f%%",
				odds.fish.name, odds.effectivePct, other.effectivePct,
				before.wpOdds[idx].effectivePct, after.wpOdds[idx].effectivePct))
		end
		table.insert(lines, "Mutations before: " .. before.mutationSummary)
		table.insert(lines, "Mutations after: " .. after.mutationSummary)
	end
	return lines
end

return PurchaseOddsSummary
