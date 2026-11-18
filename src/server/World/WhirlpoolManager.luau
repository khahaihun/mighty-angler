--!strict
-- WhirlpoolManager.luau: Quan ly Xoay Nuoc Ca Hiem (Ocean Whirlpools) noi ngau nhien tren bien (+2x Luck & Boss)

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local IslandsRegistry = require(Shared:WaitForChild("Config"):WaitForChild("Islands"))

local PartFactory = require(script.Parent.PartFactory)

export type ActiveWhirlpool = {
	islandId: number,
	position: Vector3,
	radius: number,
	expiresAt: number,
	model: Model,
}

local WhirlpoolManager = {}

local WHIRLPOOL_RADIUS = 15.5
local WHIRLPOOL_DURATION_SEC = 135
local SPAWN_CYCLE_SEC = 95

local activeByIsland: { [number]: ActiveWhirlpool } = {}
local whirlpoolRoot: Folder? = nil

local function ensureFolder(): Folder
	local existing = whirlpoolRoot
	if existing and existing.Parent then
		return existing
	end
	local f = Instance.new("Folder")
	f.Name = "OceanWhirlpools"
	f.Parent = Workspace
	whirlpoolRoot = f
	return f
end

local function buildWhirlpoolModel(parent: Instance, centerPos: Vector3, accentColor: Color3): Model
	local m = Instance.new("Model")
	m.Name = "LuckyWhirlpool"
	m:SetAttribute("WhirlpoolCenter", centerPos)
	m.Parent = parent

	local outerRing = PartFactory.VerticalCylinder(
		m,
		"OuterSwirl",
		0.25,
		WHIRLPOOL_RADIUS * 1.85,
		CFrame.new(centerPos + Vector3.new(0, 0.15, 0)),
		Color3.fromRGB(116, 244, 255),
		Enum.Material.Neon,
		false,
		0.38
	)
	outerRing.CanQuery = false

	local innerRing = PartFactory.VerticalCylinder(
		m,
		"InnerSwirl",
		0.32,
		WHIRLPOOL_RADIUS * 1.05,
		CFrame.new(centerPos + Vector3.new(0, 0.22, 0)),
		accentColor,
		Enum.Material.Neon,
		false,
		0.24
	)
	innerRing.CanQuery = false
	m.PrimaryPart = innerRing

	-- Cot anh sang bao hieu tu xa giong Strange Whirlpool cua Fisch
	local beamPillar = PartFactory.VerticalCylinder(
		m,
		"SkyBeam",
		36,
		2.6,
		CFrame.new(centerPos + Vector3.new(0, 18, 0)),
		Color3.fromRGB(122, 248, 255),
		Enum.Material.Neon,
		false,
		0.76
	)
	beamPillar.CanQuery = false

	-- 4 bong ca boi vong tron duoi lan nuoc
	for i = 1, 4 do
		local ang = math.rad(i * 90)
		local fishShadow = PartFactory.Ball(
			m,
			"ShadowFish_" .. tostring(i),
			1.8,
			centerPos + Vector3.new(math.cos(ang) * 7.5, -0.8, math.sin(ang) * 7.5),
			Color3.fromRGB(24, 52, 82),
			Enum.Material.SmoothPlastic,
			false,
			0.25
		)
		fishShadow.Size = Vector3.new(1.1, 0.7, 2.8)
		fishShadow.CanQuery = false
	end

	local splash = Instance.new("ParticleEmitter")
	splash.Color = ColorSequence.new(Color3.fromRGB(196, 250, 255))
	splash.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1.8) })
	splash.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1) })
	splash.Lifetime = NumberRange.new(1.0, 1.8)
	splash.Rate = 18
	splash.Speed = NumberRange.new(3.5, 6.5)
	splash.Parent = innerRing

	PartFactory.AddBillboard(
		innerRing,
		"🌀 LUCKY WHIRLPOOL",
		"2x Total Luck & 2x Boss Weight!",
		Color3.fromRGB(118, 248, 255),
		5.4
	)

	return m
end

function WhirlpoolManager.ClearIslandWhirlpool(islandId: number)
	local existing = activeByIsland[islandId]
	if existing then
		if existing.model.Parent then
			existing.model:Destroy()
		end
		activeByIsland[islandId] = nil
	end
end

function WhirlpoolManager.SpawnOnIsland(islandId: number, announce: boolean?)
	local islandDef = IslandsRegistry.ById[islandId]
	if not islandDef then
		return
	end
	WhirlpoolManager.ClearIslandWhirlpool(islandId)

	local c = islandDef.centerPosition
	-- Chon vi tri de nhin va de quang phao toi tu mui Cau go & bo bien
	local sideSign = if math.random(1, 2) == 1 then 1 else -1
	local offsetX = sideSign * math.random(20, 42)
	local offsetZ = math.random(96, 136)
	local waterSurfaceY = c.Y - 0.35
	local worldPos = Vector3.new(c.X + offsetX, waterSurfaceY, c.Z + offsetZ)

	local model = buildWhirlpoolModel(ensureFolder(), worldPos, islandDef.theme.accentColor)
	activeByIsland[islandId] = {
		islandId = islandId,
		position = worldPos,
		radius = WHIRLPOOL_RADIUS,
		expiresAt = os.time() + WHIRLPOOL_DURATION_SEC,
		model = model,
	}

	if announce then
		Net.FireAllClients(Net.ServerToClient.Toast, {
			kind = "Info",
			text = string.format("🌀 A Lucky Whirlpool surfaced off %s!", islandDef.name),
		})
	end
end

function WhirlpoolManager.IsPointInWhirlpool(islandId: number, worldPos: Vector3): boolean
	local wp = activeByIsland[islandId]
	if not wp or os.time() >= wp.expiresAt then
		return false
	end
	local horiz = Vector3.new(worldPos.X - wp.position.X, 0, worldPos.Z - wp.position.Z).Magnitude
	return horiz <= wp.radius
end

function WhirlpoolManager.Init()
	ensureFolder()
	-- Khoi tao san xoay nuoc tren Dao 1 va 1 dao ngau nhien de nguoi choi vao thay ngay (chuyen dong ca bong chay tren Client de 0% ton bang thong!)
	WhirlpoolManager.SpawnOnIsland(1, false)
	if #IslandsRegistry.List >= 2 then
		WhirlpoolManager.SpawnOnIsland(2, false)
	end

	task.spawn(function()
		while true do
			task.wait(10)
			local now = os.time()
			for islId, wp in pairs(activeByIsland) do
				if now >= wp.expiresAt then
					WhirlpoolManager.ClearIslandWhirlpool(islId)
				end
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(SPAWN_CYCLE_SEC)
			-- Luon duy tri xoay nuoc luon phien tren Dao 1 va cac dao cao
			WhirlpoolManager.SpawnOnIsland(1, false)
			local pickId = math.random(2, math.max(2, #IslandsRegistry.List))
			WhirlpoolManager.SpawnOnIsland(pickId, true)
		end
	end)
end

return WhirlpoolManager
