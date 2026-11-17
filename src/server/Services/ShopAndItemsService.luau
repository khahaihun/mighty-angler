--!strict
-- ShopAndItemsService.luau: Quan ly Mua/Trang bi Can cau, Moi cau (Bait), Do Gym (Gear) va Dung Thuoc (Potions)

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
local BuffAggregator = require(script.Parent.BuffAggregator)
local CurrencyService = require(script.Parent.CurrencyService)
local PotionAndBaitHelper = require(script.Parent.PotionAndBaitHelper)

local ShopAndItemsService = {}

local rodChangedCallbacks: { (Player, string) -> () } = {}

function ShopAndItemsService.OnRodChanged(callback: (Player, string) -> ())
	table.insert(rodChangedCallbacks, callback)
end

local function fireRodChanged(player: Player, rodId: string)
	for _, cb in ipairs(rodChangedCallbacks) do
		task.spawn(cb, player, rodId)
	end
end

function ShopAndItemsService.PushInventory(player: Player)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	Net.FireClient(player, Net.ServerToClient.InventoryUpdated, {
		rodId = profile.rodId,
		ownedRods = profile.ownedRods,
		bait = profile.bait,
		activeBait = profile.activeBait,
		gymGearLevel = profile.gymGearLevel,
		potions = profile.potions,
		activePotions = profile.activePotions,
		serverNow = os.time(),
	})
end

function ShopAndItemsService.GrantPotion(player: Player, potionId: string, qty: number, notify: boolean?)
	local profile = DataService.Get(player)
	local pDef = PotionsConfig.ById[potionId]
	if not profile or not pDef or qty <= 0 then
		return
	end
	local cur = profile.potions[potionId] or 0
	profile.potions[potionId] = math.min(99, cur + math.floor(qty))
	DataService.MarkDirty(player)
	ShopAndItemsService.PushInventory(player)

	if notify then
		Net.FireClient(player, Net.ServerToClient.Toast, {
			kind = "Success",
			text = string.format("🧪 Received +%dx %s!", qty, pDef.name),
		})
	end
end

function ShopAndItemsService.ConsumeActiveBaitOnCatch(player: Player, profile: Types.PlayerProfile)
	local baitId = profile.activeBait
	if not baitId then
		return
	end
	local count = profile.bait[baitId] or 0
	if count <= 1 then
		profile.bait[baitId] = nil
		profile.activeBait = nil
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
	DataService.MarkDirty(player)
	ShopAndItemsService.PushInventory(player)
	fireRodChanged(player, rodId)

	Net.FireClient(player, Net.ServerToClient.Toast, {
		kind = "Success",
		text = "Purchased & equipped " .. rod.name .. "!",
	})
end

function ShopAndItemsService.HandleEquipRod(player: Player, rodId: string)
	local profile = DataService.Get(player)
	local rod = RodsConfig.ById[rodId]
	if not profile or not rod or not profile.ownedRods[rodId] then
		return
	end
	if profile.strength < rod.strengthReq then
		Net.FireClient(player, Net.ServerToClient.Toast, {
			kind = "Error",
			text = string.format("Need %s Strength to equip %s!", Util.FormatNumber(rod.strengthReq), rod.name),
		})
		return
	end
	profile.rodId = rodId
	DataService.MarkDirty(player)
	ShopAndItemsService.PushInventory(player)
	fireRodChanged(player, rodId)
end

local function handleBuyBait(player: Player, baitId: string)
	local profile = DataService.Get(player)
	local bDef = BaitConfig.ById[baitId]
	if not profile or not bDef then
		return
	end
	if not CurrencyService.SpendGold(player, bDef.priceGold) then
		Net.FireClient(player, Net.ServerToClient.Toast, {
			kind = "Error",
			text = string.format("Need %s Gold for %s pack!", Util.FormatNumber(bDef.priceGold), bDef.name),
		})
		return
	end

	local cur = profile.bait[baitId] or 0
	profile.bait[baitId] = math.min(999, cur + bDef.packSize)
	if profile.activeBait == nil then
		profile.activeBait = baitId
	end
	DataService.MarkDirty(player)
	ShopAndItemsService.PushInventory(player)

	Net.FireClient(player, Net.ServerToClient.Toast, {
		kind = "Success",
		text = string.format("Bought +%d %s!", bDef.packSize, bDef.name),
	})
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
	if not profile or not gDef or profile.gymGearLevel + 1 ~= targetLevel then
		return
	end
	if not CurrencyService.SpendGold(player, gDef.priceGold) then
		Net.FireClient(player, Net.ServerToClient.Toast, {
			kind = "Error",
			text = string.format("Need %s Gold to unlock %s!", Util.FormatNumber(gDef.priceGold), gDef.name),
		})
		return
	end

	profile.gymGearLevel = targetLevel
	DataService.MarkDirty(player)
	ShopAndItemsService.PushInventory(player)

	Net.FireClient(player, Net.ServerToClient.Toast, {
		kind = "Success",
		text = "🥊 Upgraded Gym Gear: " .. gDef.name .. "!",
	})
end

local function handleUsePotion(player: Player, potionId: string)
	local profile = DataService.Get(player)
	local pDef = PotionsConfig.ById[potionId]
	if not profile or not pDef then
		return
	end
	local owned = profile.potions[potionId] or 0
	if owned <= 0 then
		return
	end

	local now = os.time()
	local existing = profile.activePotions[pDef.kind]
	if existing and existing.expiresAt > now and existing.tier > pDef.tier then
		Net.FireClient(player, Net.ServerToClient.Toast, {
			kind = "Error",
			text = "A stronger " .. pDef.kind .. " potion is already active!",
		})
		return
	end

	if owned <= 1 then
		profile.potions[potionId] = nil
	else
		profile.potions[potionId] = owned - 1
	end

	profile.activePotions[pDef.kind] = {
		potionId = pDef.id,
		tier = pDef.tier,
		expiresAt = now + pDef.durationSec,
	}
	DataService.MarkDirty(player)
	ShopAndItemsService.PushInventory(player)

	Net.FireClient(player, Net.ServerToClient.Toast, {
		kind = "Success",
		text = string.format("🧪 Activated %s (%s)!", pDef.name, Util.FormatDuration(pDef.durationSec)),
	})
end

function ShopAndItemsService.Init()
	BuffAggregator.RegisterProvider(PotionAndBaitHelper.ComputeBuffContribution)

	Net.OnServerEvent(Net.ClientToServer.BuyRod, function(player: Player, rawId: any)
		if type(rawId) == "string" then
			ShopAndItemsService.HandleBuyRod(player, rawId)
		end
	end)
	Net.OnServerEvent(Net.ClientToServer.EquipRod, function(player: Player, rawId: any)
		if type(rawId) == "string" then
			ShopAndItemsService.HandleEquipRod(player, rawId)
		end
	end)
	Net.OnServerEvent(Net.ClientToServer.BuyBait, function(player: Player, rawId: any)
		if type(rawId) == "string" then
			handleBuyBait(player, rawId)
		end
	end)
	Net.OnServerEvent(Net.ClientToServer.SelectBait, function(player: Player, rawId: any)
		if type(rawId) == "string" then
			handleSelectBait(player, rawId)
		end
	end)
	Net.OnServerEvent(Net.ClientToServer.BuyGymGear, function(player: Player, rawLv: any)
		local lv = tonumber(rawLv)
		if lv then
			handleBuyGymGear(player, math.floor(lv))
		end
	end)
	Net.OnServerEvent(Net.ClientToServer.UsePotion, function(player: Player, rawId: any)
		if type(rawId) == "string" then
			handleUsePotion(player, rawId)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(5)
			local now = os.time()
			for _, player in ipairs(Players:GetPlayers()) do
				local profile = DataService.Get(player)
				if profile and PotionAndBaitHelper.PruneExpiredPotions(profile, now) then
					ShopAndItemsService.PushInventory(player)
				end
			end
		end
	end)
end

return ShopAndItemsService
