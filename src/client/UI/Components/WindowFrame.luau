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
	Theme.AddCorner(root, 16)
	Theme.AddStroke(root, accentColor, 3)

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, -16, 0, 46)
	header.Position = UDim2.fromOffset(8, 8)
	header.BackgroundColor3 = Theme.Colors.PanelInner
	header.ZIndex = 21
	header.Parent = root
	Theme.AddCorner(header, 12)

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
