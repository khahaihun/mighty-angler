--!strict
-- Register emitters once; periodic work visits emitters rather than whole worlds.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ParticleBudgetController = {}
local emitters: { [ParticleEmitter]: boolean } = {}
local initialized = false

local function register(instance: Instance)
	if instance:IsA("ParticleEmitter") and instance:GetAttribute("ClientBudgetManaged") == true then
		emitters[instance] = true
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
	for emitter in pairs(emitters) do
		local part = emitter:FindFirstAncestorWhichIsA("BasePart")
		if not part then continue end
		local selfOwned = character ~= nil and emitter:IsDescendantOf(character)
		local distance = if position then (part.Position - position).Magnitude else math.huge
		local allowed = if lowGfx then selfOwned and distance <= 45 else distance <= (if emitter.Name == "RankAuraEmitter" then 145 else 210)
		emitter.Enabled = emitter:GetAttribute("ClientBudgetEnabled") ~= false and emitter.Rate > 0 and allowed
	end
end

return ParticleBudgetController
