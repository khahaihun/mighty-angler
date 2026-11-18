--!strict
-- One owner for overlapping dialogue and fishing camera focus.
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local CameraFocusController = {}
local talking = false
local minigame = false
local activeTween: Tween? = nil

function CameraFocusController.GetTargetFov(): number
	return if talking then 62 elseif minigame then 64 else 70
end

local function refresh()
	if activeTween then activeTween:Cancel(); activeTween = nil end
	local camera = Workspace.CurrentCamera
	if not camera then return end
	local tween = TweenService:Create(camera, TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		FieldOfView = CameraFocusController.GetTargetFov(),
	})
	activeTween = tween
	tween:Play()
end

function CameraFocusController.SetTalking(value: boolean)
	talking = value
	refresh()
end

function CameraFocusController.SetMinigame(value: boolean)
	minigame = value
	refresh()
end

Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(refresh)
return CameraFocusController
