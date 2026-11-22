--!strict
-- PetBuffs.luau: Tong buff cua cac Pet dang trang bi, nho san theo ho so (tach khoi PetsService de giu file do < 310 dong).
-- PetsService goi Invalidate moi khi Pet/trang bi doi; Get con tu so so Pet va danh sach trang bi de phong ma khac sua thang.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local PetsConfig = require(Shared:WaitForChild("Config"):WaitForChild("PetsConfig"))

local BuffAggregator = require(script.Parent.BuffAggregator)

local PetBuffs = {}

type Entry = { maxSlots: number, petCount: number, equipped: { string }, equippedCount: number, buff: BuffAggregator.BonusContribution }
local cache: { [Types.PlayerProfile]: Entry } = setmetatable({}, { __mode = "k" }) :: any

function PetBuffs.Invalidate(profile: Types.PlayerProfile)
	cache[profile] = nil
end

function PetBuffs.Get(profile: Types.PlayerProfile, maxSlots: number): BuffAggregator.BonusContribution
	local cached = cache[profile]
	if cached and cached.maxSlots == maxSlots and cached.petCount == #profile.pets
		and cached.equipped == profile.equippedPetUids and cached.equippedCount == #profile.equippedPetUids then
		return cached.buff
	end
	local ownedByUid: { [string]: string } = {}
	for _, inst in ipairs(profile.pets) do
		ownedByUid[inst.uid] = inst.petId
	end

	local sellAdd, strAdd, luckAdd, mutAdd, count = 0, 0, 0, 0, 0
	for _, uid in ipairs(profile.equippedPetUids) do
		local petId = ownedByUid[uid]
		local def = if petId then PetsConfig.PetsById[petId] else nil
		if def then
			local eff = PetsConfig.GetEffectivePetStats(def, profile.pets)
			count += 1
			sellAdd += eff.sellBonus
			strAdd += eff.strengthBonus
			luckAdd += eff.luckBonus
			mutAdd += eff.mutationBonus
			if count >= maxSlots then
				break
			end
		end
	end

	local buff = { sellAdd = sellAdd, strengthAdd = strAdd, luckAdd = luckAdd, mutationAdd = mutAdd }
	cache[profile] = {
		maxSlots = maxSlots, petCount = #profile.pets,
		equipped = profile.equippedPetUids, equippedCount = #profile.equippedPetUids, buff = buff,
	}
	return buff
end

return PetBuffs
