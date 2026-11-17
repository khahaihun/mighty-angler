--!strict
-- Theme.luau: Design System chuan Roblox Simulator hien dai (bo goc, UIStroke day, nut nhun lo xo, 6 mau do hiem)

local TweenService = game:GetService("TweenService")

local Theme = {}

Theme.Colors = {
	PanelBg = Color3.fromRGB(24, 32, 52),
	PanelInner = Color3.fromRGB(34, 45, 72),
	CardBg = Color3.fromRGB(42, 56, 88),
	CardOwned = Color3.fromRGB(36, 76, 68),
	StrokeDark = Color3.fromRGB(12, 16, 28),
	StrokeLight = Color3.fromRGB(88, 122, 184),
	TextPrimary = Color3.fromRGB(250, 252, 255),
	TextMuted = Color3.fromRGB(182, 198, 226),
	Gold = Color3.fromRGB(255, 208, 56),
	Gems = Color3.fromRGB(212, 102, 255),
	Strength = Color3.fromRGB(255, 108, 82),
	Success = Color3.fromRGB(64, 214, 116),
	Primary = Color3.fromRGB(54, 168, 255),
	Warning = Color3.fromRGB(255, 162, 52),
	Danger = Color3.fromRGB(242, 78, 86),
}

Theme.RarityColors = {
	Common = Color3.fromRGB(178, 188, 202),
	Uncommon = Color3.fromRGB(82, 224, 128),
	Rare = Color3.fromRGB(74, 168, 255),
	Epic = Color3.fromRGB(190, 102, 255),
	Legendary = Color3.fromRGB(255, 196, 56),
	Mythic = Color3.fromRGB(255, 82, 162),
	Boss = Color3.fromRGB(255, 76, 76),
}

Theme.FontTitle = Enum.Font.FredokaOne
Theme.FontBody = Enum.Font.GothamBold
Theme.FontLight = Enum.Font.GothamMedium

function Theme.AddCorner(parent: GuiObject, radiusPx: number): UICorner
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radiusPx)
	c.Parent = parent
	return c
end

function Theme.AddStroke(parent: GuiObject, color: Color3, thickness: number): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

function Theme.AddTextStroke(label: GuiObject, thickness: number?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = Theme.Colors.StrokeDark
	s.Thickness = thickness or 1.8
	s.Parent = label
	return s
end

function Theme.BindSpringButton(button: GuiButton, onClick: (() -> ())?)
	local existingScale = button:FindFirstChildOfClass("UIScale")
	local uiScale: UIScale
	if existingScale then
		uiScale = existingScale
	else
		local created = Instance.new("UIScale")
		created.Parent = button
		uiScale = created
	end

	button.MouseEnter:Connect(function()
		TweenService:Create(uiScale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1.05 }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(uiScale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1.0 }):Play()
	end)
	button.MouseButton1Down:Connect(function()
		TweenService:Create(uiScale, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 0.94 }):Play()
	end)
	button.MouseButton1Up:Connect(function()
		TweenService:Create(uiScale, TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.04 }):Play()
	end)

	if onClick then
		button.Activated:Connect(onClick)
	end
end

function Theme.CreateButton(
	parent: Instance,
	name: string,
	text: string,
	size: UDim2,
	pos: UDim2,
	bgColor: Color3,
	onClick: (() -> ())?
): TextButton
	local btn = Instance.new("TextButton")
	btn.Name = name
	btn.Size = size
	btn.Position = pos
	btn.BackgroundColor3 = bgColor
	btn.AutoButtonColor = false
	btn.Font = Theme.FontTitle
	btn.Text = text
	btn.TextColor3 = Theme.Colors.TextPrimary
	btn.TextSize = 18
	btn.Parent = parent

	Theme.AddCorner(btn, 10)
	Theme.AddStroke(btn, Theme.Colors.StrokeDark, 2.2)
	Theme.AddTextStroke(btn, 1.8)
	Theme.BindSpringButton(btn, onClick)
	return btn
end

return Theme
