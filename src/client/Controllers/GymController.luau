--!strict
-- GymController.luau: Phat hien dung tren may Gym, xu ly Click chuot tap ta, Hieu ung tia sang & Auto-Train

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local IslandsRegistry = require(Shared:WaitForChild("Config"):WaitForChild("Islands"))

local AnimationController = require(script.Parent.AnimationController)
local MinigameBar = require(script.Parent.Parent.UI.Panels.MinigameBar)

local GymController = {}

local localPlayer = Players.LocalPlayer
local canAutoTrainPerk = false
local autoTrainEnabled = false
local currentStationName: string? = nil
local currentIslandId = 1
local lastClickSentAt = 0

local stateListeners: { (string?, boolean) -> () } = {}
local repFeedbackListeners: { (number, string) -> () } = {}

local function notifyState()
	for _, cb in ipairs(stateListeners) do
		task.spawn(cb, currentStationName, autoTrainEnabled)
	end
end

function GymController.OnStateChanged(callback: (string?, boolean) -> ())
	table.insert(stateListeners, callback)
end

function GymController.OnRepFeedback(callback: (number, string) -> ())
	table.insert(repFeedbackListeners, callback)
end

function GymController.SetCurrentIsland(islandId: number)
	currentIslandId = islandId
end

function GymController.SetAutoTrainPerkAvailable(unlocked: boolean)
	canAutoTrainPerk = unlocked
	if not unlocked and autoTrainEnabled then
		autoTrainEnabled = false
		notifyState()
	end
end

function GymController.TriggerManualRep()
	local now = os.clock()
	if now - lastClickSentAt < GameConfig.GYM_MANUAL_COOLDOWN_SEC then
		return
	end
	lastClickSentAt = now
	Net.FireServer(Net.ClientToServer.GymRep)
end

function GymController.ToggleAutoTrain()
	if not canAutoTrainPerk then
		Net.FireServer(Net.ClientToServer.SetAutoTrain, true)
		return
	end
	autoTrainEnabled = not autoTrainEnabled
	Net.FireServer(Net.ClientToServer.SetAutoTrain, autoTrainEnabled)
	notifyState()
end

local function spawnWorkoutSpark()
	local char = localPlayer.Character
	local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
	if not (root and root:IsA("BasePart")) then
		return
	end

	local ring = Instance.new("Part")
	ring.Name = "GymPulse"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.15, 2.2, 2.2)
	ring.CFrame = CFrame.new(root.Position - Vector3.new(0, 2.5, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Color = Color3.fromRGB(255, 148, 68)
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.25
	ring.Anchored = true
	ring.CanCollide = false
	ring.Parent = Workspace

	TweenService:Create(
		ring,
		TweenInfo.new(0.42, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.new(0.08, 6.8, 6.8), Transparency = 1 }
	):Play()
	Debris:AddItem(ring, 0.5)
end

function GymController.Init()
	Net.OnClientEvent(Net.ServerToClient.GymRepFeedback, function(payload: any)
		if type(payload) ~= "table" then
			return
		end
		local stType = tostring(payload.stationType or "Dumbbells")
		local gained = tonumber(payload.gained) or 1
		local stName = tostring(payload.stationName or "Gym")

		AnimationController.PlayGymRep(stType)
		spawnWorkoutSpark()

		for _, cb in ipairs(repFeedbackListeners) do
			task.spawn(cb, gained, stName)
		end
	end)

	-- Kiem tra vi tri nhan vat co dang dung tren may Gym nao khong
	local checkAcc = 0
	RunService.Heartbeat:Connect(function(dt: number)
		checkAcc += dt
		if checkAcc < 0.2 then
			return
		end
		checkAcc = 0

		local char = localPlayer.Character
		local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
		local foundName: string? = nil

		if root and root:IsA("BasePart") then
			local islandDef = IslandsRegistry.Get(currentIslandId)
			local pPos = root.Position
			for _, st in ipairs(islandDef.gymStations) do
				local stPos = islandDef.centerPosition + st.offset
				local horiz = Vector3.new(pPos.X - stPos.X, 0, pPos.Z - stPos.Z).Magnitude
				if horiz <= GameConfig.GYM_STATION_RADIUS and math.abs(pPos.Y - stPos.Y) <= 10 then
					foundName = st.name
					break
				end
			end
		end

		if foundName ~= currentStationName then
			currentStationName = foundName
			notifyState()
		end
	end)

	-- Bam chuot trai / cham man hinh khi dang dung tren may Gym se tap 1 nhip
	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed or MinigameBar.IsOpen() then
			return
		end
		if currentStationName == nil then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			GymController.TriggerManualRep()
		end
	end)
end

return GymController
