--!strict
-- CurrencyService.luau: Quan ly Gold, Gems, Strength, Lock Ca & 4 luong Ban Ca (chan tuyet doi Locked & Soulbound Trophy)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))

local DataService = require(script.Parent.DataService)
local BuffAggregator = require(script.Parent.BuffAggregator)

local CurrencyService = {}

local statChangedHooks: { (Player, string, number) -> () } = {}
local bagMutatedHooks: { (Player, Types.PlayerProfile) -> () } = {}

function CurrencyService.OnStatIncremented(callback: (Player, string, number) -> ())
	table.insert(statChangedHooks, callback)
end

function CurrencyService.OnBagMutated(callback: (Player, Types.PlayerProfile) -> ())
	table.insert(bagMutatedHooks, callback)
end

local function notifyStat(player: Player, statName: string, delta: number)
	for _, cb in ipairs(statChangedHooks) do
		task.spawn(cb, player, statName, delta)
	end
end

function CurrencyService.NotifyBagAndHotbarChanged(player: Player, profile: Types.PlayerProfile)
	local validUids: { [string]: boolean } = {}
	for _, f in ipairs(profile.fishBag) do
		validUids[f.uid] = true
	end
	for slotKey, pinnedUid in pairs(profile.pinnedFishUids) do
		if not validUids[pinnedUid] then
			profile.pinnedFishUids[slotKey] = nil
		end
	end
	if profile.equippedHotbarSlot >= 2 and profile.equippedHotbarSlot <= 5 then
		local curKey = tostring(profile.equippedHotbarSlot)
		if not profile.pinnedFishUids[curKey] then
			profile.equippedHotbarSlot = 1
		end
	end

	Net.FireClient(player, Net.ServerToClient.BagUpdated, {
		fishBag = profile.fishBag,
	})
	Net.FireClient(player, Net.ServerToClient.HotbarUpdated, {
		equippedSlot = profile.equippedHotbarSlot,
		pinnedFishUids = profile.pinnedFishUids,
		rodId = profile.rodId,
	})
	for _, cb in ipairs(bagMutatedHooks) do
		task.spawn(cb, player, profile)
	end
end

function CurrencyService.PushCurrencies(player: Player)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	DataService.SyncLeaderstats(player)
	Net.FireClient(player, Net.ServerToClient.CurrencyUpdated, {
		gold = profile.gold,
		gems = profile.gems,
		strength = profile.strength,
		rebirths = profile.rebirths,
	})
end

function CurrencyService.AddGold(player: Player, rawAmount: number, showPopup: boolean?): number
	local profile = DataService.Get(player)
	if not profile or rawAmount <= 0 then
		return 0
	end
	local amount = math.max(1, math.floor(rawAmount + 0.5))
	profile.gold += amount
	profile.stats.goldEarned += amount
	DataService.MarkDirty(player)
	CurrencyService.PushCurrencies(player)
	notifyStat(player, "goldEarned", amount)

	if showPopup then
		Net.FireClient(player, Net.ServerToClient.FloatingGain, { kind = "Gold", amount = amount })
	end
	return amount
end

function CurrencyService.SpendGold(player: Player, cost: number): boolean
	local profile = DataService.Get(player)
	if not profile or cost < 0 or DataService.IsTransactionLocked(player, true) then
		return false
	end
	local needed = math.floor(cost)
	if profile.gold < needed then
		return false
	end
	profile.gold -= needed
	DataService.MarkDirty(player)
	CurrencyService.PushCurrencies(player)
	return true
end

function CurrencyService.AddGems(player: Player, rawAmount: number, showPopup: boolean?): number
	local profile = DataService.Get(player)
	if not profile or rawAmount <= 0 then
		return 0
	end
	local amount = math.max(1, math.floor(rawAmount + 0.5))
	profile.gems += amount
	DataService.MarkDirty(player)
	CurrencyService.PushCurrencies(player)

	if showPopup then
		Net.FireClient(player, Net.ServerToClient.FloatingGain, { kind = "Gems", amount = amount })
	end
	return amount
end

function CurrencyService.SpendGems(player: Player, cost: number): boolean
	local profile = DataService.Get(player)
	if not profile or cost < 0 or DataService.IsTransactionLocked(player, true) then
		return false
	end
	local needed = math.floor(cost)
	if profile.gems < needed then
		return false
	end
	profile.gems -= needed
	DataService.MarkDirty(player)
	CurrencyService.PushCurrencies(player)
	return true
end

function CurrencyService.AddStrength(player: Player, baseAmount: number, applyMultipliers: boolean?, showPopup: boolean?): number
	local profile = DataService.Get(player)
	if not profile or baseAmount <= 0 then
		return 0
	end
	local mult = if applyMultipliers == false then 1.0 else BuffAggregator.GetMultipliers(player).strengthMult
	local gained = math.max(1, math.floor(baseAmount * mult + 0.5))
	profile.strength += gained
	profile.totalStrength += gained
	DataService.MarkDirty(player)
	CurrencyService.PushCurrencies(player)
	notifyStat(player, "strength", gained)

	if showPopup then
		Net.FireClient(player, Net.ServerToClient.FloatingGain, { kind = "Strength", amount = gained })
	end
	return gained
end

local function isProtectedFromGoldSell(entry: Types.CaughtFish): boolean
	return entry.soulbound == true or entry.locked == true
end

function CurrencyService.SellAllFish(player: Player)
	local profile = DataService.Get(player)
	if not profile or DataService.IsTransactionLocked(player, true) then
		return
	end
	if #profile.fishBag == 0 then
		Net.FireClient(player, Net.ServerToClient.Toast, { kind = "Info", text = "Your Fish Bag is empty!" })
		return
	end

	local kept: { Types.CaughtFish } = {}
	local rawTotal = 0
	local soldCount = 0
	for _, fish in ipairs(profile.fishBag) do
		if isProtectedFromGoldSell(fish) then
			table.insert(kept, fish)
		else
			rawTotal += math.max(1, fish.sellValue)
			soldCount += 1
		end
	end

	if soldCount == 0 then
		Net.FireClient(player, Net.ServerToClient.Toast, {
			kind = "Info",
			text = "All fish in your Bag are 🔒 Locked or 🏆 Soulbound Trophies!",
		})
		return
	end

	profile.fishBag = kept
	local sellMult = BuffAggregator.GetMultipliers(player).sellMult
	local finalGold = math.max(1, math.floor(rawTotal * sellMult + 0.5))
	CurrencyService.AddGold(player, finalGold, true)
	CurrencyService.NotifyBagAndHotbarChanged(player, profile)

	local keptNote = if #kept > 0 then string.format(" (%d locked/trophy safe)", #kept) else ""
	Net.FireClient(player, Net.ServerToClient.Toast, {
		kind = "Success",
		text = string.format("Sold %d fish for +%s Gold!%s", soldCount, Util.FormatNumber(finalGold), keptNote),
	})
end

function CurrencyService.SellSingleFish(player: Player, uid: string)
	local profile = DataService.Get(player)
	if not profile or type(uid) ~= "string" or DataService.IsTransactionLocked(player, true) then
		return
	end
	for idx, entry in ipairs(profile.fishBag) do
		if entry.uid == uid then
			if entry.soulbound then
				Net.FireClient(player, Net.ServerToClient.Toast, {
					kind = "Error",
					text = "🏆 Soulbound Trophy fish cannot be sold for Gold! (Trade at Fish Bounties instead)",
				})
				return
			end
			if entry.locked then
				Net.FireClient(player, Net.ServerToClient.Toast, {
					kind = "Info",
					text = "🔒 Unlock this fish first before selling!",
				})
				return
			end
			table.remove(profile.fishBag, idx)
			local sellMult = BuffAggregator.GetMultipliers(player).sellMult
			local finalGold = math.max(1, math.floor(entry.sellValue * sellMult + 0.5))
			CurrencyService.AddGold(player, finalGold, true)
			CurrencyService.NotifyBagAndHotbarChanged(player, profile)
			return
		end
	end
end

function CurrencyService.SellSelectedFish(player: Player, uidList: { any })
	local profile = DataService.Get(player)
	if not profile or DataService.IsTransactionLocked(player, true) then
		return
	end
	local wantSet: { [string]: boolean } = {}
	for _, u in ipairs(uidList) do
		if type(u) == "string" then
			wantSet[u] = true
		end
	end

	local kept: { Types.CaughtFish } = {}
	local rawTotal = 0
	local soldCount = 0
	for _, fish in ipairs(profile.fishBag) do
		if wantSet[fish.uid] and not isProtectedFromGoldSell(fish) then
			rawTotal += math.max(1, fish.sellValue)
			soldCount += 1
		else
			table.insert(kept, fish)
		end
	end
	if soldCount == 0 then
		Net.FireClient(player, Net.ServerToClient.Toast, {
			kind = "Info",
			text = "No unlocked sellable fish in selection!",
		})
		return
	end

	profile.fishBag = kept
	local sellMult = BuffAggregator.GetMultipliers(player).sellMult
	local finalGold = math.max(1, math.floor(rawTotal * sellMult + 0.5))
	CurrencyService.AddGold(player, finalGold, true)
	CurrencyService.NotifyBagAndHotbarChanged(player, profile)
	Net.FireClient(player, Net.ServerToClient.Toast, {
		kind = "Success",
		text = string.format("Sold %d selected fish for +%s Gold!", soldCount, Util.FormatNumber(finalGold)),
	})
end

function CurrencyService.SellHeldFish(player: Player)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	local slot = profile.equippedHotbarSlot
	if slot < 2 or slot > 5 then
		Net.FireClient(player, Net.ServerToClient.Toast, {
			kind = "Info",
			text = "Hold a fish in your hands (Hotbar slots 2–5) to sell held fish!",
		})
		return
	end
	local uid = profile.pinnedFishUids[tostring(slot)]
	if not uid then
		return
	end
	CurrencyService.SellSingleFish(player, uid)
end

function CurrencyService.ToggleLockFish(player: Player, uid: string)
	local profile = DataService.Get(player)
	if not profile or type(uid) ~= "string" then
		return
	end
	for _, entry in ipairs(profile.fishBag) do
		if entry.uid == uid then
			if entry.soulbound then
				entry.locked = true
				Net.FireClient(player, Net.ServerToClient.Toast, {
					kind = "Info",
					text = "🏆 Soulbound Trophies stay permanently locked & protected across Rebirths!",
				})
				return
			end
			entry.locked = not entry.locked
			DataService.MarkDirty(player)
			Net.FireClient(player, Net.ServerToClient.BagUpdated, { fishBag = profile.fishBag })
			return
		end
	end
end

function CurrencyService.Init()
	Net.OnServerEvent(Net.ClientToServer.SellAllFish, CurrencyService.SellAllFish)
	Net.OnServerEvent(Net.ClientToServer.SellHeldFish, CurrencyService.SellHeldFish)
	Net.OnServerEvent(Net.ClientToServer.SellSingleFish, function(player: Player, rawUid: any)
		if type(rawUid) == "string" then
			CurrencyService.SellSingleFish(player, rawUid)
		end
	end)
	Net.OnServerEvent(Net.ClientToServer.SellSelectedFish, function(player: Player, rawList: any)
		if type(rawList) == "table" then
			CurrencyService.SellSelectedFish(player, rawList)
		end
	end)
	Net.OnServerEvent(Net.ClientToServer.ToggleLockFish, function(player: Player, rawUid: any)
		if type(rawUid) == "string" then
			CurrencyService.ToggleLockFish(player, rawUid)
		end
	end)
end

return CurrencyService
