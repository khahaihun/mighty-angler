--!strict
-- PotionAndBaitHelper.luau: Tinh buff Bait + GymGear + Potions, quet thuoc het han & dong bo Hotbar cam Can / cam Ca

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Net = require(Shared:WaitForChild("Net"))
local BaitConfig = require(Shared:WaitForChild("Config"):WaitForChild("BaitConfig"))
local GymGearConfig = require(Shared:WaitForChild("Config"):WaitForChild("GymGearConfig"))
local PotionsConfig = require(Shared:WaitForChild("Config"):WaitForChild("PotionsConfig"))

local RodVisuals = require(script.Parent.Parent.World.RodVisuals)
local PetAndFishVisuals = require(script.Parent.Parent.World.PetAndFishVisuals)

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

function PotionAndBaitHelper.FindFishByUid(profile: Types.PlayerProfile, uid: string): Types.CaughtFish?
	for _, f in ipairs(profile.fishBag) do
		if f.uid == uid then
			return f
		end
	end
	return nil
end

function PotionAndBaitHelper.SyncCharacterHandVisuals(player: Player, profile: Types.PlayerProfile?)
	if not profile then
		return
	end
	local slot = profile.equippedHotbarSlot
	if slot == 1 then
		PetAndFishVisuals.EquipHeldFishOnCharacter(player, nil)
		RodVisuals.EquipRodOnCharacter(player, profile.rodId)
	elseif slot >= 2 and slot <= 5 then
		RodVisuals.UnequipRodFromCharacter(player)
		local uid = profile.pinnedFishUids[tostring(slot)]
		local entry = if uid then PotionAndBaitHelper.FindFishByUid(profile, uid) else nil
		PetAndFishVisuals.EquipHeldFishOnCharacter(player, entry)
	else
		RodVisuals.UnequipRodFromCharacter(player)
		PetAndFishVisuals.EquipHeldFishOnCharacter(player, nil)
	end
end

function PotionAndBaitHelper.PushHotbar(player: Player, profile: Types.PlayerProfile)
	Net.FireClient(player, Net.ServerToClient.HotbarUpdated, {
		equippedSlot = profile.equippedHotbarSlot,
		pinnedFishUids = profile.pinnedFishUids,
		rodId = profile.rodId,
	})
end

return PotionAndBaitHelper
