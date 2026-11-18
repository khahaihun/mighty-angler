--!strict
-- Register emitters once; periodic work visits emitters rather than whole worlds.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ParticleBudgetController = {}
local emitters: { [ParticleEmitter]: boolean } = {}
local initialized = false

local function register(instance: Instance)
	if instance:IsA("ParticleEmitter") then
		local original = instance:GetAttribute("BudgetOriginalEnabled")
		if type(original) ~= "boolean" then
			original = instance.Enabled
			instance:SetAttribute("BudgetOriginalEnabled", original)
		end
		emitters[instance] = original == true
	end
end

function ParticleBudgetController.Update(lowGfx: boolean)
	if not initialized then
		initialized = true
		Workspace.DescendantAdded:Connect(register)
		Workspace.DescendantRemoving:Connect(function(instance: Instance)
			if instance:IsA("ParticleEmitter") then emitters[instance] = nil end
		end)
		for _, instance in ipairs(Workspace:GetDescendants()) do register(instance) end
	end
	local localPlayer = Players.LocalPlayer
	local character = localPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local position = if root and root:IsA("BasePart") then root.Position else nil
	for emitter, originallyEnabled in pairs(emitters) do
		local part = emitter:FindFirstAncestorWhichIsA("BasePart")
		if not part then continue end
		local selfOwned = character ~= nil and emitter:IsDescendantOf(character)
		local distance = if position then (part.Position - position).Magnitude else math.huge
		local allowed = if lowGfx then selfOwned and distance <= 45 else distance <= 210
		emitter.Enabled = originallyEnabled and emitter.Rate > 0 and allowed
	end
end

return ParticleBudgetController
