--!strict
-- PetsService.luau: Mo trung Gold/Gems, trang bi 2-4 Pet (dong bo Attribute cho ClientPetRenderer) & cong BuffAggregator

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local PetsConfig = require(Shared:WaitForChild("Config"):WaitForChild("PetsConfig"))

local DataService = require(script.Parent.DataService)
local PerkService = require(script.Parent.PerkService)
local BuffAggregator = require(script.Parent.BuffAggregator)
local PetBuffs = require(script.Parent.PetBuffs)
local CurrencyService = require(script.Parent.CurrencyService)

local PetsService = {}

local hatchHooks: { (Player, Types.PetDef) -> () } = {}

function PetsService.OnPetHatched(callback: (Player, Types.PetDef) -> ())
	table.insert(hatchHooks, callback)
end

local function sanitizeEquippedList(player: Player, profile: Types.PlayerProfile): { [string]: string }
	PetBuffs.Invalidate(profile) -- moi thay doi Pet/trang bi deu di qua day
	local ownedByUid: { [string]: string } = {}
	for _, inst in ipairs(profile.pets) do
		ownedByUid[inst.uid] = inst.petId
	end

	local maxSlots = BuffAggregator.GetMaxEquippedPets(player)
	local clean: { string } = {}
	local seen: { [string]: boolean } = {}
	for _, uid in ipairs(profile.equippedPetUids) do
		if ownedByUid[uid] and not seen[uid] and #clean < maxSlots then
			seen[uid] = true
			table.insert(clean, uid)
		end
	end
	profile.equippedPetUids = clean
	return ownedByUid
end

function PetsService.SyncVisualsAndClient(player: Player)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	local ownedByUid = sanitizeEquippedList(player, profile)

	local equippedIds: { string } = {}
	for _, uid in ipairs(profile.equippedPetUids) do
		local petId = ownedByUid[uid]
		if petId and PetsConfig.PetsById[petId] then
			table.insert(equippedIds, petId)
		end
	end

	-- Dong bo gon nhe qua Attribute de ClientPetRenderer noi suy muot 60FPS tren Client!
	player:SetAttribute("EquippedPetIds", table.concat(equippedIds, ","))

	Net.FireClient(player, Net.ServerToClient.PetsUpdated, {
		pets = profile.pets,
		equippedPetUids = profile.equippedPetUids,
		maxSlots = BuffAggregator.GetMaxEquippedPets(player),
	})
end

function PetsService.AwardPetDirect(player: Player, petDef: Types.PetDef, sourceLabel: string, eggId: string?)
	local profile = DataService.Get(player)
	if not profile or #profile.pets >= GameConfig.MAX_PET_INVENTORY then
		return
	end

	local inst: Types.PetInstance = {
		uid = Util.NewUid(),
		petId = petDef.id,
	}
	table.insert(profile.pets, inst)
	profile.indexPets[petDef.id] = (profile.indexPets[petDef.id] or 0) + 1

	local maxSlots = BuffAggregator.GetMaxEquippedPets(player)
	if #profile.equippedPetUids < maxSlots then
		table.insert(profile.equippedPetUids, inst.uid)
	end

	DataService.MarkDirty(player)
	PetsService.SyncVisualsAndClient(player)

	Net.FireClient(player, Net.ServerToClient.EggHatched, {
		eggId = eggId or petDef.eggId,
		petId = petDef.id,
		petName = petDef.name,
		rarity = petDef.rarity,
		source = sourceLabel,
	})

	if petDef.rarity == "Mythic" then
		Net.FireAllClients(Net.ServerToClient.Toast, {
			kind = "Epic",
			text = string.format("🌟 %s hatched a MYTHIC %s!", player.DisplayName, petDef.name),
		})
	end

	for _, cb in ipairs(hatchHooks) do
		task.spawn(cb, player, petDef)
	end
end

function PetsService.HandleHatchEgg(player: Player, eggId: string)
	local profile = DataService.Get(player)
	local egg = PetsConfig.EggsById[eggId]
	if not profile or not egg or DataService.IsTransactionLocked(player, true) then
		return
	end

	if not profile.unlockedIslands[tostring(egg.islandId)] then
		Net.FireClient(player, Net.ServerToClient.Toast, {
			kind = "Error",
			text = "Unlock Island " .. tostring(egg.islandId) .. " first to hatch this egg!",
		})
		return
	end

	if #profile.pets >= GameConfig.MAX_PET_INVENTORY then
		Net.FireClient(player, Net.ServerToClient.Toast, {
			kind = "Error",
			text = "Pet inventory is full! Delete weak pets to make room.",
		})
		return
	end

	if egg.currency == "Gold" then
		if not CurrencyService.SpendGold(player, egg.cost) then
			Net.FireClient(player, Net.ServerToClient.Toast, {
				kind = "Error",
				text = string.format("Need %s Gold to hatch %s!", Util.FormatNumber(egg.cost), egg.name),
			})
			return
		end
	else
		if PerkService.ArePaidRandomItemsRestricted(player) then
			local st = PerkService.GetPolicyState(player)
			local msg = if st == "Loading"
				then "Verifying regional policy — please wait 1 second and try again!"
				else "Regional policy restricts paid random Gem eggs — hatch Gold Eggs or earn Boss Pet drops!"
			Net.FireClient(player, Net.ServerToClient.Toast, { kind = "Error", text = msg })
			return
		end
		if not CurrencyService.SpendGems(player, egg.cost) then
			Net.FireClient(player, Net.ServerToClient.Toast, {
				kind = "Error",
				text = string.format("Need %s Gems to hatch %s!", Util.FormatNumber(egg.cost), egg.name),
			})
			return
		end
	end

	profile.stats.eggsHatched += 1
	local rolledPet = Util.PickWeighted(egg.pets, function(p: Types.PetDef): number
		return p.weightChance
	end)
	PetsService.AwardPetDirect(player, rolledPet, egg.name, egg.id)
end

local function handleEquipPet(player: Player, uid: string)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	for _, existing in ipairs(profile.equippedPetUids) do
		if existing == uid then
			return
		end
	end
	local owns = false
	for _, inst in ipairs(profile.pets) do
		if inst.uid == uid then
			owns = true
			break
		end
	end
	if not owns then
		return
	end

	local maxSlots = BuffAggregator.GetMaxEquippedPets(player)
	if #profile.equippedPetUids >= maxSlots then
		Net.FireClient(player, Net.ServerToClient.Toast, { kind = "Info", text = "Pet slots are full. Unequip a pet first!" })
		return
	end
	table.insert(profile.equippedPetUids, uid)
	DataService.MarkDirty(player)
	PetsService.SyncVisualsAndClient(player)
end

local function handleUnequipPet(player: Player, uid: string)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	if uid == "ALL" then
		table.clear(profile.equippedPetUids)
	else
		for idx, eqUid in ipairs(profile.equippedPetUids) do
			if eqUid == uid then
				table.remove(profile.equippedPetUids, idx)
				break
			end
		end
	end
	DataService.MarkDirty(player)
	PetsService.SyncVisualsAndClient(player)
end

local function handleEquipBest(player: Player)
	local profile = DataService.Get(player)
	if not profile or #profile.pets == 0 then
		return
	end

	-- Tinh diem moi loai Pet dung mot lan roi moi sap xep (truoc day tinh lai trong tung phep so sanh).
	local scoreByPetId: { [string]: number } = {}
	for _, inst in ipairs(profile.pets) do
		if scoreByPetId[inst.petId] == nil then
			local def = PetsConfig.PetsById[inst.petId]
			scoreByPetId[inst.petId] = if def then PetsConfig.GetEffectivePowerScore(def, profile.pets) else 0
		end
	end
	local sorted = table.clone(profile.pets)
	table.sort(sorted, function(a: Types.PetInstance, b: Types.PetInstance): boolean
		return scoreByPetId[a.petId] > scoreByPetId[b.petId]
	end)

	local maxSlots = BuffAggregator.GetMaxEquippedPets(player)
	table.clear(profile.equippedPetUids)
	for i = 1, math.min(maxSlots, #sorted) do
		table.insert(profile.equippedPetUids, sorted[i].uid)
	end
	DataService.MarkDirty(player)
	PetsService.SyncVisualsAndClient(player)
	Net.FireClient(player, Net.ServerToClient.Toast, { kind = "Success", text = "⚡ Equipped your strongest Pets!" })
end

local function handleDeletePet(player: Player, uid: string)
	local profile = DataService.Get(player)
	if not profile or DataService.IsTransactionLocked(player, true) then
		return
	end
	for idx, eqUid in ipairs(profile.equippedPetUids) do
		if eqUid == uid then
			table.remove(profile.equippedPetUids, idx)
			break
		end
	end
	for idx, inst in ipairs(profile.pets) do
		if inst.uid == uid then
			table.remove(profile.pets, idx)
			break
		end
	end
	DataService.MarkDirty(player)
	PetsService.SyncVisualsAndClient(player)
end

function PetsService.Init()
	BuffAggregator.RegisterProvider(function(player: Player, profile: Types.PlayerProfile)
		return PetBuffs.Get(profile, BuffAggregator.GetMaxEquippedPets(player))
	end)

	DataService.OnProfileLoaded(function(player: Player)
		PetsService.SyncVisualsAndClient(player)
	end)

	Net.OnServerEvent(Net.ClientToServer.HatchEgg, function(p: Player, id: any) if type(id) == "string" then PetsService.HandleHatchEgg(p, id) end end)
	Net.OnServerEvent(Net.ClientToServer.EquipPet, function(p: Player, u: any) if type(u) == "string" then handleEquipPet(p, u) end end)
	Net.OnServerEvent(Net.ClientToServer.UnequipPet, function(p: Player, u: any) if type(u) == "string" then handleUnequipPet(p, u) end end)
	Net.OnServerEvent(Net.ClientToServer.EquipBestPets, handleEquipBest)
	Net.OnServerEvent(Net.ClientToServer.DeletePet, function(p: Player, u: any) if type(u) == "string" then handleDeletePet(p, u) end end)
end

return PetsService
