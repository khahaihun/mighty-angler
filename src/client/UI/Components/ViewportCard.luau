--!strict
-- ViewportCard.luau: O the vuong 3D ViewportFrame (hinh 3D lon chinh giua, nhan goc tren, thong so gon duoi day)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))

local Theme = require(script.Parent.Parent.Theme)

export type CardModelSpec = {
	kind: "Fish" | "Pet" | "Egg" | "Rod" | "Potion" | "Bait" | "Gear",
	primaryColor: Color3,
	secondaryColor: Color3,
	mutation: string?,
	silhouette: boolean?,
	modelRefData: any?,
}

export type CardVisualSpec = {
	key: string,
	order: number,
	title: string,
	subtitle: string,
	footerText: string,
	footerColor: Color3,
	strokeColor: Color3,
	bgColor: Color3,
	topLeftBadge: string?,
	topLeftColor: Color3?,
	cornerIcon: string?,
	cornerColor: Color3?,
	modelSignature: string,
	modelSpec: CardModelSpec,
	onActivate: () -> (),
	onCornerActivate: (() -> ())?,
}

export type PooledCard = {
	root: TextButton,
	viewport: ViewportFrame,
	cam: Camera,
	model: Model?,
	baseDist: number,
	modelSignature: string,
	badgeLbl: TextLabel,
	cornerBtn: TextButton,
	titleLbl: TextLabel,
	subLbl: TextLabel,
	footerPill: Frame,
	footerLbl: TextLabel,
	stroke: UIStroke,
	onActivateRef: (() -> ())?,
	onCornerRef: (() -> ())?,
}

local ViewportCard = {}

local function tryBuildViaSharedBuilders(spec: CardModelSpec): Model?
	local mbFolder = Shared:FindFirstChild("ModelBuilders")
	if not mbFolder then
		return nil
	end
	if spec.kind == "Fish" and spec.modelRefData then
		local fm = mbFolder:FindFirstChild("FishModelBuilder")
		if fm and fm:IsA("ModuleScript") then
			local builder = require(fm) :: any
			return builder.BuildFish(spec.modelRefData, spec.mutation or "None", spec.silhouette == true)
		end
	elseif spec.kind == "Pet" and spec.modelRefData then
		local pm = mbFolder:FindFirstChild("PetModelBuilder")
		if pm and pm:IsA("ModuleScript") then
			return (require(pm) :: any).BuildPet(spec.modelRefData, spec.silhouette == true)
		end
	elseif spec.kind == "Egg" and spec.modelRefData then
		local pm = mbFolder:FindFirstChild("PetModelBuilder")
		if pm and pm:IsA("ModuleScript") then
			return (require(pm) :: any).BuildEggPreview(spec.modelRefData)
		end
	elseif spec.kind == "Rod" and spec.modelRefData then
		local rm = mbFolder:FindFirstChild("RodAndWeightBuilder")
		if rm and rm:IsA("ModuleScript") then
			local builder = require(rm) :: any
			return builder.BuildRodPreview(spec.modelRefData)
		end
	end
	return nil
end

local function makePreviewPart(m: Model, shape: Enum.PartType, sz: Vector3, cf: CFrame, col: Color3, mat: Enum.Material): Part
	local p = Instance.new("Part")
	p.Shape = shape
	p.Size = sz
	p.CFrame = cf
	p.Color = col
	p.Material = mat
	p.Anchored = true
	p.CanCollide = false
	p.Parent = m
	return p
end

local function buildFallbackPreviewModel(spec: CardModelSpec): (Model, number)
	local viaBuilder = tryBuildViaSharedBuilders(spec)
	if viaBuilder then
		local dist = if spec.kind == "Rod" then 6.2 elseif spec.kind == "Fish" then 4.6 else 4.0
		return viaBuilder, dist
	end

	local m = Instance.new("Model")
	local c1 = if spec.silhouette then Color3.fromRGB(22, 26, 38) else spec.primaryColor
	local c2 = if spec.silhouette then Color3.fromRGB(32, 38, 54) else spec.secondaryColor
	local mat = Enum.Material.SmoothPlastic
	if not spec.silhouette then
		if spec.mutation == "Shiny" then
			c1 = GameConfig.Mutations.Shiny.color
			mat = Enum.Material.Neon
		elseif spec.mutation == "Golden" then
			c1 = GameConfig.Mutations.Golden.color
			mat = Enum.Material.Foil
		elseif spec.mutation == "Cosmic" then
			c1 = GameConfig.Mutations.Cosmic.color
			mat = Enum.Material.Neon
		end
	end

	if spec.kind == "Fish" then
		local body = makePreviewPart(m, Enum.PartType.Ball, Vector3.new(1.1, 1.35, 2.45), CFrame.new(), c1, mat)
		m.PrimaryPart = body
		local tail = Instance.new("WedgePart")
		tail.Size = Vector3.new(0.32, 1.45, 1.1)
		tail.CFrame = CFrame.new(0, 0, 1.45)
		tail.Color = c2
		tail.Anchored = true
		tail.Parent = m
		local dorsal = Instance.new("WedgePart")
		dorsal.Size = Vector3.new(0.24, 0.72, 0.95)
		dorsal.CFrame = CFrame.new(0, 0.78, 0.05)
		dorsal.Color = c2
		dorsal.Anchored = true
		dorsal.Parent = m
		if not spec.silhouette then
			makePreviewPart(m, Enum.PartType.Ball, Vector3.new(0.24, 0.24, 0.24), CFrame.new(0.42, 0.24, -0.82), Color3.fromRGB(20, 24, 34), Enum.Material.SmoothPlastic)
			makePreviewPart(m, Enum.PartType.Ball, Vector3.new(0.24, 0.24, 0.24), CFrame.new(-0.42, 0.24, -0.82), Color3.fromRGB(20, 24, 34), Enum.Material.SmoothPlastic)
		end
		return m, 4.3
	elseif spec.kind == "Pet" then
		local head = makePreviewPart(m, Enum.PartType.Ball, Vector3.new(1.85, 1.75, 1.9), CFrame.new(), c1, mat)
		m.PrimaryPart = head
		makePreviewPart(m, Enum.PartType.Block, Vector3.new(0.7, 0.45, 0.9), CFrame.new(-1.05, 0.15, 0.1) * CFrame.Angles(0, 0, math.rad(18)), c2, Enum.Material.SmoothPlastic)
		makePreviewPart(m, Enum.PartType.Block, Vector3.new(0.7, 0.45, 0.9), CFrame.new(1.05, 0.15, 0.1) * CFrame.Angles(0, 0, math.rad(-18)), c2, Enum.Material.SmoothPlastic)
		if not spec.silhouette then
			makePreviewPart(m, Enum.PartType.Ball, Vector3.new(0.34, 0.34, 0.34), CFrame.new(-0.42, 0.2, -0.84), Color3.fromRGB(18, 22, 32), Enum.Material.SmoothPlastic)
			makePreviewPart(m, Enum.PartType.Ball, Vector3.new(0.34, 0.34, 0.34), CFrame.new(0.42, 0.2, -0.84), Color3.fromRGB(18, 22, 32), Enum.Material.SmoothPlastic)
		end
		return m, 3.8
	elseif spec.kind == "Egg" then
		local egg = makePreviewPart(m, Enum.PartType.Ball, Vector3.new(1.95, 2.45, 1.95), CFrame.new(), c1, Enum.Material.SmoothPlastic)
		m.PrimaryPart = egg
		makePreviewPart(m, Enum.PartType.Cylinder, Vector3.new(0.32, 2.02, 2.02), CFrame.new(0, -0.15, 0) * CFrame.Angles(0, 0, math.rad(90)), c2, Enum.Material.Neon)
		return m, 4.0
	elseif spec.kind == "Rod" then
		local shaft = makePreviewPart(m, Enum.PartType.Block, Vector3.new(0.22, 4.6, 0.22), CFrame.Angles(0, 0, math.rad(-32)), c1, Enum.Material.SmoothPlastic)
		m.PrimaryPart = shaft
		makePreviewPart(m, Enum.PartType.Cylinder, Vector3.new(0.42, 0.85, 0.85), CFrame.new(0.55, -1.2, 0), c2, Enum.Material.Neon)
		makePreviewPart(m, Enum.PartType.Ball, Vector3.new(0.48, 0.48, 0.48), CFrame.new(-1.15, 1.85, 0), c2, Enum.Material.Neon)
		return m, 5.4
	elseif spec.kind == "Potion" then
		local flask = makePreviewPart(m, Enum.PartType.Ball, Vector3.new(1.75, 1.75, 1.75), CFrame.new(0, -0.25, 0), c1, Enum.Material.Neon)
		m.PrimaryPart = flask
		makePreviewPart(m, Enum.PartType.Cylinder, Vector3.new(0.95, 0.65, 0.65), CFrame.new(0, 0.85, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(220, 232, 248), Enum.Material.Glass)
		return m, 3.8
	else
		local item = makePreviewPart(m, Enum.PartType.Block, Vector3.new(1.65, 1.35, 1.65), CFrame.Angles(math.rad(14), math.rad(28), 0), c1, Enum.Material.SmoothPlastic)
		m.PrimaryPart = item
		makePreviewPart(m, Enum.PartType.Ball, Vector3.new(0.9, 0.9, 0.9), CFrame.new(0, 0.75, 0), c2, Enum.Material.Neon)
		return m, 3.9
	end
end

function ViewportCard.CreateEmpty(parent: Instance): PooledCard
	local root = Instance.new("TextButton")
	root.Size = UDim2.fromOffset(128, 150)
	root.BackgroundColor3 = Theme.Colors.CardBg
	root.AutoButtonColor = false
	root.Text = ""
	root.ZIndex = 22
	root.Parent = parent
	Theme.AddCorner(root, 12)
	Theme.AddGradient(root)
	local stroke = Theme.AddStroke(root, Theme.Colors.StrokeLight, 2)

	local vp = Instance.new("ViewportFrame")
	vp.Size = UDim2.new(1, -12, 0, 70)
	vp.Position = UDim2.fromOffset(6, 18)
	vp.BackgroundColor3 = Color3.fromRGB(16, 22, 36)
	vp.BackgroundTransparency = 0.25
	vp.Ambient = Color3.fromRGB(186, 198, 220)
	vp.LightColor = Color3.fromRGB(255, 252, 240)
	vp.LightDirection = Vector3.new(-1, -1.2, -1)
	vp.ZIndex = 23
	vp.Parent = root
	Theme.AddCorner(vp, 9)

	local cam = Instance.new("Camera")
	cam.FieldOfView = 42
	cam.Parent = vp
	vp.CurrentCamera = cam

	local badge = Instance.new("TextLabel")
	badge.Size = UDim2.new(0.72, 0, 0, 18)
	badge.Position = UDim2.fromOffset(6, 1)
	badge.BackgroundTransparency = 1
	badge.Font = Theme.FontTitle
	Theme.FitText(badge, 13, 11)
	badge.TextXAlignment = Enum.TextXAlignment.Left
	badge.TextColor3 = Theme.Colors.Gold
	badge.ZIndex = 25
	badge.Parent = root
	Theme.AddTextStroke(badge, 1.3)

	local cornerBtn = Instance.new("TextButton")
	cornerBtn.Size = UDim2.fromOffset(24, 24)
	cornerBtn.Position = UDim2.new(1, -28, 0, 4)
	cornerBtn.BackgroundColor3 = Color3.fromRGB(28, 36, 58)
	cornerBtn.Font = Theme.FontTitle
	cornerBtn.TextSize = 13
	cornerBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	cornerBtn.ZIndex = 26
	cornerBtn.Visible = false
	cornerBtn.Parent = root
	Theme.AddCorner(cornerBtn, 6)

	local titleLbl = Instance.new("TextLabel")
	titleLbl.Size = UDim2.new(1, -10, 0, 18)
	titleLbl.Position = UDim2.fromOffset(5, 89)
	titleLbl.BackgroundTransparency = 1
	titleLbl.Font = Theme.FontTitle
	Theme.FitText(titleLbl, 13, 12)
	titleLbl.TextTruncate = Enum.TextTruncate.AtEnd
	titleLbl.TextColor3 = Theme.Colors.TextPrimary
	titleLbl.ZIndex = 24
	titleLbl.Parent = root
	Theme.AddTextStroke(titleLbl, 1.3)

	local subLbl = Instance.new("TextLabel")
	subLbl.Size = UDim2.new(1, -10, 0, 18)
	subLbl.Position = UDim2.fromOffset(5, 107)
	subLbl.BackgroundTransparency = 1
	subLbl.Font = Theme.FontBody
	Theme.FitText(subLbl, 13, 11)
	subLbl.TextTruncate = Enum.TextTruncate.AtEnd
	subLbl.TextColor3 = Theme.Colors.TextMuted
	subLbl.ZIndex = 24
	subLbl.Parent = root

	local footerPill = Instance.new("Frame")
	footerPill.Size = UDim2.new(1, -12, 0, 20)
	footerPill.Position = UDim2.fromOffset(6, 126)
	footerPill.BackgroundColor3 = Theme.Colors.Primary
	footerPill.ZIndex = 24
	footerPill.Parent = root
	Theme.AddCorner(footerPill, 6)

	local footerLbl = Instance.new("TextLabel")
	footerLbl.Size = UDim2.fromScale(1, 1)
	footerLbl.BackgroundTransparency = 1
	footerLbl.Font = Theme.FontTitle
	Theme.FitText(footerLbl, 13, 11)
	footerLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
	footerLbl.ZIndex = 25
	footerLbl.Parent = footerPill
	Theme.AddTextStroke(footerLbl, 1.2)

	local card: PooledCard = {
		root = root,
		viewport = vp,
		cam = cam,
		model = nil,
		baseDist = 4.2,
		modelSignature = "",
		badgeLbl = badge,
		cornerBtn = cornerBtn,
		titleLbl = titleLbl,
		subLbl = subLbl,
		footerPill = footerPill,
		footerLbl = footerLbl,
		stroke = stroke,
		onActivateRef = nil,
		onCornerRef = nil,
	}

	root.Activated:Connect(function()
		if card.onActivateRef then card.onActivateRef() end
	end)
	cornerBtn.Activated:Connect(function()
		if card.onCornerRef then card.onCornerRef() end
	end)
	return card
end

function ViewportCard.ApplySpec(card: PooledCard, spec: CardVisualSpec, yawRad: number)
	card.root.Name = "Card_" .. spec.key
	card.root.LayoutOrder = spec.order
	card.root.BackgroundColor3 = spec.bgColor
	card.stroke.Color = spec.strokeColor
	card.titleLbl.Text = spec.title
	card.titleLbl.TextColor3 = spec.strokeColor
	card.subLbl.Text = spec.subtitle
	card.footerPill.BackgroundColor3 = spec.footerColor
	card.footerLbl.Text = spec.footerText
	card.onActivateRef = spec.onActivate
	card.onCornerRef = spec.onCornerActivate

	card.badgeLbl.Text = spec.topLeftBadge or ""
	card.badgeLbl.TextColor3 = spec.topLeftColor or Theme.Colors.Gold

	if spec.cornerIcon and spec.onCornerActivate then
		card.cornerBtn.Visible = true
		card.cornerBtn.Text = spec.cornerIcon
		card.cornerBtn.BackgroundColor3 = spec.cornerColor or Color3.fromRGB(34, 44, 68)
	else
		card.cornerBtn.Visible = false
	end

	if card.modelSignature ~= spec.modelSignature then
		card.modelSignature = spec.modelSignature
		if card.model then
			card.model:Destroy()
			card.model = nil
		end
		local builtModel, dist = buildFallbackPreviewModel(spec.modelSpec)
		builtModel.Parent = card.viewport
		card.model = builtModel
		card.baseDist = dist
	end

	ViewportCard.SetCameraAngle(card, yawRad)
end

function ViewportCard.SetCameraAngle(card: PooledCard, yawRad: number)
	local d = card.baseDist
	local camPos = Vector3.new(math.sin(yawRad) * d, d * 0.34, math.cos(yawRad) * d)
	card.cam.CFrame = CFrame.lookAt(camPos, Vector3.zero)
end

return ViewportCard
