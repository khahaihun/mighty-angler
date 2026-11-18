--!strict
-- ShopAndItemsService.luau: Quan ly Can cau (chan Exclusive Gold), Hotbar (1..5), Moi cau, Do Gym va Potions

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))
local RodsConfig = require(Shared:WaitForChild("Config"):WaitForChild("RodsConfig"))
local BaitConfig = require(Shared:WaitForChild("Config"):WaitForChild("BaitConfig"))
local GymGearConfig = require(Shared:WaitForChild("Config"):WaitForChild("GymGearConfig"))
local PotionsConfig = require(Shared:WaitForChild("Config"):WaitForChild("PotionsConfig"))

local DataService = require(script.Parent.DataService)
local PerkService = require(script.Parent.PerkService)
local BuffAggregator = require(script.Parent.BuffAggregator)
local CurrencyService = require(script.Parent.CurrencyService)
local PotionAndBaitHelper = require(script.Parent.PotionAndBaitHelper)

local ShopAndItemsService = {}

local rodChangedCallbacks: { (Player, string) -> () } = {}
local hotbarChangedCallbacks: { (Player, number) -> () } = {}

function ShopAndItemsService.OnRodChanged(callback: (Player, string) -> ())
	table.insert(rodChangedCallbacks, callback)
end

function ShopAndItemsService.OnHotbarSlotChanged(callback: (Player, number) -> ())
	table.insert(hotbarChangedCallbacks, callback)
end

function ShopAndItemsService.SyncCharacterHandVisuals(player: Player)
	PotionAndBaitHelper.SyncCharacterHandVisuals(player, DataService.Get(player))
end

function ShopAndItemsService.PushInventory(player: Player)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	Net.FireClient(player, Net.ServerToClient.InventoryUpdated, {
		rodId = profile.rodId,
		ownedRods = profile.ownedRods,
		rodEnchants = profile.rodEnchants,
		enchantRelics = profile.enchantRelics,
		bait = profile.bait,
		activeBait = profile.activeBait,
		gymGearLevel = profile.gymGearLevel,
		potions = profile.potions,
		activePotions = profile.activePotions,
		serverNow = os.time(),
	})
	PotionAndBaitHelper.PushHotbar(player, profile)
end

function ShopAndItemsService.GrantPotion(player: Player, potionId: string, qty: number, notify: boolean?)
	local profile = DataService.Get(player)
	local pDef = PotionsConfig.ById[potionId]
	if not profile or not pDef or qty <= 0 then
		return
	end
	profile.potions[potionId] = math.min(99, (profile.potions[potionId] or 0) + math.floor(qty))
	DataService.MarkDirty(player)
	ShopAndItemsService.PushInventory(player)
	if notify then
		Net.FireClient(player, Net.ServerToClient.Toast, {
			kind = "Success",
			text = string.format("🧪 Received +%dx %s!", qty, pDef.name),
		})
	end
end

function ShopAndItemsService.GrantBait(player: Player, baitId: string, qty: number)
	local profile = DataService.Get(player)
	local bDef = BaitConfig.ById[baitId]
	if not profile or not bDef or qty <= 0 then
		return
	end
	profile.bait[baitId] = math.min(999, (profile.bait[baitId] or 0) + math.floor(qty))
	if profile.activeBait == nil then
		profile.activeBait = baitId
	end
	DataService.MarkDirty(player)
	ShopAndItemsService.PushInventory(player)
end

function ShopAndItemsService.ConsumeGivenBaitOnCatch(player: Player, profile: Types.PlayerProfile, baitId: string?)
	if not baitId or baitId == "" then
		return
	end
	local count = profile.bait[baitId] or 0
	if count <= 1 then
		profile.bait[baitId] = nil
		if profile.activeBait == baitId then
			profile.activeBait = nil
		end
	else
		profile.bait[baitId] = count - 1
	end
	ShopAndItemsService.PushInventory(player)
end

function ShopAndItemsService.HandleBuyRod(player: Player, rodId: string)
	local profile = DataService.Get(player)
	local rod = RodsConfig.ById[rodId]
	if not profile or not rod then
		return
	end
	if rod.isExclusive then
		Net.FireClient(player, Net.ServerToClient.Toast, {
			kind = "Error",
			text = "Exclusive Rods cannot be bought with Gold! Unlock via Collector, Gems, or Pass.",
		})
		return
	end
	if profile.ownedRods[rodId] then
		ShopAndItemsService.HandleEquipRod(player, rodId)
		return
	end
	if profile.strength < rod.strengthReq then
		Net.FireClient(player, Net.ServerToClient.Toast, {
			kind = "Error",
			text = string.format("Need %s Strength to wield %s!", Util.FormatNumber(rod.strengthReq), rod.name),
		})
		return
	end
	if not CurrencyService.SpendGold(player, rod.priceGold) then
		Net.FireClient(player, Net.ServerToClient.Toast, {
			kind = "Error",
			text = string.format("Need %s Gold to buy %s!", Util.FormatNumber(rod.priceGold), rod.name),
		})
		return
	end

	profile.ownedRods[rodId] = true
	profile.rodId = rodId
	profile.equippedHotbarSlot = 1
	DataService.MarkDirty(player)
	ShopAndItemsService.PushInventory(player)
	ShopAndItemsService.SyncCharacterHandVisuals(player)
	for _, cb in ipairs(rodChangedCallbacks) do
		task.spawn(cb, player, rodId)
	end
	Net.FireClient(player, Net.ServerToClient.Toast, { kind = "Success", text = "Purchased & equipped " .. rod.name .. "!" })
end

function ShopAndItemsService.HandleEquipRod(player: Player, rodId: string)
	local profile = DataService.Get(player)
	local rod = RodsConfig.ById[rodId]
	if not profile or not rod or not profile.ownedRods[rodId] then
		return
	end
	local eff = RodsConfig.GetEffectiveStats(rodId, profile.ownedRods, profile.rodEnchants)
	if profile.strength < eff.equipStrengthReq then
		Net.FireClient(player, Net.ServerToClient.Toast, {
			kind = "Error",
			text = string.format("Need %s Strength to equip %s!", Util.FormatNumber(eff.equipStrengthReq), rod.name),
		})
		return
	end
	profile.rodId = rodId
	profile.equippedHotbarSlot = 1
	DataService.MarkDirty(player)
	ShopAndItemsService.PushInventory(player)
	ShopAndItemsService.SyncCharacterHandVisuals(player)
	for _, cb in ipairs(rodChangedCallbacks) do
		task.spawn(cb, player, rodId)
	end
end

function ShopAndItemsService.SetHotbarSlot(player: Player, wantedSlot: number)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	local slot = math.clamp(math.floor(wantedSlot), 0, 5)
	if slot >= 2 and slot <= 5 then
		local uid = profile.pinnedFishUids[tostring(slot)]
		if not uid or not PotionAndBaitHelper.FindFishByUid(profile, uid) then
			Net.FireClient(player, Net.ServerToClient.Toast, {
				kind = "Info",
				text = "Pin a fish from your Bag to Hotbar Slot " .. tostring(slot) .. " first!",
			})
			return
		end
	end
	if profile.equippedHotbarSlot == slot and slot ~= 0 then
		slot = 0
	end
	profile.equippedHotbarSlot = slot
	DataService.MarkDirty(player)
	PotionAndBaitHelper.PushHotbar(player, profile)
	ShopAndItemsService.SyncCharacterHandVisuals(player)
	for _, cb in ipairs(hotbarChangedCallbacks) do
		task.spawn(cb, player, slot)
	end
end

local function handlePinFishToSlot(player: Player, slotKey: string, uid: string)
	local profile = DataService.Get(player)
	local n = tonumber(slotKey)
	if not profile or not n or n < 2 or n > 5 then
		return
	end
	local key = tostring(math.floor(n))
	if uid == "" then
		profile.pinnedFishUids[key] = nil
		if profile.equippedHotbarSlot == n then
			profile.equippedHotbarSlot = 1
		end
	else
		if not PotionAndBaitHelper.FindFishByUid(profile, uid) then
			return
		end
		for otherKey, existingUid in pairs(profile.pinnedFishUids) do
			if existingUid == uid then
				profile.pinnedFishUids[otherKey] = nil
			end
		end
		profile.pinnedFishUids[key] = uid
		profile.equippedHotbarSlot = math.floor(n)
	end
	DataService.MarkDirty(player)
	ShopAndItemsService.PushInventory(player)
	ShopAndItemsService.SyncCharacterHandVisuals(player)
	for _, cb in ipairs(hotbarChangedCallbacks) do
		task.spawn(cb, player, profile.equippedHotbarSlot)
	end
end

local function handleBuyBait(player: Player, baitId: string)
	local bDef = BaitConfig.ById[baitId]
	if not bDef or not CurrencyService.SpendGold(player, bDef.priceGold) then
		return
	end
	ShopAndItemsService.GrantBait(player, baitId, bDef.packSize)
	Net.FireClient(player, Net.ServerToClient.Toast, { kind = "Success", text = string.format("Bought +%d %s!", bDef.packSize, bDef.name) })
end

local function handleSelectBait(player: Player, baitId: string)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	if baitId == "" then
		profile.activeBait = nil
	elseif BaitConfig.ById[baitId] and (profile.bait[baitId] or 0) > 0 then
		profile.activeBait = baitId
	else
		return
	end
	DataService.MarkDirty(player)
	ShopAndItemsService.PushInventory(player)
end

local function handleBuyGymGear(player: Player, targetLevel: number)
	local profile = DataService.Get(player)
	local gDef = GymGearConfig.ByLevel[targetLevel]
	if not profile or not gDef or profile.gymGearLevel + 1 ~= targetLevel or not CurrencyService.SpendGold(player, gDef.priceGold) then
		return
	end
	profile.gymGearLevel = targetLevel
	DataService.MarkDirty(player)
	ShopAndItemsService.PushInventory(player)
	Net.FireClient(player, Net.ServerToClient.Toast, { kind = "Success", text = "🥊 Upgraded Gym Gear: " .. gDef.name .. "!" })
end

local function handleUsePotion(player: Player, potionId: string)
	local profile = DataService.Get(player)
	local pDef = PotionsConfig.ById[potionId]
	if not profile or not pDef or (profile.potions[potionId] or 0) <= 0 then
		return
	end
	local now = os.time()
	local existing = profile.activePotions[pDef.kind]
	if existing and existing.expiresAt > now and existing.tier > pDef.tier then
		Net.FireClient(player, Net.ServerToClient.Toast, { kind = "Error", text = "A stronger " .. pDef.kind .. " potion is active!" })
		return
	end
	local owned = profile.potions[potionId] or 0
	if owned <= 1 then
		profile.potions[potionId] = nil
	else
		profile.potions[potionId] = owned - 1
	end
	profile.activePotions[pDef.kind] = { potionId = pDef.id, tier = pDef.tier, expiresAt = now + pDef.durationSec }
	DataService.MarkDirty(player)
	ShopAndItemsService.PushInventory(player)
	Net.FireClient(player, Net.ServerToClient.Toast, { kind = "Success", text = "🧪 Activated " .. pDef.name .. "!" })
end

function ShopAndItemsService.Init()
	BuffAggregator.RegisterProvider(PotionAndBaitHelper.ComputeBuffContribution)
	CurrencyService.OnBagMutated(function(player: Player) ShopAndItemsService.SyncCharacterHandVisuals(player) end)
	PerkService.OnGamepassUnlocked(function(player: Player) ShopAndItemsService.PushInventory(player) end)

	Net.OnServerEvent(Net.ClientToServer.BuyRod, function(p: Player, id: any) if type(id) == "string" then ShopAndItemsService.HandleBuyRod(p, id) end end)
	Net.OnServerEvent(Net.ClientToServer.EquipRod, function(p: Player, id: any) if type(id) == "string" then ShopAndItemsService.HandleEquipRod(p, id) end end)
	Net.OnServerEvent(Net.ClientToServer.SelectHotbarSlot, function(p: Player, s: any) local n = tonumber(s); if n then ShopAndItemsService.SetHotbarSlot(p, n) end end)
	Net.OnServerEvent(Net.ClientToServer.PinFishToSlot, function(p: Player, s: any, u: any) if type(s) == "string" and type(u) == "string" then handlePinFishToSlot(p, s, u) end end)
	Net.OnServerEvent(Net.ClientToServer.BuyBait, function(p: Player, id: any) if type(id) == "string" then handleBuyBait(p, id) end end)
	Net.OnServerEvent(Net.ClientToServer.SelectBait, function(p: Player, id: any) if type(id) == "string" then handleSelectBait(p, id) end end)
	Net.OnServerEvent(Net.ClientToServer.BuyGymGear, function(p: Player, lv: any) local n = tonumber(lv); if n then handleBuyGymGear(p, math.floor(n)) end end)
	Net.OnServerEvent(Net.ClientToServer.UsePotion, function(p: Player, id: any) if type(id) == "string" then handleUsePotion(p, id) end end)

	task.spawn(function()
		while true do
			task.wait(5)
			local now = os.time()
			for _, p in ipairs(Players:GetPlayers()) do
				local prof = DataService.Get(p)
				if prof and PotionAndBaitHelper.PruneExpiredPotions(prof, now) then
					ShopAndItemsService.PushInventory(p)
				end
			end
		end
	end)
end

return ShopAndItemsService
