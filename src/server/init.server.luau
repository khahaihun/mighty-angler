--!strict
-- init.server.luau: Diem khoi dong Server — dung the gioi va khoi tao Services

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

local WorldBuilder = require(script.World.WorldBuilder)

-- 1. Khoi tao mang RemoteEvent va dung canh quan the gioi
Net.InitServer()
WorldBuilder.BuildAll()
