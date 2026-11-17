--!strict
-- ShopAndItemsService.luau: Mua & trang bi Can cau (Chang 1), mo rong them Moi/Do Gym/Potions o Chang 2

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))
local RodsConfig = require(Shared:WaitForChild("Config"):WaitForChild("RodsConfig"))

local DataService = require(script.Parent.DataService)
local CurrencyService = require(script.Parent.CurrencyService)

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
			text = string.format("Need %s Strength to wield %s! Hit the Gym!", Util.FormatNumber(rod.strengthReq), rod.name),
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
	if not profile or not rod then
		return
	end
	if not profile.ownedRods[rodId] then
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

	Net.FireClient(player, Net.ServerToClient.Toast, {
		kind = "Info",
		text = "Equipped " .. rod.name .. "!",
	})
end

function ShopAndItemsService.Init()
	Net.OnServerEvent(Net.ClientToServer.BuyRod, function(player: Player, rawRodId: any)
		if type(rawRodId) == "string" then
			ShopAndItemsService.HandleBuyRod(player, rawRodId)
		end
	end)

	Net.OnServerEvent(Net.ClientToServer.EquipRod, function(player: Player, rawRodId: any)
		if type(rawRodId) == "string" then
			ShopAndItemsService.HandleEquipRod(player, rawRodId)
		end
	end)
end

return ShopAndItemsService
