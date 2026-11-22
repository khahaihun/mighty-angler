--!strict
-- WindowFrame.luau: Khung cua so Modal dung chung (tieu de, nut X nhun lo xo, thanh Tab va vung cuon)

local Theme = require(script.Parent.Parent.Theme)

export type BuiltWindow = {
	root: Frame,
	tabBar: Frame,
	body: ScrollingFrame,
	SetVisible: (visible: boolean) -> (),
	IsVisible: () -> boolean,
	OnVisibilityChanged: (cb: (boolean) -> ()) -> (),
	AddTab: (tabName: string, onSelect: () -> ()) -> TextButton,
	SetActiveTab: (activeBtn: TextButton) -> (),
}

local WindowFrame = {}

export type Rect = { x: number, y: number, w: number, h: number }
function WindowFrame.ComputeLayout(width: number, height: number, insets: { number }?): { [string]: Rect }
	if width <= 0 or height <= 0 then return {} end
	local i = insets or { 0, 0, 0, 0 }
	local x, y = i[1], i[2]
	local w, h = math.max(1, width - x - i[3]), math.max(1, height - y - i[4])
	local function rect(rx: number, ry: number, rw: number, rh: number): Rect
		return { x = x + rx, y = y + ry, w = rw, h = rh }
	end
	local center, cw = 164, math.max(1, w - 384)
	return {
		TopCurrencyBar = rect((w - 536) / 2, 8, 536, 44),
		RodStrengthHint = rect(center, 54, cw, 18), LiveOddsBanner = rect(center, 74, cw, 18),
		IslandTag = rect(14, 8, 140, 28), EventBanner = rect(14, 40, 140, 40),
		LeftMenuDock = rect(14, 96, 136, 336),
		OnboardingHint = rect(center + (cw - math.min(600, cw)) / 2, h - 216, math.min(600, cw), 36),
		ToastStack = rect(w - 208, 96, 192, 126),
		GymActiveBanner = rect(center + (cw - 380) / 2, h - 176, 380, 32),
		CastPowerBar = rect((w - 310) / 2, h - 140, 310, 26),
		AboveHotbarAutoRow = rect((w - 520) / 2, h - 108, 520, 34),
		CustomHotbar = rect((w - 490) / 2, h - 68, 490, 62),
		QuickBaitBtn = rect(w - 208, h - 64, 192, 46),
		QuickBaitPopup = rect(w - 208, h - 298, 192, 228),
		Window = rect(center, 96, cw, math.max(114, h - 320)),
	}
end

local probes: { [ScreenGui]: ScreenGui? } = {}
function WindowFrame.BindLayout(gui: ScreenGui, object: GuiObject, key: string, maximum: Vector2?)
	local probe = probes[gui]
	if not probe then
		local created = Instance.new("ScreenGui")
		created.Name = "MobileLayoutProbe"
		created.ResetOnSpawn = false
		created.IgnoreGuiInset = gui.IgnoreGuiInset
		created.ScreenInsets = gui.ScreenInsets
		created.Parent = gui.Parent
		probes[gui] = created
		probe = created
		gui.Destroying:Connect(function() created:Destroy(); probes[gui] = nil end)
	end
	local screenProbe = probe :: ScreenGui
	local scale = gui:FindFirstChildOfClass("UIScale")
	local function update()
		local s = if scale then scale.Scale else 1
		local size = screenProbe.AbsoluteSize / s
		if size.X <= 0 or size.Y <= 0 then return end
		local r = WindowFrame.ComputeLayout(size.X, size.Y)[key]
		local w = if maximum then math.min(r.w, maximum.X) else r.w
		local h = if maximum then math.min(r.h, maximum.Y) else r.h
		object.AnchorPoint = Vector2.zero
		object.Position = UDim2.fromOffset(r.x + (r.w - w) / 2, r.y + (r.h - h) / 2)
		object.Size = UDim2.fromOffset(w, h)
	end
	local resize = screenProbe:GetPropertyChangedSignal("AbsoluteSize"):Connect(update)
	local rescale = if scale then scale:GetPropertyChangedSignal("Scale"):Connect(update) else nil
	object.Destroying:Connect(function() resize:Disconnect(); if rescale then rescale:Disconnect() end end)
	update()
end

function WindowFrame.Create(
	parentGui: ScreenGui,
	windowName: string,
	titleText: string,
	size: UDim2,
	accentColor: Color3
): BuiltWindow
	local root = Instance.new("Frame")
	root.Name = windowName
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = size
	root.BackgroundColor3 = Theme.Colors.PanelBg
	root.Visible = false
	root.ZIndex = 20
	root.Parent = parentGui
	WindowFrame.BindLayout(parentGui, root, "Window", Vector2.new(size.X.Offset, size.Y.Offset))
	Theme.AddCorner(root, 16)
	Theme.AddGradient(root)
	Theme.AddStroke(root, accentColor, 3)

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, -16, 0, 46)
	header.Position = UDim2.fromOffset(8, 8)
	header.BackgroundColor3 = Theme.Colors.PanelInner
	header.ZIndex = 21
	header.Parent = root
	Theme.AddCorner(header, 12)
	Theme.AddGradient(header)

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -66, 1, 0)
	title.Position = UDim2.fromOffset(16, 0)
	title.BackgroundTransparency = 1
	title.Font = Theme.FontTitle
	title.TextSize = 23
	title.TextColor3 = accentColor
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = titleText
	title.ZIndex = 22
	title.Parent = header
	Theme.AddTextStroke(title, 2)

	local visCallbacks: { (boolean) -> () } = {}
	local function setWindowVisible(v: boolean)
		if root.Visible == v then
			return
		end
		root.Visible = v
		for _, cb in ipairs(visCallbacks) do
			task.spawn(cb, v)
		end
	end

	local closeBtn = Theme.CreateButton(
		header,
		"CloseButton",
		"X",
		UDim2.fromOffset(36, 36),
		UDim2.new(1, -41, 0.5, -18),
		Theme.Colors.Danger,
		function()
			setWindowVisible(false)
		end
	)
	closeBtn.ZIndex = 23

	local tabBar = Instance.new("Frame")
	tabBar.Name = "TabBar"
	tabBar.Size = UDim2.new(1, -20, 0, 36)
	tabBar.Position = UDim2.fromOffset(10, 60)
	tabBar.BackgroundTransparency = 1
	tabBar.ZIndex = 21
	tabBar.Parent = root

	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.Padding = UDim.new(0, 8)
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabLayout.Parent = tabBar

	local body = Instance.new("ScrollingFrame")
	body.Name = "BodyScroll"
	body.Size = UDim2.new(1, -20, 1, -112)
	body.Position = UDim2.fromOffset(10, 102)
	body.BackgroundColor3 = Theme.Colors.PanelInner
	body.BorderSizePixel = 0
	body.ScrollBarThickness = 6
	body.ScrollBarImageColor3 = accentColor
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.CanvasSize = UDim2.fromOffset(0, 0)
	body.ZIndex = 21
	body.Parent = root
	Theme.AddCorner(body, 12)

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 10)
	pad.PaddingBottom = UDim.new(0, 12)
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 12)
	pad.Parent = body

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 8)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = body

	local tabButtons: { TextButton } = {}

	local function setActiveTab(activeBtn: TextButton)
		for _, b in ipairs(tabButtons) do
			b.BackgroundColor3 = if b == activeBtn then accentColor else Theme.Colors.CardBg
		end
	end

	local function addTab(tabName: string, onSelect: () -> ()): TextButton
		local btn = Theme.CreateButton(
			tabBar,
			"Tab_" .. tabName,
			tabName,
			UDim2.fromOffset(122, 34),
			UDim2.fromOffset(0, 0),
			Theme.Colors.CardBg,
			nil
		)
		btn.TextSize = 16
		btn.ZIndex = 22
		table.insert(tabButtons, btn)
		btn.Activated:Connect(function()
			setActiveTab(btn)
			onSelect()
		end)
		return btn
	end

	return {
		root = root,
		tabBar = tabBar,
		body = body,
		SetVisible = setWindowVisible,
		IsVisible = function(): boolean
			return root.Visible
		end,
		OnVisibilityChanged = function(cb: (boolean) -> ())
			table.insert(visCallbacks, cb)
		end,
		AddTab = addTab,
		SetActiveTab = setActiveTab,
	}
end

return WindowFrame
