--!strict
-- DevTestService.luau: Bang quyen nang test nhanh cho Chu Game — KHOA CUNG 100% chi hoat dong trong Roblox Studio

local LogService = game:GetService("LogService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local IslandsRegistry = require(Shared:WaitForChild("Config"):WaitForChild("Islands"))

local DataService = require(script.Parent.DataService)
local PerkService = require(script.Parent.PerkService)
local CurrencyService = require(script.Parent.CurrencyService)
local ShopAndItemsService = require(script.Parent.ShopAndItemsService)
local FishingService = require(script.Parent.FishingService)
local IslandService = require(script.Parent.IslandService)
local PetsService = require(script.Parent.PetsService)
local RodVisuals = require(script.Parent.Parent.World.RodVisuals)

local DevTestService = {}

local triggerEventHook: (() -> ())? = nil

function DevTestService.SetTriggerEventHook(hook: () -> ())
	triggerEventHook = hook
end

function DevTestService.Init()
	if RunService:IsStudio() then
		local reportingErr = false
		LogService.MessageOut:Connect(function(message: string, messageType: Enum.MessageType)
			if messageType == Enum.MessageType.MessageError and not reportingErr then
				reportingErr = true
				pcall(function()
					Net.FireAllClients(Net.ServerToClient.Toast, {
						kind = "Error",
						text = "⚠️ SERVER ERROR: " .. string.sub(message, 1, 120),
					})
				end)
				reportingErr = false
			end
		end)
	end

	Net.OnServerEvent(Net.ClientToServer.DevAction, function(player: Player, rawAction: any)
		-- CHOT AN TOAN TUYET DOI: Nguoi choi ngoai Server Publish khong bao gio goi duoc!
		if not RunService:IsStudio() then
			return
		end
		if type(rawAction) ~= "string" then
			return
		end
		local profile = DataService.Get(player)
		if not profile then
			return
		end

		if rawAction == "AddGold10K" then
			CurrencyService.AddGold(player, 10000, true)
		elseif rawAction == "AddGold2M" then
			CurrencyService.AddGold(player, 2000000, true)
		elseif rawAction == "AddStrength50K" then
			CurrencyService.AddStrength(player, 50000, false, true)
		elseif rawAction == "AddStrength5M" then
			CurrencyService.AddStrength(player, 5000000, false, true)
		elseif rawAction == "AddGems500" then
			profile.enchantRelics += 3
			CurrencyService.AddGems(player, 500, true)
			ShopAndItemsService.GrantPotion(player, "lucky_elixir_s", 1, false)
			ShopAndItemsService.GrantPotion(player, "titan_brew_s", 1, false)
		elseif rawAction == "ForceRare" then
			FishingService.SetForcedRarityForDev(player, "Rare")
			Net.FireClient(player, Net.ServerToClient.Toast, {
				kind = "Info",
				text = "[DEV] Next cast guaranteed RARE fish!",
			})
		elseif rawAction == "ForceBoss" then
			FishingService.SetForcedRarityForDev(player, "Boss")
			Net.FireClient(player, Net.ServerToClient.Toast, {
				kind = "Epic",
				text = "[DEV] Next cast guaranteed ISLAND BOSS!",
			})
		elseif rawAction == "UnlockAllIslands" then
			for _, isl in ipairs(IslandsRegistry.List) do
				profile.unlockedIslands[tostring(isl.id)] = true
			end
			DataService.MarkDirty(player)
			DataService.PushFullSnapshot(player)
			Net.FireClient(player, Net.ServerToClient.Toast, {
				kind = "Success",
				text = "[DEV] Unlocked all registered Islands!",
			})
		elseif rawAction == "GrantAllPasses" then
			PerkService.GrantAllPassesInStudio(player)
			Net.FireClient(player, Net.ServerToClient.Toast, {
				kind = "Success",
				text = "[DEV] Enabled all 4 Gamepasses for testing!",
			})
		elseif rawAction == "ToggleFreeSim" then
			PerkService.ToggleDevFreeMode(player)
			Net.FireClient(player, Net.ServerToClient.Toast, {
				kind = "Info",
				text = "[DEV] Toggled Free-Player Perk Lock simulation!",
			})
		elseif rawAction == "TriggerEvent" then
			if triggerEventHook then
				triggerEventHook()
			else
				Net.FireClient(player, Net.ServerToClient.Toast, {
					kind = "Info",
					text = "[DEV] Server Events activate in Milestone 3!",
				})
			end
		elseif rawAction == "ResetSave" then
			FishingService.CancelSession(player, true, "ManualCancel")
			local fresh, saveRes = DataService.ResetProfileForDev(player)
			local resetInfo = { ramApplied = fresh ~= nil, persistent = saveRes, saveSeq = if fresh then fresh.saveSeq else 0 }
			if not fresh then
				Net.FireClient(player, Net.ServerToClient.Toast, {
					kind = "Error", text = "[DEV] Reset NOT applied (" .. saveRes .. ").", devReset = resetInfo,
				})
				return
			end
			IslandService.TeleportCharacterToIsland(player, 1)
			RodVisuals.EquipRodOnCharacter(player, "Twig")
			PetsService.SyncVisualsAndClient(player)
			ShopAndItemsService.PushInventory(player)
			CurrencyService.PushCurrencies(player)
			local text = if saveRes == "Saved" then "[DEV] RAM reset applied. Persistent save confirmed."
				elseif saveRes == "RAMOnly" then "[DEV] RAM reset applied. RAM-only mode; no persistent store."
				else "[DEV] RAM reset applied. Persistent save NOT confirmed (" .. saveRes .. ")."
			Net.FireClient(player, Net.ServerToClient.Toast, {
				kind = if saveRes == "Saved" then "Success" elseif saveRes == "RAMOnly" then "Info" else "Error",
				text = text, devReset = resetInfo,
			})
		end
	end)
end

return DevTestService
