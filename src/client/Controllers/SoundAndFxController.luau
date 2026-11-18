--!strict
-- SoundAndFxController.luau: Am thanh SFX an toan, Toast thong bao & Hieu ung chu bay (+Gold, +Strength, +Gems)

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))
local SoundConfig = require(Shared:WaitForChild("Config"):WaitForChild("SoundConfig"))

local Theme = require(script.Parent.Parent.UI.Theme)

local SoundAndFxController = {}

local fxRootGui: ScreenGui? = nil
local toastStackFrame: Frame? = nil
local cachedSounds: { [string]: Sound } = {}
local mutedFlag = false
local lowGfxFlag = false

function SoundAndFxController.SetClientPrefs(muteSfx: boolean, lowGfx: boolean)
	mutedFlag = muteSfx
	lowGfxFlag = lowGfx
	local lighting = game:GetService("Lighting")
	lighting.GlobalShadows = not lowGfx
	local bloom = lighting:FindFirstChild("MightyBloom")
	if bloom and bloom:IsA("PostEffect") then
		bloom.Enabled = not lowGfx
	end
end

function SoundAndFxController.IsLowGfx(): boolean
	return lowGfxFlag
end

function SoundAndFxController.PlaySfx(effectKey: string)
	if mutedFlag then
		return
	end
	local spec = (SoundConfig.Effects :: any)[effectKey]
	if not spec then
		return
	end
	local snd = cachedSounds[effectKey]
	if not snd then
		local created = Instance.new("Sound")
		created.Name = "Sfx_" .. effectKey
		created.SoundId = spec.id
		created.Volume = spec.volume
		created.PlaybackSpeed = spec.pitch
		created.Parent = SoundService
		cachedSounds[effectKey] = created
		snd = created
	end
	pcall(function()
		snd:Play()
	end)
end

function SoundAndFxController.PunchCamera(intensityDeg: number?)
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	local deg = intensityDeg or 1.4
	task.spawn(function()
		cam.CFrame = cam.CFrame * CFrame.Angles(math.rad(deg), 0, 0)
		task.wait(0.06)
		cam.CFrame = cam.CFrame * CFrame.Angles(math.rad(-deg * 0.6), 0, 0)
	end)
end

function SoundAndFxController.ShowToast(kind: string, message: string)
	local stack = toastStackFrame
	if not stack then
		return
	end

	local accent = Theme.Colors.Primary
	if kind == "Success" then
		accent = Theme.Colors.Success
		SoundAndFxController.PlaySfx("Coins")
	elseif kind == "Error" then
		accent = Theme.Colors.Danger
		SoundAndFxController.PlaySfx("Error")
	elseif kind == "Epic" then
		accent = Theme.Colors.Gold
		SoundAndFxController.PlaySfx("CatchRare")
	end

	local item = Instance.new("Frame")
	item.Name = "ToastItem"
	item.Size = UDim2.new(1, 0, 0, 38)
	item.BackgroundColor3 = Theme.Colors.PanelBg
	item.BackgroundTransparency = 0.08
	item.Parent = stack
	Theme.AddCorner(item, 10)
	Theme.AddStroke(item, accent, 2.2)

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, -20, 1, 0)
	lbl.Position = UDim2.fromOffset(10, 0)
	lbl.BackgroundTransparency = 1
	lbl.Font = Theme.FontBody
	lbl.TextSize = 15
	lbl.TextColor3 = Theme.Colors.TextPrimary
	lbl.Text = message
	lbl.TextTruncate = Enum.TextTruncate.AtEnd
	lbl.Parent = item
	Theme.AddTextStroke(lbl, 1.6)

	task.delay(3.1, function()
		if item.Parent then
			TweenService:Create(item, TweenInfo.new(0.28), { BackgroundTransparency = 1 }):Play()
			TweenService:Create(lbl, TweenInfo.new(0.28), { TextTransparency = 1 }):Play()
			task.wait(0.3)
			if item.Parent then
				item:Destroy()
			end
		end
	end)
end

function SoundAndFxController.SpawnFloatingGain(kind: string, amount: number, extraLabel: string?)
	local root = fxRootGui
	if not root then
		return
	end

	local color = Theme.Colors.Gold
	local prefix = "+"
	local suffix = " Gold"
	if kind == "Strength" then
		color = Theme.Colors.Strength
		suffix = " Strength"
	elseif kind == "Gems" then
		color = Theme.Colors.Gems
		suffix = " Gems"
	end

	local lbl = Instance.new("TextLabel")
	lbl.Name = "FloatingGain"
	lbl.AnchorPoint = Vector2.new(0.5, 0.5)
	local randX = 0.44 + math.random() * 0.14
	local randY = 0.54 + math.random() * 0.08
	lbl.Position = UDim2.fromScale(randX, randY)
	lbl.Size = UDim2.fromOffset(260, 34)
	lbl.BackgroundTransparency = 1
	lbl.Font = Theme.FontTitle
	lbl.TextSize = 24
	lbl.TextColor3 = color
	lbl.Text = if extraLabel then extraLabel else (prefix .. Util.FormatNumber(amount) .. suffix)
	lbl.ZIndex = 60
	lbl.Parent = root
	Theme.AddTextStroke(lbl, 2.2)

	TweenService:Create(
		lbl,
		TweenInfo.new(0.95, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		{ Position = UDim2.fromScale(randX, randY - 0.12), TextTransparency = 0.15 }
	):Play()
	Debris:AddItem(lbl, 1.0)
end

function SoundAndFxController.Init(rootGui: ScreenGui)
	fxRootGui = rootGui

	local stack = Instance.new("Frame")
	stack.Name = "ToastStack"
	stack.AnchorPoint = Vector2.new(0.5, 0)
	stack.Position = UDim2.new(0.5, 0, 0, 66)
	stack.Size = UDim2.fromOffset(440, 180)
	stack.BackgroundTransparency = 1
	stack.ZIndex = 55
	stack.Parent = rootGui

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = stack
	toastStackFrame = stack

	Net.OnClientEvent(Net.ServerToClient.Toast, function(payload: any)
		if type(payload) == "table" then
			SoundAndFxController.ShowToast(tostring(payload.kind or "Info"), tostring(payload.text or ""))
		end
	end)

	Net.OnClientEvent(Net.ServerToClient.FloatingGain, function(payload: any)
		if type(payload) == "table" then
			SoundAndFxController.SpawnFloatingGain(tostring(payload.kind or "Gold"), tonumber(payload.amount) or 0, nil)
		end
	end)
end

return SoundAndFxController
