--!strict
-- PotionAndBaitHelper.luau: Tinh he so buff cho Bait + GymGear + Potions va quet thuoc het han

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local BaitConfig = require(Shared:WaitForChild("Config"):WaitForChild("BaitConfig"))
local GymGearConfig = require(Shared:WaitForChild("Config"):WaitForChild("GymGearConfig"))
local PotionsConfig = require(Shared:WaitForChild("Config"):WaitForChild("PotionsConfig"))

local PotionAndBaitHelper = {}

function PotionAndBaitHelper.ComputeBuffContribution(_player: Player, profile: Types.PlayerProfile)
	local luckAdd = 0
	local bossMult = 1.0
	local sellAdd = 0
	local strAdd = 0
	local mutAdd = 0
	local speedAdd = 0

	if profile.activeBait then
		local bDef = BaitConfig.ById[profile.activeBait]
		if bDef and (profile.bait[profile.activeBait] or 0) > 0 then
			luckAdd += bDef.luckBonus
			bossMult *= bDef.bossChanceMult
			mutAdd += bDef.mutationBonus
		end
	end

	if profile.gymGearLevel > 0 then
		local gDef = GymGearConfig.ByLevel[profile.gymGearLevel]
		if gDef then
			strAdd += gDef.strengthBonus
		end
	end

	local now = os.time()
	for _, state in pairs(profile.activePotions) do
		if state.expiresAt > now then
			local pDef = PotionsConfig.ById[state.potionId]
			if pDef then
				if pDef.kind == "Luck" then
					luckAdd += pDef.bonus
				elseif pDef.kind == "Strength" then
					strAdd += pDef.bonus
				elseif pDef.kind == "Sell" then
					sellAdd += pDef.bonus
				elseif pDef.kind == "Mutation" then
					mutAdd += pDef.bonus
				elseif pDef.kind == "Speed" then
					speedAdd += pDef.bonus
				end
			end
		end
	end

	return {
		luckAdd = luckAdd,
		bossChanceMult = bossMult,
		sellAdd = sellAdd,
		strengthAdd = strAdd,
		mutationAdd = mutAdd,
		biteSpeedAdd = speedAdd,
	}
end

function PotionAndBaitHelper.PruneExpiredPotions(profile: Types.PlayerProfile, now: number): boolean
	local expiredAny = false
	for kind, st in pairs(profile.activePotions) do
		if st.expiresAt <= now then
			profile.activePotions[kind] = nil
			expiredAny = true
		end
	end
	return expiredAny
end

return PotionAndBaitHelper
