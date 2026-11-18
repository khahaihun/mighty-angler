--!strict
-- RodVisuals.luau: Gan Can cau 3D Chi Tiet Cao (RodAndWeightBuilder) + Day cau Beam + Phao noi & Nay dat

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RodsConfig = require(Shared:WaitForChild("Config"):WaitForChild("RodsConfig"))
local RodAndWeightBuilder = require(Shared:WaitForChild("ModelBuilders"):WaitForChild("RodAndWeightBuilder"))

local RodVisuals = {}

local activeBobbers: { [Player]: Part } = {}
local activeBeams: { [Player]: Beam } = {}

local function getRightHandPart(character: Model): BasePart?
	local r15 = character:FindFirstChild("RightHand")
	if r15 and r15:IsA("BasePart") then
		return r15
	end
	local r6 = character:FindFirstChild("Right Arm")
	if r6 and r6:IsA("BasePart") then
		return r6
	end
	return nil
end

function RodVisuals.EquipRodOnCharacter(player: Player, rodId: string)
	local character = player.Character
	if not character then
		return
	end
	local old = character:FindFirstChild("EquippedFishingRod")
	if old then
		old:Destroy()
	end
	local oldWeights = character:FindFirstChild("ActiveGymWeights")
	if oldWeights then
		oldWeights:Destroy()
	end

	local hand = getRightHandPart(character)
	if not hand then
		return
	end

	local rodDef = RodsConfig.Get(rodId)
	local rodModel, handlePart, _ = RodAndWeightBuilder.BuildCharacterRod(rodDef)
	rodModel.Name = "EquippedFishingRod"

	local isR6 = (hand.Name == "Right Arm")
	local gripOffset = if isR6
		then CFrame.new(0, -0.95, -0.4) * CFrame.Angles(math.rad(-25), 0, 0)
		else CFrame.new(0, -0.15, -0.45) * CFrame.Angles(math.rad(-20), 0, 0)

	local targetGripCf = hand.CFrame * gripOffset
	local invOld = handlePart.CFrame:Inverse()
	for _, d in ipairs(rodModel:GetDescendants()) do
		if d:IsA("BasePart") and d ~= handlePart then
			d.CFrame = targetGripCf * (invOld * d.CFrame)
		end
	end
	handlePart.CFrame = targetGripCf
	rodModel.Parent = character

	local handWeld = Instance.new("WeldConstraint")
	handWeld.Name = "HandWeld"
	handWeld.Part0 = hand
	handWeld.Part1 = handlePart
	handWeld.Parent = handlePart
end

function RodVisuals.UnequipRodFromCharacter(player: Player)
	RodVisuals.ClearBobber(player)
	local character = player.Character
	if not character then
		return
	end
	local old = character:FindFirstChild("EquippedFishingRod")
	if old then
		old:Destroy()
	end
end

function RodVisuals.ClearBobber(player: Player)
	local bob = activeBobbers[player]
	if bob then
		bob:Destroy()
		activeBobbers[player] = nil
	end
	local beam = activeBeams[player]
	if beam then
		beam:Destroy()
		activeBeams[player] = nil
	end
end

function RodVisuals.SpawnRipple(waterPos: Vector3, color: Color3)
	local ring = Instance.new("Part")
	ring.Name = "WaterRipple"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.15, 1.2, 1.2)
	ring.CFrame = CFrame.new(waterPos + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Color = color
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.25
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.Parent = Workspace

	TweenService:Create(ring, TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.08, 6.2, 6.2),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ring, 0.75)
end

function RodVisuals.SpawnCastBobber(player: Player, waterTargetPos: Vector3)
	RodVisuals.ClearBobber(player)
	local character = player.Character
	if not character then
		return
	end
	local rodModel = character:FindFirstChild("EquippedFishingRod")
	local tipAtt = if rodModel then rodModel:FindFirstChild("RodTipAttachment", true) else nil

	local bobber = Instance.new("Part")
	bobber.Name = "FishingBobber_" .. player.Name
	bobber.Shape = Enum.PartType.Ball
	bobber.Size = Vector3.new(1.15, 1.15, 1.15)
	bobber.Position = waterTargetPos + Vector3.new(0, 0.35, 0)
	bobber.Color = Color3.fromRGB(255, 76, 76)
	bobber.Material = Enum.Material.Neon
	bobber.Anchored = true
	bobber.CanCollide = false
	bobber.CanQuery = false
	bobber.Parent = Workspace

	local lineAtt = Instance.new("Attachment")
	lineAtt.Name = "BobberLineAtt"
	lineAtt.Position = Vector3.new(0, 0.45, 0)
	lineAtt.Parent = bobber

	if tipAtt and tipAtt:IsA("Attachment") then
		local beam = Instance.new("Beam")
		beam.Name = "FishingLineBeam"
		beam.Attachment0 = tipAtt
		beam.Attachment1 = lineAtt
		beam.Width0 = 0.07
		beam.Width1 = 0.05
		beam.FaceCamera = true
		beam.Color = ColorSequence.new(Color3.fromRGB(230, 246, 255))
		beam.Transparency = NumberSequence.new(0.15)
		beam.CurveSize0 = -1.6
		beam.Segments = 14
		beam.Parent = bobber
		activeBeams[player] = beam
	end

	activeBobbers[player] = bobber
	RodVisuals.SpawnRipple(waterTargetPos, Color3.fromRGB(165, 245, 255))
end

function RodVisuals.PlayLandBounce(player: Player, hitPos: Vector3)
	RodVisuals.ClearBobber(player)
	local character = player.Character
	if not character then
		return
	end
	local rodModel = character:FindFirstChild("EquippedFishingRod")
	local tipAtt = if rodModel then rodModel:FindFirstChild("RodTipAttachment", true) else nil

	local bobber = Instance.new("Part")
	bobber.Shape = Enum.PartType.Ball
	bobber.Size = Vector3.new(1.05, 1.05, 1.05)
	bobber.Position = hitPos + Vector3.new(0, 0.55, 0)
	bobber.Color = Color3.fromRGB(255, 146, 68)
	bobber.Material = Enum.Material.Neon
	bobber.Anchored = true
	bobber.CanCollide = false
	bobber.CanQuery = false
	bobber.Parent = Workspace

	local lineAtt = Instance.new("Attachment")
	lineAtt.Parent = bobber
	if tipAtt and tipAtt:IsA("Attachment") then
		local beam = Instance.new("Beam")
		beam.Attachment0 = tipAtt
		beam.Attachment1 = lineAtt
		beam.Width0 = 0.06
		beam.Width1 = 0.05
		beam.FaceCamera = true
		beam.Color = ColorSequence.new(Color3.fromRGB(255, 212, 168))
		beam.Parent = bobber
	end

	local dust = Instance.new("Part")
	dust.Shape = Enum.PartType.Cylinder
	dust.Size = Vector3.new(0.18, 1.1, 1.1)
	dust.CFrame = CFrame.new(hitPos + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.rad(90))
	dust.Color = Color3.fromRGB(224, 204, 168)
	dust.Material = Enum.Material.SmoothPlastic
	dust.Transparency = 0.25
	dust.Anchored = true
	dust.CanCollide = false
	dust.CanQuery = false
	dust.Parent = Workspace
	TweenService:Create(dust, TweenInfo.new(0.42, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.06, 4.4, 4.4),
		Transparency = 1,
	}):Play()
	Debris:AddItem(dust, 0.5)

	task.spawn(function()
		TweenService:Create(bobber, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true), { Position = hitPos + Vector3.new(0, 2.35, 0) }):Play()
		task.wait(0.28)
		if bobber.Parent then
			TweenService:Create(bobber, TweenInfo.new(0.10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true), { Position = hitPos + Vector3.new(0, 1.25, 0) }):Play()
			task.wait(0.22)
		end
		if bobber.Parent then bobber:Destroy() end
	end)
	Debris:AddItem(bobber, 0.75)
end

function RodVisuals.PlayBiteSplash(player: Player, isRareOrBoss: boolean)
	local bob = activeBobbers[player]
	if not bob then return end
	local splashCol = if isRareOrBoss then Color3.fromRGB(255, 206, 64) else Color3.fromRGB(120, 245, 255)
	RodVisuals.SpawnRipple(bob.Position, splashCol)
	TweenService:Create(bob, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 1, true), { Position = bob.Position - Vector3.new(0, 0.75, 0) }):Play()
	local beam = activeBeams[player]
	if beam then
		beam.CurveSize0 = if isRareOrBoss then -3.2 else -2.1 -- Day cau cang cong manh khi ca can!
	end
end

Players.PlayerRemoving:Connect(RodVisuals.ClearBobber)

return RodVisuals
