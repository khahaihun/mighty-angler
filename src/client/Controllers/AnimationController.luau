--!strict
-- AnimationController.luau: Dien hoat nhan vat muot ma bang Motor6D Tween (chay 100% tren moi tai khoan R15 & R6)

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local AnimationController = {}

local localPlayer = Players.LocalPlayer
local savedC0s: { [Motor6D]: CFrame } = {}
local fishingHoldActive = false

local function findArmMotors(character: Model): (Motor6D?, Motor6D?)
	-- Ho tro R15
	local rightUpper = character:FindFirstChild("RightUpperArm")
	local leftUpper = character:FindFirstChild("LeftUpperArm")
	local rMotor: Motor6D? = nil
	local lMotor: Motor6D? = nil

	if rightUpper then
		local m = rightUpper:FindFirstChild("RightShoulder")
		if m and m:IsA("Motor6D") then
			rMotor = m
		end
	end
	if leftUpper then
		local m = leftUpper:FindFirstChild("LeftShoulder")
		if m and m:IsA("Motor6D") then
			lMotor = m
		end
	end

	if rMotor then
		return rMotor, lMotor
	end

	-- Ho tro R6
	local torso = character:FindFirstChild("Torso")
	if torso then
		local rm = torso:FindFirstChild("Right Shoulder")
		local lm = torso:FindFirstChild("Left Shoulder")
		if rm and rm:IsA("Motor6D") then
			rMotor = rm
		end
		if lm and lm:IsA("Motor6D") then
			lMotor = lm
		end
	end
	return rMotor, lMotor
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
	local isR6 = (motor.Name == "Right Shoulder" or motor.Name == "Left Shoulder")
	local adjusted = offsetAngles
	if isR6 then
		-- R6 truc vai xoay quanh Z thay vi X
		local rx, ry, rz = offsetAngles:ToEulerAnglesXYZ()
		local sign = if motor.Name == "Right Shoulder" then 1 else -1
		adjusted = CFrame.Angles(rz, ry, rx * sign)
	end
	TweenService:Create(
		motor,
		TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ C0 = base * adjusted }
	):Play()
end

function AnimationController.ResetArms(duration: number?)
	local char = localPlayer.Character
	if not char then
		return
	end
	local rMotor, lMotor = findArmMotors(char)
	local dur = duration or 0.22
	tweenMotor(rMotor, CFrame.Angles(0, 0, 0), dur)
	tweenMotor(lMotor, CFrame.Angles(0, 0, 0), dur)
end

function AnimationController.PlayCast()
	local char = localPlayer.Character
	if not char then
		return
	end
	local rMotor, _ = findArmMotors(char)
	if not rMotor then
		return
	end
	fishingHoldActive = true

	task.spawn(function()
		-- Vung tay ra sau lay da
		tweenMotor(rMotor, CFrame.Angles(math.rad(135), 0, math.rad(10)), 0.16)
		task.wait(0.17)
		-- Quang can manh ra phia truoc
		tweenMotor(rMotor, CFrame.Angles(math.rad(52), 0, math.rad(-6)), 0.14)
		task.wait(0.16)
		if fishingHoldActive then
			tweenMotor(rMotor, CFrame.Angles(math.rad(65), 0, math.rad(-5)), 0.25)
		end
	end)
end

function AnimationController.PlayReelPull()
	local char = localPlayer.Character
	if not char then
		return
	end
	local rMotor, lMotor = findArmMotors(char)
	fishingHoldActive = false

	task.spawn(function()
		tweenMotor(rMotor, CFrame.Angles(math.rad(118), 0, math.rad(-12)), 0.16)
		tweenMotor(lMotor, CFrame.Angles(math.rad(82), 0, math.rad(18)), 0.16)
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
	local rMotor, lMotor = findArmMotors(char)
	gymToggleSide = not gymToggleSide

	task.spawn(function()
		if stationType == "Dumbbells" then
			if gymToggleSide then
				tweenMotor(rMotor, CFrame.Angles(math.rad(112), 0, math.rad(-8)), 0.15)
				tweenMotor(lMotor, CFrame.Angles(math.rad(24), 0, 0), 0.15)
			else
				tweenMotor(lMotor, CFrame.Angles(math.rad(112), 0, math.rad(8)), 0.15)
				tweenMotor(rMotor, CFrame.Angles(math.rad(24), 0, 0), 0.15)
			end
			task.wait(0.22)
			AnimationController.ResetArms(0.20)
		elseif stationType == "Treadmill" then
			local fwd = if gymToggleSide then 68 else -36
			local bwd = if gymToggleSide then -36 else 68
			tweenMotor(rMotor, CFrame.Angles(math.rad(fwd), 0, 0), 0.14)
			tweenMotor(lMotor, CFrame.Angles(math.rad(bwd), 0, 0), 0.14)
			task.wait(0.20)
			AnimationController.ResetArms(0.20)
		else
			-- BenchPress: Day ta ca hai tay manh len cao
			tweenMotor(rMotor, CFrame.Angles(math.rad(132), 0, math.rad(-14)), 0.16)
			tweenMotor(lMotor, CFrame.Angles(math.rad(132), 0, math.rad(14)), 0.16)
			task.wait(0.22)
			tweenMotor(rMotor, CFrame.Angles(math.rad(55), 0, math.rad(-20)), 0.18)
			tweenMotor(lMotor, CFrame.Angles(math.rad(55), 0, math.rad(20)), 0.18)
			task.wait(0.18)
			AnimationController.ResetArms(0.22)
		end
	end)
end

localPlayer.CharacterAdded:Connect(function()
	table.clear(savedC0s)
	fishingHoldActive = false
end)

return AnimationController
