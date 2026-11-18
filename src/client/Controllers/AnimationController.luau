--!strict
-- Action-specific procedural poses, evaluated after Animator on every observing client.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local AnimationController = {}

type Joint = { instance: any, role: string, r6: boolean, lastOffset: CFrame }
type Rig = { joints: { Joint }, dirty: boolean, connection: RBXScriptConnection }
local rigs: { [Model]: Rig } = {}
local localAction = ""
local localActionAt = 0
local localPlayer = Players.LocalPlayer

local function angle(x: number, y: number?, z: number?): CFrame
	return CFrame.Angles(math.rad(x), math.rad(y or 0), math.rad(z or 0))
end

local function pose(action: string, elapsed: number): (CFrame, CFrame, CFrame)
	if action == "FishHold" then return angle(82, -18, -14), angle(82, 18, 14), angle(-6) end
	if action == "Cast" then
		local lift = if elapsed < 0.16 then 142 else 50
		return angle(lift, 0, 10), angle(35, 0, -10), angle(if elapsed < 0.16 then 14 else -12)
	end
	if action == "Reel" then return angle(124, 0, -14), angle(88, 0, 18), angle(16) end
	if action == "FishingHold" then return angle(66, 0, -5), angle(42, 16), angle(-4) end
	local wave = math.sin(elapsed * math.pi * 4)
	if action == "Dumbbells" then return angle(65 + 45 * wave, 0, -8), angle(65 - 45 * wave, 0, 8), angle(-5) end
	if action == "BenchPress" then return angle(110 + 28 * wave), angle(110 + 28 * wave), angle(10) end
	if action == "Treadmill" then return angle(30 + 48 * wave), angle(30 - 48 * wave), angle(-10) end
	return CFrame.identity, CFrame.identity, CFrame.identity
end

local function watchCharacter(character: Model)
	if rigs[character] then return end
	local rig: Rig = { joints = {}, dirty = true, connection = nil :: any }
	rig.connection = character.DescendantAdded:Connect(function() rig.dirty = true end)
	rigs[character] = rig
end

local function watchPlayer(player: Player)
	if player.Character then watchCharacter(player.Character) end
	player.CharacterAdded:Connect(watchCharacter)
end

local function rebuild(character: Model, rig: Rig)
	table.clear(rig.joints)
	for _, joint in ipairs(character:GetDescendants()) do
		if joint:IsA("Motor6D") or joint:IsA("AnimationConstraint") then
			local role = if joint.Name == "RightShoulder" or joint.Name == "Right Shoulder" then "Right"
				elseif joint.Name == "LeftShoulder" or joint.Name == "Left Shoulder" then "Left"
				elseif joint.Name == "Waist" then "Waist" else ""
			if role ~= "" then table.insert(rig.joints, { instance = joint, role = role, r6 = string.find(joint.Name, " ") ~= nil, lastOffset = CFrame.identity }) end
		end
	end
	rig.dirty = false
end

local function getAction(character: Model): (string, number)
	if character:GetAttribute("HoldingFlexFish") == true then return "FishHold", 0 end
	local now = Workspace:GetServerTimeNow()
	local action = tostring(character:GetAttribute("VisualAction") or "")
	local at = tonumber(character:GetAttribute("VisualActionAt")) or 0
	if character == localPlayer.Character and localActionAt > at then action = localAction; at = localActionAt end
	local elapsed = now - at
	if action == "Cast" and elapsed > 0.34 then action = "" end
	if action == "Reel" and elapsed > 0.5 then action = "" end
	if (action == "Dumbbells" or action == "BenchPress" or action == "Treadmill") and elapsed > 0.55 then action = "" end
	if action == "" and character:GetAttribute("FishingPoseActive") == true then action = "FishingHold" end
	return action, math.max(0, elapsed)
end

-- Remove our previous offset before Animator evaluates, then layer a fresh one after it.
RunService.PreAnimation:Connect(function()
	for character, rig in pairs(rigs) do
		if not character.Parent then rig.connection:Disconnect(); rigs[character] = nil; continue end
		for _, joint in ipairs(rig.joints) do
			if joint.instance.Parent then joint.instance.Transform = joint.instance.Transform * joint.lastOffset:Inverse() end
			joint.lastOffset = CFrame.identity
		end
	end
end)
RunService.PreSimulation:Connect(function()
	for character, rig in pairs(rigs) do
		if rig.dirty then rebuild(character, rig) end
		local action, elapsed = getAction(character)
		local right, left, waist = pose(action, elapsed)
		for _, joint in ipairs(rig.joints) do
			local offset = if joint.role == "Right" then right elseif joint.role == "Left" then left else waist
			if joint.r6 then
				local x, y, z = offset:ToEulerAnglesXYZ()
				offset = CFrame.Angles(z, y, x * (if joint.role == "Right" then 1 else -1))
			end
			if joint.instance.Parent then joint.instance.Transform = joint.instance.Transform * offset; joint.lastOffset = offset end
		end
	end
end)

local function play(action: string)
	localAction = action
	localActionAt = Workspace:GetServerTimeNow()
end
function AnimationController.ResetArms(_duration: number?) play("") end
function AnimationController.PlayCast() play("Cast") end
function AnimationController.PlayReelPull() play("Reel") end
function AnimationController.StopFishingHold() play("") end
function AnimationController.PlayGymRep(stationType: string) play(stationType) end
for _, player in ipairs(Players:GetPlayers()) do watchPlayer(player) end
Players.PlayerAdded:Connect(watchPlayer)
return AnimationController
