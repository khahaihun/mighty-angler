--!strict
-- TrophyHelper.luau: Ham dung chung 100% giua Client & Server de xep hang va chon toi da 12 Soulbound Trophies khi Rebirth

local Types = require(script.Parent.Types)
local GameConfig = require(script.Parent.Config.GameConfig)

local TrophyHelper = {}

-- So sanh on dinh tuyet doi: originalValue giam dan -> weight giam dan -> uid tang dan
function TrophyHelper.CompareCandidates(a: any, b: any): boolean
	-- Uu tien tuyet doi ca da la Soulbound Trophy tu kiep truoc de khong bao gio bi roi mat ngoai y muon!
	local sbA = (a.soulbound == true)
	local sbB = (b.soulbound == true)
	if sbA ~= sbB then
		return sbA
	end
	local oa = tonumber(a.originalValue) or tonumber(a.sellValue) or 0
	local ob = tonumber(b.originalValue) or tonumber(b.sellValue) or 0
	if oa ~= ob then
		return oa > ob
	end
	local wa = tonumber(a.weight) or 0
	local wb = tonumber(b.weight) or 0
	if wa ~= wb then
		return wa > wb
	end
	return tostring(a.uid or "") < tostring(b.uid or "")
end

function TrophyHelper.PartitionForRebirth(fishBag: { any }): ({ Types.CaughtFish }, { Types.CaughtFish }, { [string]: boolean })
	local eligible: { any } = {}
	for _, entry in ipairs(fishBag) do
		if type(entry) == "table" and (entry.locked == true or entry.soulbound == true) then
			table.insert(eligible, entry)
		end
	end
	table.sort(eligible, TrophyHelper.CompareCandidates)

	local kept: { Types.CaughtFish } = {}
	local overflowLocked: { Types.CaughtFish } = {}
	local keptUidSet: { [string]: boolean } = {}
	local cap = GameConfig.MAX_SOULBOUND_TROPHIES

	for idx, item in ipairs(eligible) do
		if idx <= cap then
			table.insert(kept, item :: Types.CaughtFish)
			keptUidSet[tostring(item.uid)] = true
		else
			table.insert(overflowLocked, item :: Types.CaughtFish)
		end
	end
	return kept, overflowLocked, keptUidSet
end

return TrophyHelper
