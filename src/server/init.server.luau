--!strict
-- init.server.luau: Diem khoi dong Server — dung the gioi va khoi tao Services

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

local WorldBuilder = require(script.World.WorldBuilder)
local DataService = require(script.Services.DataService)
local PerkService = require(script.Services.PerkService)
local CurrencyService = require(script.Services.CurrencyService)
local ShopAndItemsService = require(script.Services.ShopAndItemsService)
local FishingService = require(script.Services.FishingService)
local GymService = require(script.Services.GymService)
local DevTestService = require(script.Services.DevTestService)

-- 1. Khoi tao mang RemoteEvent va dung canh quan the gioi
Net.InitServer()
WorldBuilder.BuildAll()

-- 2. Khoi tao cac Service nen tang
DataService.Init()
PerkService.Init()
CurrencyService.Init()
ShopAndItemsService.Init()
FishingService.Init()
GymService.Init()
DevTestService.Init()
