-- Algebra mock verifies lifecycle/order; this does not certify rendered joint orientation.
local cf = {}
local mt = { __mul = function(a, b) return cf.new(a.x+b.x, a.y+b.y, a.z+b.z) end }
function cf.new(x, y, z)
	return setmetatable({ x = x or 0, y = y or 0, z = z or 0,
		Inverse = function(self) return cf.new(-self.x, -self.y, -self.z) end,
		ToEulerAnglesXYZ = function(self) return self.x, self.y, self.z end }, mt)
end
cf.Angles = cf.new
cf.identity = cf.new()
local function signal()
	local result = { callbacks = {} }
	function result:Connect(callback) table.insert(self.callbacks, callback); return { Disconnect = function() end } end
	function result:Fire(...) for _, callback in ipairs(self.callbacks) do callback(...) end end
	return result
end
local function character(kind)
	local attrs, joints = {}, {}
	for _, role in ipairs({ "RightShoulder", "LeftShoulder", "Waist" }) do
		local name = if kind == "R6" and role ~= "Waist" then (if role == "RightShoulder" then "Right Shoulder" else "Left Shoulder") else role
		local joint = { Name = name, Parent = true, Transform = cf.identity }
		function joint:IsA(class) return class == (if kind == "Constraint" then "AnimationConstraint" else "Motor6D") end
		table.insert(joints, joint)
	end
	return { Parent = true, DescendantAdded = signal(), GetDescendants = function() return joints end,
		GetAttribute = function(_, key) return attrs[key] end, SetAttribute = function(_, key, value) attrs[key] = value end }, joints
end
local localChar, localJoints = character("R6")
local remoteChar, remoteJoints = character("Constraint")
local motorChar, motorJoints = character("Motor")
local localPlayer = { Character = localChar, CharacterAdded = signal() }
local players = { LocalPlayer = localPlayer, PlayerAdded = signal(), GetPlayers = function()
	return { localPlayer, { Character = remoteChar, CharacterAdded = signal() }, { Character = motorChar, CharacterAdded = signal() } }
end }
local now = 100
local workspace = { GetServerTimeNow = function() return now end }
local run = { PreAnimation = signal(), PreSimulation = signal() }
local environment = setmetatable({ CFrame = cf, game = { GetService = function(_, name)
	return if name == "Players" then players elseif name == "RunService" then run else workspace
end } }, { __index = getfenv() })
local chunk = assert(loadstring(source)); setfenv(chunk, environment)
local animation = chunk()
local function frame() run.PreAnimation:Fire(); run.PreSimulation:Fire() end
local function magnitude(joints) local sum = 0; for _, joint in ipairs(joints) do sum += math.abs(joint.Transform.x)+math.abs(joint.Transform.y)+math.abs(joint.Transform.z) end; return sum end
animation.PlayCast(); frame()
assert(magnitude(localJoints) > 0 and magnitude(remoteJoints) == 0, "prediction must stay on the local player")
remoteChar:SetAttribute("VisualAction", "Cast"); remoteChar:SetAttribute("VisualActionAt", now)
motorChar:SetAttribute("VisualAction", "Dumbbells"); motorChar:SetAttribute("VisualActionAt", now)
frame(); assert(magnitude(remoteJoints) > 0 and magnitude(motorJoints) > 0, "observers need replicated actions on both joint kinds")
local previous = magnitude(remoteJoints)
for _ = 1, 100 do frame() end
assert(math.abs(magnitude(remoteJoints)-previous) < 1e-8, "pose offsets must not accumulate")
now += 1; frame(); assert(magnitude(remoteJoints) < 1e-8 and magnitude(localJoints) < 1e-8, "one-shot poses must expire")
remoteChar:SetAttribute("HoldingFlexFish", true); frame(); assert(magnitude(remoteJoints) > 0, "fish hold must persist")
remoteChar:SetAttribute("HoldingFlexFish", false); remoteChar:SetAttribute("FishingPoseActive", true); frame(); assert(magnitude(remoteJoints) > 0, "fishing hold must persist")
remoteChar:SetAttribute("FishingPoseActive", false); frame(); assert(magnitude(remoteJoints) < 1e-8)
local newChar, newJoints = character("Motor")
localChar.Parent = nil; localPlayer.Character = newChar; localPlayer.CharacterAdded:Fire(newChar)
animation.PlayGymRep("BenchPress"); frame(); assert(magnitude(newJoints) > 0, "respawn must bind fresh joints")
print("PASS pose lifecycle: R6/Motor/Constraint, observer actions, no accumulation, hold/stop/respawn")
