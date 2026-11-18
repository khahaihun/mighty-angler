--!strict
-- PetsService.luau: Mo trung Gold/Gems, trang bi 2-4 Pet bay theo nhan vat & cong he so vao BuffAggregator

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local PetsConfig = require(Shared:WaitForChild("Config"):WaitForChild("PetsConfig"))

local DataService = require(script.Parent.DataService)
local BuffAggregator = require(script.Parent.BuffAggregator)
local CurrencyService = require(script.Parent.CurrencyService)
local PetAndFishVisuals = require(script.Parent.Parent.World.PetAndFishVisuals)

local PetsService = {}

local hatchHooks: { (Player, Types.PetDef) -> () } = {}

function PetsService.OnPetHatched(callback: (Player, Types.PetDef) -> ())
	table.insert(hatchHooks, callback)
end

local function sanitizeEquippedList(player: Player, profile: Types.PlayerProfile)
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
end

function PetsService.SyncVisualsAndClient(player: Player)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	sanitizeEquippedList(player, profile)

	local ownedByUid: { [string]: string } = {}
	for _, inst in ipairs(profile.pets) do
		ownedByUid[inst.uid] = inst.petId
	end

	local equippedDefs: { Types.PetDef } = {}
	for _, uid in ipairs(profile.equippedPetUids) do
		local petId = ownedByUid[uid]
		local def = if petId then PetsConfig.PetsById[petId] else nil
		if def then
			table.insert(equippedDefs, def)
		end
	end

	PetAndFishVisuals.SyncPlayerPets(player, equippedDefs)

	Net.FireClient(player, Net.ServerToClient.PetsUpdated, {
		pets = profile.pets,
		equippedPetUids = profile.equippedPetUids,
		maxSlots = BuffAggregator.GetMaxEquippedPets(player),
	})
end

function PetsService.AwardPetDirect(player: Player, petDef: Types.PetDef, sourceLabel: string)
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
		petId = petDef.id,
		petName = petDef.name,
		rarity = petDef.rarity,
		source = sourceLabel,
	})
	Net.FireClient(player, Net.ServerToClient.Toast, {
		kind = if petDef.rarity == "Mythic" or petDef.rarity == "Legendary" then "Epic" else "Success",
		text = string.format("🐾 Hatched [%s] %s!", petDef.rarity, petDef.name),
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
	if not profile or not egg then
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
	PetsService.AwardPetDirect(player, rolledPet, egg.name)
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
		table.remove(profile.equippedPetUids, 1)
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

	local sorted = table.clone(profile.pets)
	table.sort(sorted, function(a: Types.PetInstance, b: Types.PetInstance): boolean
		local defA = PetsConfig.PetsById[a.petId]
		local defB = PetsConfig.PetsById[b.petId]
		local scoreA = if defA then PetsConfig.GetPowerScore(defA) else 0
		local scoreB = if defB then PetsConfig.GetPowerScore(defB) else 0
		return scoreA > scoreB
	end)

	local maxSlots = BuffAggregator.GetMaxEquippedPets(player)
	table.clear(profile.equippedPetUids)
	for i = 1, math.min(maxSlots, #sorted) do
		table.insert(profile.equippedPetUids, sorted[i].uid)
	end
	DataService.MarkDirty(player)
	PetsService.SyncVisualsAndClient(player)

	Net.FireClient(player, Net.ServerToClient.Toast, {
		kind = "Success",
		text = "⚡ Equipped your strongest Pets!",
	})
end

local function handleDeletePet(player: Player, uid: string)
	local profile = DataService.Get(player)
	if not profile then
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
	-- Dang ky buff Pet vao BuffAggregator (KHONG goi nguoc GetMultipliers de tuyet doi khong de quy!)
	BuffAggregator.RegisterProvider(function(player: Player, profile: Types.PlayerProfile)
		local maxSlots = BuffAggregator.GetMaxEquippedPets(player)
		local ownedByUid: { [string]: string } = {}
		for _, inst in ipairs(profile.pets) do
			ownedByUid[inst.uid] = inst.petId
		end

		local sellAdd = 0
		local strAdd = 0
		local luckAdd = 0
		local mutAdd = 0
		local count = 0

		for _, uid in ipairs(profile.equippedPetUids) do
			local petId = ownedByUid[uid]
			local def = if petId then PetsConfig.PetsById[petId] else nil
			if def then
				count += 1
				sellAdd += def.sellBonus
				strAdd += def.strengthBonus
				luckAdd += def.luckBonus
				mutAdd += def.mutationBonus
				if count >= maxSlots then
					break
				end
			end
		end

		return {
			sellAdd = sellAdd,
			strengthAdd = strAdd,
			luckAdd = luckAdd,
			mutationAdd = mutAdd,
		}
	end)

	DataService.OnProfileLoaded(function(player: Player, _profile: Types.PlayerProfile)
		PetsService.SyncVisualsAndClient(player)
		player.CharacterAdded:Connect(function()
			task.wait(0.25)
			PetsService.SyncVisualsAndClient(player)
		end)
	end)

	Net.OnServerEvent(Net.ClientToServer.HatchEgg, function(player: Player, rawEggId: any)
		if type(rawEggId) == "string" then
			PetsService.HandleHatchEgg(player, rawEggId)
		end
	end)
	Net.OnServerEvent(Net.ClientToServer.EquipPet, function(player: Player, rawUid: any)
		if type(rawUid) == "string" then
			handleEquipPet(player, rawUid)
		end
	end)
	Net.OnServerEvent(Net.ClientToServer.UnequipPet, function(player: Player, rawUid: any)
		if type(rawUid) == "string" then
			handleUnequipPet(player, rawUid)
		end
	end)
	Net.OnServerEvent(Net.ClientToServer.EquipBestPets, function(player: Player)
		handleEquipBest(player)
	end)
	Net.OnServerEvent(Net.ClientToServer.DeletePet, function(player: Player, rawUid: any)
		if type(rawUid) == "string" then
			handleDeletePet(player, rawUid)
		end
	end)
end

return PetsService
