--!strict
-- AnimationController.luau: Dien hoat toan than R15 & R6 (Than nguoi nghieng + 2 tay quang can, giat ca, cam ca khoe & tap ta)

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local AnimationController = {}

local localPlayer = Players.LocalPlayer
local savedC0s: { [Motor6D]: CFrame } = {}
local fishingHoldActive = false

local function findBodyMotors(character: Model): (Motor6D?, Motor6D?, Motor6D?)
	local rightUpper = character:FindFirstChild("RightUpperArm")
	local leftUpper = character:FindFirstChild("LeftUpperArm")
	local upperTorso = character:FindFirstChild("UpperTorso")
	local rMotor: Motor6D? = nil
	local lMotor: Motor6D? = nil
	local waistMotor: Motor6D? = nil

	if rightUpper then
		local m = rightUpper:FindFirstChild("RightShoulder")
		if m and m:IsA("Motor6D") then rMotor = m end
	end
	if leftUpper then
		local m = leftUpper:FindFirstChild("LeftShoulder")
		if m and m:IsA("Motor6D") then lMotor = m end
	end
	if upperTorso then
		local w = upperTorso:FindFirstChild("Waist")
		if w and w:IsA("Motor6D") then waistMotor = w end
	end
	if rMotor then
		return rMotor, lMotor, waistMotor
	end

	local torso = character:FindFirstChild("Torso")
	if torso then
		local rm = torso:FindFirstChild("Right Shoulder")
		local lm = torso:FindFirstChild("Left Shoulder")
		if rm and rm:IsA("Motor6D") then rMotor = rm end
		if lm and lm:IsA("Motor6D") then lMotor = lm end
	end
	return rMotor, lMotor, nil
end

local function getBaseC0(motor: Motor6D): CFrame
	local saved = savedC0s[motor]
	if saved then
		return saved
	end
	savedC0s[motor] = motor.C0
	return motor.C0
end

local function tweenMotor(motor: Motor6D?, offsetAngles: CFrame, duration: number)
	if not motor or not motor.Parent then
		return
	end
	local base = getBaseC0(motor)
	local isR6Shoulder = (motor.Name == "Right Shoulder" or motor.Name == "Left Shoulder")
	local adjusted = offsetAngles
	if isR6Shoulder then
		local rx, ry, rz = offsetAngles:ToEulerAnglesXYZ()
		local sign = if motor.Name == "Right Shoulder" then 1 else -1
		adjusted = CFrame.Angles(rz, ry, rx * sign)
	end
	TweenService:Create(motor, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		C0 = base * adjusted,
	}):Play()
end

local function applyFlexFishHoldIfActive(char: Model): boolean
	if char:GetAttribute("HoldingFlexFish") == true then
		local rMotor, lMotor, waist = findBodyMotors(char)
		tweenMotor(rMotor, CFrame.Angles(math.rad(82), math.rad(-18), math.rad(-14)), 0.22)
		tweenMotor(lMotor, CFrame.Angles(math.rad(82), math.rad(18), math.rad(14)), 0.22)
		tweenMotor(waist, CFrame.Angles(math.rad(-6), 0, 0), 0.22)
		return true
	end
	return false
end

function AnimationController.ResetArms(duration: number?)
	local char = localPlayer.Character
	if not char then
		return
	end
	if applyFlexFishHoldIfActive(char) then
		return
	end
	local rMotor, lMotor, waist = findBodyMotors(char)
	local dur = duration or 0.22
	tweenMotor(rMotor, CFrame.Angles(0, 0, 0), dur)
	tweenMotor(lMotor, CFrame.Angles(0, 0, 0), dur)
	tweenMotor(waist, CFrame.Angles(0, 0, 0), dur)
end

function AnimationController.PlayCast()
	local char = localPlayer.Character
	if not char then
		return
	end
	local rMotor, lMotor, waist = findBodyMotors(char)
	if not rMotor then
		return
	end
	fishingHoldActive = true

	task.spawn(function()
		-- Nghieng than nguoi ra sau lay da vung can
		tweenMotor(waist, CFrame.Angles(math.rad(14), math.rad(-12), 0), 0.15)
		tweenMotor(rMotor, CFrame.Angles(math.rad(142), 0, math.rad(12)), 0.15)
		tweenMotor(lMotor, CFrame.Angles(math.rad(35), 0, math.rad(-10)), 0.15)
		task.wait(0.16)
		-- Vut manh can cau ra phia truoc
		tweenMotor(waist, CFrame.Angles(math.rad(-12), math.rad(8), 0), 0.14)
		tweenMotor(rMotor, CFrame.Angles(math.rad(50), 0, math.rad(-6)), 0.14)
		task.wait(0.16)
		if fishingHoldActive then
			tweenMotor(waist, CFrame.Angles(math.rad(-4), 0, 0), 0.25)
			tweenMotor(rMotor, CFrame.Angles(math.rad(66), 0, math.rad(-5)), 0.25)
			tweenMotor(lMotor, CFrame.Angles(math.rad(42), math.rad(16), 0), 0.25)
		end
	end)
end

function AnimationController.PlayReelPull()
	local char = localPlayer.Character
	if not char then
		return
	end
	local rMotor, lMotor, waist = findBodyMotors(char)
	fishingHoldActive = false

	task.spawn(function()
		tweenMotor(waist, CFrame.Angles(math.rad(16), 0, 0), 0.16)
		tweenMotor(rMotor, CFrame.Angles(math.rad(124), 0, math.rad(-14)), 0.16)
		tweenMotor(lMotor, CFrame.Angles(math.rad(88), 0, math.rad(18)), 0.16)
		task.wait(0.24)
		AnimationController.ResetArms(0.26)
	end)
end

function AnimationController.StopFishingHold()
	fishingHoldActive = false
	AnimationController.ResetArms(0.22)
end

local gymToggleSide = false

function AnimationController.PlayGymRep(stationType: string)
	local char = localPlayer.Character
	if not char then
		return
	end
	local rMotor, lMotor, waist = findBodyMotors(char)
	gymToggleSide = not gymToggleSide

	task.spawn(function()
		if stationType == "Dumbbells" then
			if gymToggleSide then
				tweenMotor(rMotor, CFrame.Angles(math.rad(118), 0, math.rad(-8)), 0.15)
				tweenMotor(lMotor, CFrame.Angles(math.rad(26), 0, 0), 0.15)
				tweenMotor(waist, CFrame.Angles(math.rad(-5), math.rad(8), 0), 0.15)
			else
				tweenMotor(lMotor, CFrame.Angles(math.rad(118), 0, math.rad(8)), 0.15)
				tweenMotor(rMotor, CFrame.Angles(math.rad(26), 0, 0), 0.15)
				tweenMotor(waist, CFrame.Angles(math.rad(-5), math.rad(-8), 0), 0.15)
			end
			task.wait(0.22)
			AnimationController.ResetArms(0.20)
		elseif stationType == "Treadmill" then
			local fwd = if gymToggleSide then 72 else -38
			local bwd = if gymToggleSide then -38 else 72
			tweenMotor(waist, CFrame.Angles(math.rad(-10), 0, 0), 0.14)
			tweenMotor(rMotor, CFrame.Angles(math.rad(fwd), 0, 0), 0.14)
			tweenMotor(lMotor, CFrame.Angles(math.rad(bwd), 0, 0), 0.14)
			task.wait(0.20)
			AnimationController.ResetArms(0.20)
		else
			tweenMotor(waist, CFrame.Angles(math.rad(10), 0, 0), 0.16)
			tweenMotor(rMotor, CFrame.Angles(math.rad(138), 0, math.rad(-14)), 0.16)
			tweenMotor(lMotor, CFrame.Angles(math.rad(138), 0, math.rad(14)), 0.16)
			task.wait(0.22)
			tweenMotor(rMotor, CFrame.Angles(math.rad(58), 0, math.rad(-20)), 0.18)
			tweenMotor(lMotor, CFrame.Angles(math.rad(58), 0, math.rad(20)), 0.18)
			task.wait(0.18)
			AnimationController.ResetArms(0.22)
		end
	end)
end

local function bindCharacterFlexWatcher(char: Model)
	table.clear(savedC0s)
	fishingHoldActive = false
	char:GetAttributeChangedSignal("HoldingFlexFish"):Connect(function()
		AnimationController.ResetArms(0.22)
	end)
	task.delay(0.35, function()
		if char.Parent then
			applyFlexFishHoldIfActive(char)
		end
	end)
end

if localPlayer.Character then
	bindCharacterFlexWatcher(localPlayer.Character)
end
localPlayer.CharacterAdded:Connect(bindCharacterFlexWatcher)

return AnimationController
