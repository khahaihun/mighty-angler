--!strict
-- PromptController.luau: Xu ly tuong tac ProximityPrompt voi 4 NPC Hoi thoai, Be Enchant, May Gym, Trung (Mo Bang %) & Cong Dao

local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

export type PromptCallbacks = {
	OpenPanel: (panelKey: string) -> (),
	OpenNpcDialogue: (role: string) -> (),
	OpenEnchantAltar: () -> (),
	OpenEggHatchPreview: (eggId: string) -> (),
	TriggerGymRep: () -> (),
}

local PromptController = {}

function PromptController.Init(callbacks: PromptCallbacks)
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, _player: Player)
		local kind = prompt:GetAttribute("PromptKind")
		if kind == "NpcMerchant" then
			callbacks.OpenNpcDialogue("Merchant")
		elseif kind == "NpcShop" then
			callbacks.OpenNpcDialogue("Shop")
		elseif kind == "NpcCollector" then
			callbacks.OpenNpcDialogue("Collector")
		elseif kind == "NpcCoach" then
			callbacks.OpenNpcDialogue("Coach")
		elseif kind == "OpenEnchantAltar" then
			callbacks.OpenEnchantAltar()
		elseif kind == "SellAll" then
			Net.FireServer(Net.ClientToServer.SellAllFish)
		elseif kind == "OpenShop" then
			callbacks.OpenPanel("Shop")
		elseif kind == "GymFocus" then
			callbacks.TriggerGymRep()
		elseif kind == "HatchEgg" then
			local eggId = prompt:GetAttribute("EggId")
			if type(eggId) == "string" then
				callbacks.OpenEggHatchPreview(eggId)
			else
				callbacks.OpenPanel("Pets")
			end
		elseif kind == "PortalNext" then
			local targetId = prompt:GetAttribute("TargetIslandId")
			if type(targetId) == "number" then
				Net.FireServer(Net.ClientToServer.UnlockIsland, targetId)
			end
		elseif kind == "PortalTravel" then
			local targetId = prompt:GetAttribute("TargetIslandId")
			if type(targetId) == "number" then
				Net.FireServer(Net.ClientToServer.TravelIsland, targetId)
			end
		end
	end)
end

return PromptController
