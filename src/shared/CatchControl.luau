--!strict
local GameConfig = require(script.Parent.Config.GameConfig)
local CatchControl = {}

function CatchControl.ComputeMastery(strength: number, baseline: number): number
	return math.clamp(math.log10(1 + math.max(0, strength) / math.max(baseline, 300)) / 2, 0, 1)
end

function CatchControl.ComputeWidthBonus(strength: number, baseline: number, control: number): number
	return control + CatchControl.ComputeMastery(strength, baseline) * GameConfig.STRENGTH_MAX_BAR_BONUS
end

function CatchControl.ComputeWidth(isBoss: boolean, bonus: number): number
	return math.clamp((if isBoss then 0.22 else 0.28) + bonus, 0.20, GameConfig.MINIGAME_MAX_WIDTH)
end

return CatchControl
