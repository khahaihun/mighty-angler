--!strict
-- RebirthConfig.luau: Cong thuc moc Strength Chuyen sinh (Rebirth), phan thuong Gems + Potions & Nhan vinh vien

local RebirthConfig = {}

RebirthConfig.BASE_STRENGTH_REQ = 5000000
RebirthConfig.EXPONENT = 1.55
RebirthConfig.MULTIPLIER_PER_REBIRTH = 0.50

function RebirthConfig.GetStrengthRequirement(currentRebirths: number): number
	local raw = RebirthConfig.BASE_STRENGTH_REQ * ((currentRebirths + 1) ^ RebirthConfig.EXPONENT)
	return math.floor(raw / 1000 + 0.5) * 1000
end

function RebirthConfig.GetGemReward(currentRebirths: number): number
	return 150 + currentRebirths * 75
end

function RebirthConfig.GetPermanentMultiplier(rebirths: number): number
	return 1.0 + rebirths * RebirthConfig.MULTIPLIER_PER_REBIRTH
end

return RebirthConfig
