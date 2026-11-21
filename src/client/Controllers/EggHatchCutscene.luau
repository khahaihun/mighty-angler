--!strict
-- EggHatchCutscene.luau: Dien hoat Dap Trung Nut Vo 3D + No Anh Sang khoe Pet Chibi moi no (co nut SKIP nhanh)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local AssetRegistry = require(Shared:WaitForChild("AssetRegistry"))
local PetsConfig = require(Shared:WaitForChild("Config"):WaitForChild("PetsConfig"))
local PetModelBuilder = require(Shared:WaitForChild("ModelBuilders"):WaitForChild("PetModelBuilder"))

local Theme = require(script.Parent.Parent.UI.Theme)
local SoundAndFxController = require(script.Parent.SoundAndFxController)

local EggHatchCutscene = {}

local overlay: Frame? = nil
local vpFrame: ViewportFrame? = nil
local vpCam: Camera? = nil
local flashFrame: Frame? = nil
local titleLbl: TextLabel? = nil
local subLbl: TextLabel? = nil

local activeTicket = 0
local spinConn: RBXScriptConnection? = nil

local function clearViewport()
	if spinConn then
		spinConn:Disconnect()
		spinConn = nil
	end
	if vpFrame then
		for _, ch in ipairs(vpFrame:GetChildren()) do
			if not ch:IsA("Camera") then
				ch:Destroy()
			end
		end
	end
end

function EggHatchCutscene.Skip()
	activeTicket += 1
	clearViewport()
	if overlay then
		overlay.Visible = false
	end
end

local function buildEgg3DModel(eggId: string, eggColor: Color3, accentColor: Color3): Model
	if eggId ~= "" then
		local override = AssetRegistry.TryClone("Eggs", eggId, true)
		if override and override.PrimaryPart then
			AssetRegistry.NormalizeForViewport(override, 2.75)
			return override
		end
	end

	local m = Instance.new("Model")
	local shell = Instance.new("Part")
	shell.Shape = Enum.PartType.Ball
	shell.Size = Vector3.new(2.15, 2.75, 2.15)
	shell.Color = eggColor
	shell.Material = Enum.Material.SmoothPlastic
	shell.Anchored = true
	shell.Parent = m
	m.PrimaryPart = shell

	local band = Instance.new("Part")
	band.Shape = Enum.PartType.Cylinder
	band.Size = Vector3.new(0.36, 2.24, 2.24)
	band.CFrame = CFrame.Angles(0, 0, math.rad(90))
	band.Color = accentColor
	band.Material = Enum.Material.Neon
	band.Anchored = true
	band.Parent = m
	return m
end

local function playHatchSequence(eggId: string, petId: string, sourceLabel: string)
	local petDef = PetsConfig.PetsById[petId]
	local ov = overlay
	local vp = vpFrame
	local cam = vpCam
	local flash = flashFrame
	if not petDef or not ov or not vp or not cam or not flash then
		return
	end

	activeTicket += 1
	local myTicket = activeTicket
	clearViewport()

	local eggDef = PetsConfig.EggsById[eggId]
	local eggCol = if eggDef then eggDef.eggColor else petDef.primaryColor
	local accCol = if eggDef then eggDef.accentColor else petDef.secondaryColor
	local rCol = Theme.RarityColors[petDef.rarity] or Theme.Colors.Gold

	ov.Visible = true
	flash.BackgroundTransparency = 1
	cam.CFrame = CFrame.lookAt(Vector3.new(0, 0.8, 5.2), Vector3.zero)

	if titleLbl and subLbl then
		titleLbl.Text = "🥚 HATCHING " .. string.upper(sourceLabel) .. "..."
		titleLbl.TextColor3 = eggCol
		subLbl.Text = "Tap [SKIP] anytime to close"
	end

	local eggModel = buildEgg3DModel(eggId, eggCol, accCol)
	eggModel.Parent = vp

	task.spawn(function()
		-- 3 nhip rung lac trung trai-phai truoc khi nut vo
		for _, deg in ipairs({ 18, -22, 26, -26, 0 }) do
			if activeTicket ~= myTicket then return end
			SoundAndFxController.PlaySfx("Click")
			eggModel:PivotTo(CFrame.Angles(0, 0, math.rad(deg)))
			task.wait(0.11)
		end
		if activeTicket ~= myTicket then return end

		-- No anh sang trang vang & thay bang Pet Chibi 3D xoay tron!
		flash.BackgroundTransparency = 0.05
		TweenService:Create(flash, TweenInfo.new(0.38, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 1,
		}):Play()
		SoundAndFxController.PlaySfx("CatchRare")
		eggModel:Destroy()

		local petModel = PetModelBuilder.BuildPet(petDef, false, false)
		petModel.Parent = vp
		if titleLbl and subLbl then
			titleLbl.Text = string.format("🌟 [%s] %s!", string.upper(petDef.rarity), petDef.name)
			titleLbl.TextColor3 = rCol
			if petDef.isExclusive then
				subLbl.Text = string.format("👑 EXCLUSIVE • Scales %d%% of your Strongest Pet!", math.floor((petDef.scaleFactor or 1.0) * 100 + 0.5))
			else
				subLbl.Text = string.format("+%d%% Gold  •  +%d%% Strength  •  +%d%% Luck", math.floor(petDef.sellBonus * 100 + 0.5), math.floor(petDef.strengthBonus * 100 + 0.5), math.floor(petDef.luckBonus * 100 + 0.5))
			end
		end

		local t0 = os.clock()
		spinConn = RunService.RenderStepped:Connect(function()
			local yaw = (os.clock() - t0) * 2.2
			cam.CFrame = CFrame.lookAt(Vector3.new(math.sin(yaw) * 4.3, 1.1, math.cos(yaw) * 4.3), Vector3.zero)
		end)

		task.wait(1.85)
		if activeTicket == myTicket then
			EggHatchCutscene.Skip()
		end
	end)
end

function EggHatchCutscene.Init(rootGui: ScreenGui)
	local ov = Instance.new("Frame")
	ov.Name = "EggHatchCutscene"
	ov.AnchorPoint = Vector2.new(0.5, 0.5)
	ov.Position = UDim2.fromScale(0.5, 0.48)
	ov.Size = UDim2.fromOffset(360, 290)
	ov.BackgroundColor3 = Theme.Colors.PanelBg
	ov.Visible = false
	ov.ZIndex = 60
	ov.Parent = rootGui
	Theme.AddCorner(ov, 18)
	Theme.AddStroke(ov, Theme.Colors.Gold, 3)
	overlay = ov

	local vp = Instance.new("ViewportFrame")
	vp.Size = UDim2.new(1, -24, 0, 168)
	vp.Position = UDim2.fromOffset(12, 12)
	vp.BackgroundColor3 = Color3.fromRGB(16, 22, 38)
	vp.Ambient = Color3.fromRGB(196, 206, 228)
	vp.LightColor = Color3.fromRGB(255, 250, 236)
	vp.ZIndex = 61
	vp.Parent = ov
	Theme.AddCorner(vp, 12)
	vpFrame = vp

	local cam = Instance.new("Camera")
	cam.FieldOfView = 42
	cam.Parent = vp
	vp.CurrentCamera = cam
	vpCam = cam

	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.fromRGB(255, 248, 205)
	flash.BackgroundTransparency = 1
	flash.ZIndex = 64
	flash.Parent = ov
	Theme.AddCorner(flash, 18)
	flashFrame = flash

	local tLbl = Instance.new("TextLabel")
	tLbl.Size = UDim2.new(1, -20, 0, 28)
	tLbl.Position = UDim2.fromOffset(10, 184)
	tLbl.BackgroundTransparency = 1
	tLbl.Font = Theme.FontTitle
	tLbl.TextSize = 19
	tLbl.TextColor3 = Theme.Colors.Gold
	tLbl.ZIndex = 62
	tLbl.Parent = ov
	Theme.AddTextStroke(tLbl, 1.8)
	titleLbl = tLbl

	local sLbl = Instance.new("TextLabel")
	sLbl.Size = UDim2.new(1, -20, 0, 22)
	sLbl.Position = UDim2.fromOffset(10, 212)
	sLbl.BackgroundTransparency = 1
	sLbl.Font = Theme.FontBody
	sLbl.TextSize = 13
	sLbl.TextColor3 = Theme.Colors.TextMuted
	sLbl.ZIndex = 62
	sLbl.Parent = ov
	subLbl = sLbl

	local skipBtn = Theme.CreateButton(ov, "SkipHatchBtn", "⏭️ SKIP", UDim2.fromOffset(124, 34), UDim2.new(0.5, -62, 1, -44), Theme.Colors.Primary, EggHatchCutscene.Skip)
	skipBtn.TextSize = 14
	skipBtn.ZIndex = 65

	Net.OnClientEvent(Net.ServerToClient.EggHatched, function(payload: any)
		if type(payload) == "table" and type(payload.petId) == "string" then
			playHatchSequence(tostring(payload.eggId or ""), payload.petId, tostring(payload.source or "Pet Egg"))
		end
	end)
end

return EggHatchCutscene
