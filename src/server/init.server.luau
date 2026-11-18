--!strict
-- init.server.luau: Diem khoi dong Server — dung the gioi va khoi tao Services

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))
local PotionsConfig = require(Shared:WaitForChild("Config"):WaitForChild("PotionsConfig"))
local PetsConfig = require(Shared:WaitForChild("Config"):WaitForChild("PetsConfig"))

local WorldBuilder = require(script.World.WorldBuilder)
local WhirlpoolManager = require(script.World.WhirlpoolManager)
local PlayerVisuals = require(script.World.PlayerVisuals)
local DataService = require(script.Services.DataService)
local PerkService = require(script.Services.PerkService)
local CurrencyService = require(script.Services.CurrencyService)
local ShopAndItemsService = require(script.Services.ShopAndItemsService)
local FishingService = require(script.Services.FishingService)
local GymService = require(script.Services.GymService)
local IslandService = require(script.Services.IslandService)
local PetsService = require(script.Services.PetsService)
local ProgressionService = require(script.Services.ProgressionService)
local EnchantAndBountyService = require(script.Services.EnchantAndBountyService)
local LiveOpsService = require(script.Services.LiveOpsService)
local DevTestService = require(script.Services.DevTestService)

-- 1. Khoi tao mang RemoteEvent va dung canh quan the gioi
Net.InitServer()
WorldBuilder.BuildAll()
WhirlpoolManager.Init()

-- 2. Khoi tao cac Service nen tang & Endgame
DataService.Init()
PerkService.Init()
CurrencyService.Init()
ShopAndItemsService.Init()
FishingService.Init()
GymService.Init()
IslandService.Init()
PetsService.Init()
ProgressionService.Init()
EnchantAndBountyService.Init()
PlayerVisuals.Init()
LiveOpsService.Init()
DevTestService.SetTriggerEventHook(LiveOpsService.TriggerNewServerEvent)
DevTestService.Init()

-- 3. Noi hook roi thuoc Potion / Pet hiem khi cau dinh Rare / Boss
FishingService.OnFishCaught(function(player: Player, fishDef, _mutation)
	if fishDef.rarity == "Boss" then
		if math.random() <= 0.35 then
			local pool = if fishDef.islandId >= 4 then PotionsConfig.LargeIds else PotionsConfig.SmallIds
			local pick = pool[math.random(1, #pool)]
			ShopAndItemsService.GrantPotion(player, pick, 1, true)
		end
		if math.random() <= 0.03 then
			local gemEgg = PetsConfig.GemEggsByIsland[fishDef.islandId]
			if gemEgg then
				local bonusPet = Util.PickWeighted(gemEgg.pets, function(p)
					return p.weightChance
				end)
				PetsService.AwardPetDirect(player, bonusPet, "Boss Drop")
			end
		end
	elseif (fishDef.rarity == "Rare" or fishDef.rarity == "Epic" or fishDef.rarity == "Legendary") and math.random() <= 0.08 then
		local pick = PotionsConfig.SmallIds[math.random(1, #PotionsConfig.SmallIds)]
		ShopAndItemsService.GrantPotion(player, pick, 1, true)
	end
end)
