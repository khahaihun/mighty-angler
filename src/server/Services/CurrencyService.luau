--!strict
-- CurrencyService.luau: Quan ly Gold, Gems, Strength va giao dich Ban Ca Server-Authoritative

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))

local DataService = require(script.Parent.DataService)
local BuffAggregator = require(script.Parent.BuffAggregator)

local CurrencyService = {}

local statChangedHooks: { (Player, string, number) -> () } = {}

function CurrencyService.OnStatIncremented(callback: (Player, string, number) -> ())
	table.insert(statChangedHooks, callback)
end

local function notifyStat(player: Player, statName: string, delta: number)
	for _, cb in ipairs(statChangedHooks) do
		task.spawn(cb, player, statName, delta)
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
		Net.FireClient(player, Net.ServerToClient.FloatingGain, {
			kind = "Gold",
			amount = amount,
		})
	end
	return amount
end

function CurrencyService.SpendGold(player: Player, cost: number): boolean
	local profile = DataService.Get(player)
	if not profile or cost < 0 then
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
		Net.FireClient(player, Net.ServerToClient.FloatingGain, {
			kind = "Gems",
			amount = amount,
		})
	end
	return amount
end

function CurrencyService.SpendGems(player: Player, cost: number): boolean
	local profile = DataService.Get(player)
	if not profile or cost < 0 then
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
		Net.FireClient(player, Net.ServerToClient.FloatingGain, {
			kind = "Strength",
			amount = gained,
		})
	end
	return gained
end

function CurrencyService.SellAllFish(player: Player)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	if #profile.fishBag == 0 then
		Net.FireClient(player, Net.ServerToClient.Toast, {
			kind = "Info",
			text = "Your Fish Bag is empty! Go catch some fish first.",
		})
		return
	end

	local sellMult = BuffAggregator.GetMultipliers(player).sellMult
	local rawTotal = 0
	local count = #profile.fishBag
	for _, fish in ipairs(profile.fishBag) do
		rawTotal += fish.sellValue
	end

	table.clear(profile.fishBag)
	local finalGold = math.max(1, math.floor(rawTotal * sellMult + 0.5))
	CurrencyService.AddGold(player, finalGold, true)

	Net.FireClient(player, Net.ServerToClient.BagUpdated, {
		fishBag = profile.fishBag,
	})
	Net.FireClient(player, Net.ServerToClient.Toast, {
		kind = "Success",
		text = string.format("Sold %d fish for +%s Gold!", count, Util.FormatNumber(finalGold)),
	})
end

function CurrencyService.SellSingleFish(player: Player, uid: string)
	local profile = DataService.Get(player)
	if not profile or type(uid) ~= "string" then
		return
	end
	local foundIdx: number? = nil
	for idx, entry in ipairs(profile.fishBag) do
		if entry.uid == uid then
			foundIdx = idx
			break
		end
	end
	if not foundIdx then
		return
	end

	local entry = profile.fishBag[foundIdx]
	table.remove(profile.fishBag, foundIdx)
	local sellMult = BuffAggregator.GetMultipliers(player).sellMult
	local finalGold = math.max(1, math.floor(entry.sellValue * sellMult + 0.5))
	CurrencyService.AddGold(player, finalGold, true)

	Net.FireClient(player, Net.ServerToClient.BagUpdated, {
		fishBag = profile.fishBag,
	})
end

function CurrencyService.Init()
	Net.OnServerEvent(Net.ClientToServer.SellAllFish, function(player: Player)
		CurrencyService.SellAllFish(player)
	end)

	Net.OnServerEvent(Net.ClientToServer.SellSingleFish, function(player: Player, rawUid: any)
		if type(rawUid) == "string" then
			CurrencyService.SellSingleFish(player, rawUid)
		end
	end)
end

return CurrencyService
