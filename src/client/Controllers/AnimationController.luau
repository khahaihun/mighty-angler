--!strict
-- AnimationController.luau: Dien hoat toan than ho tro du R6, R15 Motor6D VA R15 AnimationConstraint + Animator Replication

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local AnimationController = {}

local localPlayer = Players.LocalPlayer
local savedC0s: { [Motor6D]: CFrame } = {}
local cachedTracks: { [string]: AnimationTrack } = {}
local activeHoldTrack: AnimationTrack? = nil
local fishingHoldActive = false

local R15_ANIMS = {
	CastSlash = "rbxassetid://522635514",
	ReelLunge = "rbxassetid://522638767",
	ToolHold = "rbxassetid://507768375",
	FlexCheer = "rbxassetid://507770677",
}
local R6_ANIMS = {
	CastSlash = "rbxassetid://129967390",
	ReelLunge = "rbxassetid://129967478",
	ToolHold = "rbxassetid://182393478",
	FlexCheer = "rbxassetid://129423030",
}

local function playAnimatorAction(char: Model, key: string, looped: boolean, speed: number): AnimationTrack?
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return nil
	end
	local animator = hum:FindFirstChildOfClass("Animator")
	if not animator then
		return nil
	end
	local idMap = if hum.RigType == Enum.HumanoidRigType.R6 then R6_ANIMS else R15_ANIMS
	local animId = (idMap :: any)[key]
	if type(animId) ~= "string" then
		return nil
	end
	local cacheKey = tostring(hum.RigType.Name) .. "_" .. key
	local track = cachedTracks[cacheKey]
	if not track then
		local ok, loaded = pcall(function()
			local anim = Instance.new("Animation")
			anim.AnimationId = animId
			return animator:LoadAnimation(anim)
		end)
		if ok and loaded then
			cachedTracks[cacheKey] = loaded
			track = loaded
		end
	end
	if track then
		pcall(function()
			track.Priority = if looped then Enum.AnimationPriority.Movement else Enum.AnimationPriority.Action
			track.Looped = looped
			track:Play(0.12, 1.0, speed)
		end)
	end
	return track
end

local function stopHoldTrack()
	if activeHoldTrack then
		pcall(function()
			activeHoldTrack:Stop(0.18)
		end)
		activeHoldTrack = nil
	end
end

local function findBodyJoints(character: Model): (Motor6D?, Motor6D?, Motor6D?, any?, any?, any?)
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
		return rMotor, lMotor, waistMotor, nil, nil, nil
	end

	local torso = character:FindFirstChild("Torso")
	if torso then
		local rm = torso:FindFirstChild("Right Shoulder")
		local lm = torso:FindFirstChild("Left Shoulder")
		if rm and rm:IsA("Motor6D") then rMotor = rm end
		if lm and lm:IsA("Motor6D") then lMotor = lm end
		if rMotor then
			return rMotor, lMotor, nil, nil, nil, nil
		end
	end

	-- Ho tro R15 Avatar Joint Upgrade su dung AnimationConstraint
	local rCon: any, lCon: any, wCon: any = nil, nil, nil
	for _, d in ipairs(character:GetDescendants()) do
		if d.ClassName == "AnimationConstraint" then
			if d.Name == "RightShoulder" then rCon = d
			elseif d.Name == "LeftShoulder" then lCon = d
			elseif d.Name == "Waist" then wCon = d end
		end
	end
	return nil, nil, nil, rCon, lCon, wCon
end

local function getBaseC0(motor: Motor6D): CFrame
	local saved = savedC0s[motor]
	if saved then return saved end
	savedC0s[motor] = motor.C0
	return motor.C0
end

local function applyJointPose(motor: Motor6D?, constraint: any?, offsetAngles: CFrame, duration: number)
	if motor and motor.Parent then
		local base = getBaseC0(motor)
		local isR6 = (motor.Name == "Right Shoulder" or motor.Name == "Left Shoulder")
		local adjusted = offsetAngles
		if isR6 then
			local rx, ry, rz = offsetAngles:ToEulerAnglesXYZ()
			local sign = if motor.Name == "Right Shoulder" then 1 else -1
			adjusted = CFrame.Angles(rz, ry, rx * sign)
		end
		TweenService:Create(motor, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			C0 = base * adjusted,
		}):Play()
	elseif constraint ~= nil and constraint.Parent ~= nil then
		pcall(function()
			TweenService:Create(constraint, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Transform = offsetAngles,
			}):Play()
		end)
	end
end

local function applyFlexFishHoldIfActive(char: Model): boolean
	if char:GetAttribute("HoldingFlexFish") == true then
		local rM, lM, wM, rC, lC, wC = findBodyJoints(char)
		applyJointPose(rM, rC, CFrame.Angles(math.rad(82), math.rad(-18), math.rad(-14)), 0.22)
		applyJointPose(lM, lC, CFrame.Angles(math.rad(82), math.rad(18), math.rad(14)), 0.22)
		applyJointPose(wM, wC, CFrame.Angles(math.rad(-6), 0, 0), 0.22)
		activeHoldTrack = playAnimatorAction(char, "ToolHold", true, 1.0)
		return true
	end
	return false
end

function AnimationController.ResetArms(duration: number?)
	local char = localPlayer.Character
	if not char then return end
	stopHoldTrack()
	if applyFlexFishHoldIfActive(char) then return end
	local rM, lM, wM, rC, lC, wC = findBodyJoints(char)
	local dur = duration or 0.22
	applyJointPose(rM, rC, CFrame.Angles(0, 0, 0), dur)
	applyJointPose(lM, lC, CFrame.Angles(0, 0, 0), dur)
	applyJointPose(wM, wC, CFrame.Angles(0, 0, 0), dur)
end

function AnimationController.PlayCast()
	local char = localPlayer.Character
	if not char then return end
	fishingHoldActive = true
	playAnimatorAction(char, "CastSlash", false, 1.35)
	local rM, lM, wM, rC, lC, wC = findBodyJoints(char)

	task.spawn(function()
		applyJointPose(wM, wC, CFrame.Angles(math.rad(14), math.rad(-12), 0), 0.15)
		applyJointPose(rM, rC, CFrame.Angles(math.rad(142), 0, math.rad(12)), 0.15)
		applyJointPose(lM, lC, CFrame.Angles(math.rad(35), 0, math.rad(-10)), 0.15)
		task.wait(0.16)
		applyJointPose(wM, wC, CFrame.Angles(math.rad(-12), math.rad(8), 0), 0.14)
		applyJointPose(rM, rC, CFrame.Angles(math.rad(50), 0, math.rad(-6)), 0.14)
		task.wait(0.16)
		if fishingHoldActive and localPlayer.Character == char then
			applyJointPose(wM, wC, CFrame.Angles(math.rad(-4), 0, 0), 0.25)
			applyJointPose(rM, rC, CFrame.Angles(math.rad(66), 0, math.rad(-5)), 0.25)
			applyJointPose(lM, lC, CFrame.Angles(math.rad(42), math.rad(16), 0), 0.25)
			activeHoldTrack = playAnimatorAction(char, "ToolHold", true, 1.0)
		end
	end)
end

function AnimationController.PlayReelPull()
	local char = localPlayer.Character
	if not char then return end
	fishingHoldActive = false
	stopHoldTrack()
	playAnimatorAction(char, "ReelLunge", false, 1.45)
	local rM, lM, wM, rC, lC, wC = findBodyJoints(char)

	task.spawn(function()
		applyJointPose(wM, wC, CFrame.Angles(math.rad(16), 0, 0), 0.16)
		applyJointPose(rM, rC, CFrame.Angles(math.rad(124), 0, math.rad(-14)), 0.16)
		applyJointPose(lM, lC, CFrame.Angles(math.rad(88), 0, math.rad(18)), 0.16)
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
	if not char then return end
	gymToggleSide = not gymToggleSide
	playAnimatorAction(char, if stationType == "BenchPress" then "ReelLunge" else "CastSlash", false, 1.5)
	local rM, lM, wM, rC, lC, wC = findBodyJoints(char)

	task.spawn(function()
		if stationType == "Dumbbells" then
			if gymToggleSide then
				applyJointPose(rM, rC, CFrame.Angles(math.rad(118), 0, math.rad(-8)), 0.15)
				applyJointPose(lM, lC, CFrame.Angles(math.rad(26), 0, 0), 0.15)
				applyJointPose(wM, wC, CFrame.Angles(math.rad(-5), math.rad(8), 0), 0.15)
			else
				applyJointPose(lM, lC, CFrame.Angles(math.rad(118), 0, math.rad(8)), 0.15)
				applyJointPose(rM, rC, CFrame.Angles(math.rad(26), 0, 0), 0.15)
				applyJointPose(wM, wC, CFrame.Angles(math.rad(-5), math.rad(-8), 0), 0.15)
			end
			task.wait(0.22)
			AnimationController.ResetArms(0.20)
		elseif stationType == "Treadmill" then
			local fwd = if gymToggleSide then 72 else -38
			local bwd = if gymToggleSide then -38 else 72
			applyJointPose(wM, wC, CFrame.Angles(math.rad(-10), 0, 0), 0.14)
			applyJointPose(rM, rC, CFrame.Angles(math.rad(fwd), 0, 0), 0.14)
			applyJointPose(lM, lC, CFrame.Angles(math.rad(bwd), 0, 0), 0.14)
			task.wait(0.20)
			AnimationController.ResetArms(0.20)
		else
			applyJointPose(wM, wC, CFrame.Angles(math.rad(10), 0, 0), 0.16)
			applyJointPose(rM, rC, CFrame.Angles(math.rad(138), 0, math.rad(-4)), 0.16)
			applyJointPose(lM, lC, CFrame.Angles(math.rad(138), 0, math.rad(4)), 0.16)
			task.wait(0.22)
			applyJointPose(rM, rC, CFrame.Angles(math.rad(58), 0, math.rad(-6)), 0.18)
			applyJointPose(lM, lC, CFrame.Angles(math.rad(58), 0, math.rad(6)), 0.18)
			task.wait(0.18)
			AnimationController.ResetArms(0.22)
		end
	end)
end

local function bindCharacterFlexWatcher(char: Model)
	table.clear(savedC0s)
	table.clear(cachedTracks)
	activeHoldTrack = nil
	fishingHoldActive = false
	char:GetAttributeChangedSignal("HoldingFlexFish"):Connect(function()
		AnimationController.ResetArms(0.22)
	end)
	task.delay(0.35, function()
		if char.Parent then applyFlexFishHoldIfActive(char) end
	end)
end

if localPlayer.Character then bindCharacterFlexWatcher(localPlayer.Character) end
localPlayer.CharacterAdded:Connect(bindCharacterFlexWatcher)

return AnimationController
