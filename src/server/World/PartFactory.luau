--!strict
-- PartFactory.luau: Bo tao BasePart chuan API Roblox Engine (100% khong dung class ao hay Terrain material)

local PartFactory = {}

function PartFactory.Block(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?,
	canCollide: boolean?,
	transparency: number?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = Enum.PartType.Block
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = true
	p.CanCollide = if canCollide == nil then true else canCollide
	p.Transparency = transparency or 0
	p.Parent = parent
	return p
end

function PartFactory.VerticalCylinder(
	parent: Instance,
	name: string,
	height: number,
	diameter: number,
	centerCf: CFrame,
	color: Color3,
	material: Enum.Material?,
	canCollide: boolean?,
	transparency: number?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = Enum.PartType.Cylinder
	-- Truc Cylinder cua Roblox nam doc theo truc X, xoay Z 90 do de dung thang
	p.Size = Vector3.new(height, diameter, diameter)
	p.CFrame = centerCf * CFrame.Angles(0, 0, math.rad(90))
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = true
	p.CanCollide = if canCollide == nil then true else canCollide
	p.Transparency = transparency or 0
	p.Parent = parent
	return p
end

function PartFactory.Ball(
	parent: Instance,
	name: string,
	diameter: number,
	position: Vector3,
	color: Color3,
	material: Enum.Material?,
	canCollide: boolean?,
	transparency: number?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.new(diameter, diameter, diameter)
	p.Position = position
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = true
	p.CanCollide = if canCollide == nil then false else canCollide
	p.Transparency = transparency or 0
	p.Parent = parent
	return p
end

function PartFactory.Wedge(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?,
	canCollide: boolean?
): WedgePart
	local w = Instance.new("WedgePart")
	w.Name = name
	w.Size = size
	w.CFrame = cf
	w.Color = color
	w.Material = material or Enum.Material.SmoothPlastic
	w.TopSurface = Enum.SurfaceType.Smooth
	w.BottomSurface = Enum.SurfaceType.Smooth
	w.Anchored = true
	w.CanCollide = if canCollide == nil then true else canCollide
	w.Parent = parent
	return w
end

function PartFactory.AddBillboard(
	adornee: BasePart,
	title: string,
	subtitle: string,
	titleColor: Color3,
	offsetY: number?
): BillboardGui
	local bb = Instance.new("BillboardGui")
	bb.Name = "InfoBillboard"
	bb.Adornee = adornee
	bb.Size = UDim2.fromOffset(210, 64)
	bb.StudsOffset = Vector3.new(0, offsetY or 4.5, 0)
	bb.AlwaysOnTop = false
	bb.MaxDistance = 95
	bb.Parent = adornee

	local titleLbl = Instance.new("TextLabel")
	titleLbl.Name = "Title"
	titleLbl.Size = UDim2.fromScale(1, 0.56)
	titleLbl.BackgroundTransparency = 1
	titleLbl.Font = Enum.Font.FredokaOne
	titleLbl.Text = title
	titleLbl.TextColor3 = titleColor
	titleLbl.TextScaled = true
	titleLbl.Parent = bb

	local s1 = Instance.new("UIStroke")
	s1.Thickness = 2
	s1.Color = Color3.fromRGB(18, 24, 38)
	s1.Parent = titleLbl

	local subLbl = Instance.new("TextLabel")
	subLbl.Name = "Subtitle"
	subLbl.Position = UDim2.fromScale(0, 0.56)
	subLbl.Size = UDim2.fromScale(1, 0.44)
	subLbl.BackgroundTransparency = 1
	subLbl.Font = Enum.Font.GothamBold
	subLbl.Text = subtitle
	subLbl.TextColor3 = Color3.fromRGB(245, 248, 255)
	subLbl.TextScaled = true
	subLbl.Parent = bb

	local s2 = Instance.new("UIStroke")
	s2.Thickness = 1.6
	s2.Color = Color3.fromRGB(18, 24, 38)
	s2.Parent = subLbl

	return bb
end

function PartFactory.AddPrompt(
	parent: BasePart,
	actionText: string,
	objectText: string,
	maxDistance: number,
	promptKind: string,
	attributes: { [string]: any }?
): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.MaxActivationDistance = maxDistance
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("PromptKind", promptKind)
	if attributes then
		for k, v in pairs(attributes) do
			prompt:SetAttribute(k, v)
		end
	end
	prompt.Parent = parent
	return prompt
end

function PartFactory.AddWarmLight(parent: Instance, color: Color3, range: number?, brightness: number?): PointLight
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range or 18
	light.Brightness = brightness or 1.2
	light.Shadows = false
	light.Parent = parent
	return light
end

return PartFactory
