--!strict
-- ClientStateController.luau: Lang nghe dong bo toan bo Remote S2C cap nhat HUD, Hotbar, Enchant, Playtime & Panels

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))
local BaitConfig = require(Shared:WaitForChild("Config"):WaitForChild("BaitConfig"))
local PotionsConfig = require(Shared:WaitForChild("Config"):WaitForChild("PotionsConfig"))

local FishingController = require(script.Parent.FishingController)
local GymController = require(script.Parent.GymController)
local SoundAndFxController = require(script.Parent.SoundAndFxController)

local HotbarAndBaitUi = require(script.Parent.Parent.UI.Components.HotbarAndBaitUi)
local HudPanel = require(script.Parent.Parent.UI.Panels.HudPanel)
local BagPanel = require(script.Parent.Parent.UI.Panels.BagPanel)
local ShopPanel = require(script.Parent.Parent.UI.Panels.ShopPanel)
local PetsPanel = require(script.Parent.Parent.UI.Panels.PetsPanel)
local EnchantAndBountyModal = require(script.Parent.Parent.UI.Panels.EnchantAndBountyModal)
local PlaytimeAndSettingsModal = require(script.Parent.Parent.UI.Panels.PlaytimeAndSettingsModal)

local ClientStateController = {}

local goldCache = 0
local gemsCache = 0
local strengthCache = 0
local rodIdCache = "Twig"
local islandCache = 1
local ownedRodsCache: { [string]: boolean } = { Twig = true }
local rodEnchantsCache: { [string]: string } = {}
local relicsCache = 0
local unlockedIslandsCache: { [string]: boolean } = { ["1"] = true }
local fishBagCache: { any } = {}
local gearLvCache = 0

local activeEventTextCache = ""
local activeBuffTextCache = ""
local activePotionsCache: any = {}
local activeBaitCache: any = nil
local baitMapCache: any = {}
local serverClockOffset = 0

local function refreshTopBuffLine()
	if activeEventTextCache ~= "" and activeBuffTextCache ~= "" then
		HudPanel.UpdateEventBanner(activeEventTextCache .. "  •  " .. activeBuffTextCache)
	elseif activeEventTextCache ~= "" then
		HudPanel.UpdateEventBanner(activeEventTextCache)
	else
		HudPanel.UpdateEventBanner(activeBuffTextCache)
	end
end

local function computeActiveItemBuffSummary(activePotions: any, activeBait: any, baitMap: any, serverNow: number?): string
	local parts: { string } = {}
	if type(activeBait) == "string" and activeBait ~= "" then
		local bDef = BaitConfig.ById[activeBait]
		local cnt = if type(baitMap) == "table" then (tonumber(baitMap[activeBait]) or 0) else 0
		if bDef and cnt > 0 then
			table.insert(parts, string.format("🪱 %s (%d)", bDef.name, cnt))
		end
	end
	local now = serverNow or os.time()
	if type(activePotions) == "table" then
		for _, st in pairs(activePotions) do
			if type(st) == "table" and (tonumber(st.expiresAt) or 0) > now then
				local pDef = PotionsConfig.ById[tostring(st.potionId or "")]
				if pDef then
					local rem = math.max(0, (tonumber(st.expiresAt) or 0) - now)
					table.insert(parts, string.format("🧪 %s (%s)", pDef.name, Util.FormatDuration(rem)))
				end
			end
		end
	end
	return table.concat(parts, " | ")
end

local function syncEnchantModal()
	EnchantAndBountyModal.SyncState(
		gemsCache,
		rodIdCache,
		ownedRodsCache,
		rodEnchantsCache,
		relicsCache,
		unlockedIslandsCache,
		fishBagCache
	)
end

function ClientStateController.Init(progressModRef: any)
	Net.OnClientEvent(Net.ServerToClient.StateSnapshot, function(snap: any)
		if type(snap) ~= "table" or type(snap.profile) ~= "table" then
			return
		end
		local p = snap.profile
		goldCache = tonumber(p.gold) or 0
		gemsCache = tonumber(p.gems) or 0
		strengthCache = tonumber(p.strength) or 0
		rodIdCache = tostring(p.rodId or "Twig")
		islandCache = tonumber(p.currentIsland) or 1
		ownedRodsCache = if type(p.ownedRods) == "table" then p.ownedRods else { Twig = true }
		rodEnchantsCache = if type(p.rodEnchants) == "table" then p.rodEnchants else {}
		relicsCache = tonumber(p.enchantRelics) or 0
		unlockedIslandsCache = if type(p.unlockedIslands) == "table" then p.unlockedIslands else { ["1"] = true }
		gearLvCache = tonumber(p.gymGearLevel) or 0

		HudPanel.UpdateCurrencies(goldCache, gemsCache, strengthCache)
		HudPanel.UpdateRodAndIsland(rodIdCache, islandCache, ownedRodsCache, rodEnchantsCache)
		GymController.SetCurrentIsland(islandCache)

		fishBagCache = if type(p.fishBag) == "table" then p.fishBag else {}
		HudPanel.UpdateBagCount(#fishBagCache)
		BagPanel.UpdateFishBag(fishBagCache)
		BagPanel.UpdateItems(p.potions or {}, p.bait or {}, p.activeBait)
		HotbarAndBaitUi.SyncBag(fishBagCache)
		HotbarAndBaitUi.SyncHotbar(tonumber(p.equippedHotbarSlot) or 1, p.pinnedFishUids or {}, rodIdCache)
		HotbarAndBaitUi.SyncBait(p.bait or {}, p.activeBait)

		ShopPanel.SyncState(goldCache, strengthCache, rodIdCache, ownedRodsCache, gearLvCache)
		PetsPanel.SyncFromProfile(p)
		syncEnchantModal()

		PlaytimeAndSettingsModal.SyncPlaytime(tonumber(p.playtimeTodaySec) or 0, p.playtimeClaimedToday or {})
		local lockRare = (p.autoLockRare ~= false)
		local lockMut = (p.autoLockMutated ~= false)
		local low = (p.lowGfx == true)
		local mute = (p.muteSfx == true)
		PlaytimeAndSettingsModal.SyncSettings(lockRare, lockMut, low, mute)
		SoundAndFxController.SetClientPrefs(mute, low)

		activePotionsCache = p.activePotions or {}
		activeBaitCache = p.activeBait
		baitMapCache = p.bait or {}
		if type(snap.serverNow) == "number" then
			serverClockOffset = snap.serverNow - os.time()
		end
		activeBuffTextCache = computeActiveItemBuffSummary(activePotionsCache, activeBaitCache, baitMapCache, os.time() + serverClockOffset)
		refreshTopBuffLine()

		if progressModRef then
			progressModRef.SyncFromProfile(p)
		end
	end)

	Net.OnClientEvent(Net.ServerToClient.CurrencyUpdated, function(payload: any)
		if type(payload) ~= "table" then
			return
		end
		goldCache = tonumber(payload.gold) or goldCache
		gemsCache = tonumber(payload.gems) or gemsCache
		strengthCache = tonumber(payload.strength) or strengthCache
		HudPanel.UpdateCurrencies(goldCache, gemsCache, strengthCache)
		ShopPanel.SyncState(goldCache, strengthCache, rodIdCache, ownedRodsCache, gearLvCache)
		syncEnchantModal()
		if progressModRef then
			progressModRef.SyncCurrencies(goldCache, gemsCache, strengthCache, tonumber(payload.rebirths) or 0)
		end
	end)

	Net.OnClientEvent(Net.ServerToClient.BagUpdated, function(payload: any)
		if type(payload) == "table" and type(payload.fishBag) == "table" then
			fishBagCache = payload.fishBag
			HudPanel.UpdateBagCount(#fishBagCache)
			BagPanel.UpdateFishBag(fishBagCache)
			HotbarAndBaitUi.SyncBag(fishBagCache)
			syncEnchantModal()
			if progressModRef then
				progressModRef.SyncBagAndHotbar(fishBagCache, nil)
			end
		end
	end)

	Net.OnClientEvent(Net.ServerToClient.HotbarUpdated, function(payload: any)
		if type(payload) == "table" then
			local slot = tonumber(payload.equippedSlot) or 1
			local pinned = if type(payload.pinnedFishUids) == "table" then payload.pinnedFishUids else {}
			rodIdCache = tostring(payload.rodId or rodIdCache)
			HotbarAndBaitUi.SyncHotbar(slot, pinned, rodIdCache)
			if progressModRef then
				progressModRef.SyncBagAndHotbar(nil, pinned)
			end
		end
	end)

	Net.OnClientEvent(Net.ServerToClient.InventoryUpdated, function(payload: any)
		if type(payload) ~= "table" then
			return
		end
		rodIdCache = tostring(payload.rodId or rodIdCache)
		ownedRodsCache = if type(payload.ownedRods) == "table" then payload.ownedRods else ownedRodsCache
		rodEnchantsCache = if type(payload.rodEnchants) == "table" then payload.rodEnchants else rodEnchantsCache
		relicsCache = tonumber(payload.enchantRelics) or relicsCache
		gearLvCache = tonumber(payload.gymGearLevel) or gearLvCache

		HudPanel.UpdateRodAndIsland(rodIdCache, islandCache, ownedRodsCache, rodEnchantsCache)
		BagPanel.UpdateItems(payload.potions or {}, payload.bait or {}, payload.activeBait)
		HotbarAndBaitUi.SyncBait(payload.bait or {}, payload.activeBait)
		ShopPanel.SyncState(goldCache, strengthCache, rodIdCache, ownedRodsCache, gearLvCache)
		syncEnchantModal()

		activePotionsCache = payload.activePotions or {}
		activeBaitCache = payload.activeBait
		baitMapCache = payload.bait or {}
		if type(payload.serverNow) == "number" then
			serverClockOffset = payload.serverNow - os.time()
		end
		activeBuffTextCache = computeActiveItemBuffSummary(activePotionsCache, activeBaitCache, baitMapCache, os.time() + serverClockOffset)
		refreshTopBuffLine()
	end)

	Net.OnClientEvent(Net.ServerToClient.EnchantAndRelicsUpdated, function(payload: any)
		if type(payload) == "table" then
			rodEnchantsCache = if type(payload.rodEnchants) == "table" then payload.rodEnchants else rodEnchantsCache
			relicsCache = tonumber(payload.enchantRelics) or relicsCache
			HudPanel.UpdateRodAndIsland(rodIdCache, islandCache, ownedRodsCache, rodEnchantsCache)
			syncEnchantModal()
		end
	end)

	Net.OnClientEvent(Net.ServerToClient.PlaytimeUpdated, function(payload: any)
		if type(payload) == "table" then
			PlaytimeAndSettingsModal.SyncPlaytime(tonumber(payload.playtimeTodaySec) or 0, payload.playtimeClaimedToday)
		end
	end)

	Net.OnClientEvent(Net.ServerToClient.SettingsUpdated, function(payload: any)
		if type(payload) == "table" then
			local lockRare = (payload.autoLockRare ~= false)
			local lockMut = (payload.autoLockMutated ~= false)
			local low = (payload.lowGfx == true)
			local mute = (payload.muteSfx == true)
			PlaytimeAndSettingsModal.SyncSettings(lockRare, lockMut, low, mute)
			SoundAndFxController.SetClientPrefs(mute, low)
		end
	end)

	Net.OnClientEvent(Net.ServerToClient.PerksUpdated, function(payload: any)
		if type(payload) ~= "table" then
			return
		end
		local canTrain = payload.canAutoTrain == true
		local canFishPro = payload.autoFish == true
		GymController.SetAutoTrainPerkAvailable(canTrain)
		FishingController.SetAutoFishPerkAvailable(canFishPro)
		HudPanel.UpdatePerks(canTrain, canFishPro)
		ShopPanel.SyncPasses(payload)
	end)

	Net.OnClientEvent(Net.ServerToClient.PetsUpdated, PetsPanel.SyncPayload)
	Net.OnClientEvent(Net.ServerToClient.EggHatched, function(payload: any)
		if type(payload) == "table" then
			SoundAndFxController.PlaySfx("CatchRare")
			SoundAndFxController.PunchCamera(1.6)
		end
	end)

	Net.OnClientEvent(Net.ServerToClient.ProgressionUpdated, function(payload: any)
		if progressModRef and type(payload) == "table" then
			progressModRef.SyncPayload(payload)
		end
	end)

	Net.OnClientEvent(Net.ServerToClient.IslandChanged, function(payload: any)
		if type(payload) == "table" then
			islandCache = tonumber(payload.islandId) or islandCache
			if type(payload.unlockedIslands) == "table" then
				unlockedIslandsCache = payload.unlockedIslands
			end
			HudPanel.UpdateRodAndIsland(rodIdCache, islandCache, ownedRodsCache, rodEnchantsCache)
			GymController.SetCurrentIsland(islandCache)
			syncEnchantModal()
			if progressModRef and type(payload.unlockedIslands) == "table" then
				progressModRef.SyncIslands(islandCache, payload.unlockedIslands)
			end
		end
	end)

	Net.OnClientEvent(Net.ServerToClient.ServerEventChanged, function(payload: any)
		if type(payload) == "table" then
			activeEventTextCache = tostring(payload.bannerText or "")
			refreshTopBuffLine()
		end
	end)

	task.spawn(function()
		while true do
			task.wait(1)
			local nextText = computeActiveItemBuffSummary(activePotionsCache, activeBaitCache, baitMapCache, os.time() + serverClockOffset)
			if nextText ~= activeBuffTextCache then
				activeBuffTextCache = nextText
				refreshTopBuffLine()
			end
		end
	end)
end

return ClientStateController
