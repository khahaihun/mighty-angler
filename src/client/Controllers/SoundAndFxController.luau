--!strict
-- SoundAndFxController.luau: Am thanh SFX an toan, Toast, FloatingGain, Camera Punch can bang 0 do & Low GFX Particle Culling

local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))
local SoundConfig = require(Shared:WaitForChild("Config"):WaitForChild("SoundConfig"))

local Theme = require(script.Parent.Parent.UI.Theme)
local ParticleBudgetController = require(script.Parent.ParticleBudgetController)

local WindowFrame = require(script.Parent.Parent.UI.Components.WindowFrame)

local SoundAndFxController = {}

local fxRootGui: ScreenGui? = nil
local toastStackFrame: Frame? = nil
local cachedSounds: { [string]: Sound } = {}
local ambientSound: Sound? = nil
local mutedFlag = false
local lowGfxFlag = false
local activeToasts: { Frame } = {}
local rayOriginals: { [SunRaysEffect]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local cloudOriginals: { [Clouds]: { density: number, cover: number, enabled: boolean } } = setmetatable({}, { __mode = "k" }) :: any

local function applyAtmosphereBudget(lowGfx: boolean)
	for _, effect in ipairs(Lighting:GetDescendants()) do
		if effect:IsA("SunRaysEffect") then
			if lowGfx then
				if rayOriginals[effect] == nil then rayOriginals[effect] = effect.Enabled end
				effect.Enabled = false
			elseif rayOriginals[effect] ~= nil then
				effect.Enabled = rayOriginals[effect]
				rayOriginals[effect] = nil
			end
		end
	end
	local clouds = Workspace.Terrain:FindFirstChildOfClass("Clouds")
	if clouds then
		local original = cloudOriginals[clouds]
		if lowGfx then
			if not original then
				original = { density = clouds.Density, cover = clouds.Cover, enabled = clouds.Enabled }
				cloudOriginals[clouds] = original
			end
			clouds.Density = original.density * 0.25
			clouds.Cover = original.cover * 0.5
		elseif original then
			clouds.Density, clouds.Cover, clouds.Enabled = original.density, original.cover, original.enabled
			cloudOriginals[clouds] = nil
		end
	end
end

local function applyClientParticleBudget()
	ParticleBudgetController.Update(lowGfxFlag)
end

function SoundAndFxController.SetClientPrefs(muteSfx: boolean, lowGfx: boolean)
	mutedFlag = muteSfx
	lowGfxFlag = lowGfx
	if ambientSound then
		ambientSound.Volume = if muteSfx then 0 else SoundConfig.OceanAmbience.volume
	end
	Lighting.GlobalShadows = not lowGfx
	local bloom = Lighting:FindFirstChild("MightyBloom")
	if bloom and bloom:IsA("PostEffect") then
		bloom.Enabled = not lowGfx
	end
	applyAtmosphereBudget(lowGfx)
	applyClientParticleBudget()
end

function SoundAndFxController.IsLowGfx(): boolean
	return lowGfxFlag
end

function SoundAndFxController.PlaySfx(effectKey: string)
	if mutedFlag then return end
	local spec = (SoundConfig.Effects :: any)[effectKey]
	if not spec then return end
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
	pcall(function() snd:Play() end)
end

function SoundAndFxController.PunchCamera(intensityDeg: number?)
	local cam = Workspace.CurrentCamera
	if not cam then return end
	local deg = intensityDeg or 1.4
	task.spawn(function()
		cam.CFrame = cam.CFrame * CFrame.Angles(math.rad(deg), 0, 0)
		task.wait(0.05)
		if Workspace.CurrentCamera == cam then
			cam.CFrame = cam.CFrame * CFrame.Angles(math.rad(-deg * 0.6), 0, 0)
		end
		task.wait(0.05)
		if Workspace.CurrentCamera == cam then
			cam.CFrame = cam.CFrame * CFrame.Angles(math.rad(-deg * 0.4), 0, 0)
		end
	end)
end

function SoundAndFxController.ShowToast(kind: string, message: string)
	local stack = toastStackFrame
	if not stack then return end

	for i = #activeToasts, 1, -1 do
		if not activeToasts[i].Parent then table.remove(activeToasts, i) end
	end
	while #activeToasts >= 3 do
		local oldest = table.remove(activeToasts, 1)
		if oldest then oldest:Destroy() end
	end

	local accent = Theme.Colors.Primary
	if kind == "Success" then accent = Theme.Colors.Success; SoundAndFxController.PlaySfx("Coins")
	elseif kind == "Error" then accent = Theme.Colors.Danger; SoundAndFxController.PlaySfx("Error")
	elseif kind == "Epic" then accent = Theme.Colors.Gold; SoundAndFxController.PlaySfx("CatchRare") end

	local item = Instance.new("Frame")
	item.Name = "ToastItem"
	item.Size = UDim2.new(1, 0, 0, 48)
	item.BackgroundColor3 = Theme.Colors.PanelBg
	item.BackgroundTransparency = 0.08
	item.Parent = stack
	table.insert(activeToasts, item)
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
	lbl.TextWrapped = true
	Theme.FitText(lbl, 15, 13)
	lbl.Parent = item
	Theme.AddTextStroke(lbl, 1.6)

	task.delay(3.1, function()
		if item.Parent then
			TweenService:Create(item, TweenInfo.new(0.28), { BackgroundTransparency = 1 }):Play()
			TweenService:Create(lbl, TweenInfo.new(0.28), { TextTransparency = 1 }):Play()
			task.wait(0.3)
			if item.Parent then item:Destroy() end
		end
	end)
end

function SoundAndFxController.SpawnFloatingGain(kind: string, amount: number, extraLabel: string?)
	local root = fxRootGui
	if not root then return end

	local color, suffix = Theme.Colors.Gold, " Gold"
	if kind == "Strength" then color, suffix = Theme.Colors.Strength, " Strength"
	elseif kind == "Gems" then color, suffix = Theme.Colors.Gems, " Gems" end

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
	lbl.Text = if extraLabel then extraLabel else ("+" .. Util.FormatNumber(amount) .. suffix)
	lbl.ZIndex = 60
	lbl.Parent = root
	Theme.AddTextStroke(lbl, 2.2)

	TweenService:Create(lbl, TweenInfo.new(0.95, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		Position = UDim2.fromScale(randX, randY - 0.12), TextTransparency = 0.15,
	}):Play()
	Debris:AddItem(lbl, 1.0)
end

function SoundAndFxController.Init(rootGui: ScreenGui)
	fxRootGui = rootGui

	local stack = Instance.new("Frame")
	stack.Name = "ToastStack"
	stack.AnchorPoint = Vector2.new(0.5, 0)
	stack.Position = UDim2.new(0.5, 0, 0, 90)
	stack.Size = UDim2.new(1, 0, 1, 0)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(460, 156)
	limit.Parent = stack
	stack.BackgroundTransparency = 1
	stack.ZIndex = 55
	local slot = Instance.new("Frame")
	slot.BackgroundTransparency = 1
	slot.ZIndex = stack.ZIndex
	slot.Parent = rootGui
	WindowFrame.BindLayout(rootGui, slot, "ToastStack")
	stack.AnchorPoint = Vector2.zero
	stack.Position = UDim2.fromScale(0, 0)
	stack.Parent = slot

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = stack
	toastStackFrame = stack

	local amb = Instance.new("Sound")
	amb.Name = "OceanAmbienceLoop"
	amb.SoundId = SoundConfig.OceanAmbience.id
	amb.Volume = if mutedFlag then 0 else SoundConfig.OceanAmbience.volume
	amb.PlaybackSpeed = SoundConfig.OceanAmbience.pitch
	amb.Looped = true
	amb.Parent = SoundService
	ambientSound = amb
	pcall(function() amb:Play() end)

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

	task.spawn(function()
		while true do
			task.wait(2.0)
			applyClientParticleBudget()
			if lowGfxFlag then applyAtmosphereBudget(true) end
		end
	end)
end

return SoundAndFxController
