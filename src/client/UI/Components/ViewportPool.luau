--!strict
-- ViewportPool.luau: Quan ly tai su dung o luoi ViewportCard (khong dung lai 3D khi nhay tien, chi xoay 1 the dang chon)

local RunService = game:GetService("RunService")

local ViewportCard = require(script.Parent.ViewportCard)

export type GridHandle = {
	frame: Frame,
	SyncItems: (specs: { ViewportCard.CardVisualSpec }, focusedKey: string?) -> (),
	ClearAll: () -> (),
	SetFocusedKey: (key: string?) -> (),
}

local ViewportPool = {}

local focusedCardGlobal: ViewportCard.PooledCard? = nil
local spinConn: RBXScriptConnection? = nil
local DEFAULT_YAW = math.rad(34)

local function stopSpinIfIdle()
	if not focusedCardGlobal and spinConn then
		spinConn:Disconnect()
		spinConn = nil
	end
end

local function setGlobalFocusedCard(card: ViewportCard.PooledCard?)
	if focusedCardGlobal and focusedCardGlobal ~= card then
		ViewportCard.SetCameraAngle(focusedCardGlobal, DEFAULT_YAW)
	end
	focusedCardGlobal = card
	if card and not spinConn then
		spinConn = RunService.RenderStepped:Connect(function()
			local cur = focusedCardGlobal
			if not cur or not cur.root.Parent or not cur.root.Visible then
				focusedCardGlobal = nil
				stopSpinIfIdle()
				return
			end
			local yaw = DEFAULT_YAW + os.clock() * 1.35
			ViewportCard.SetCameraAngle(cur, yaw)
		end)
	elseif not card then
		stopSpinIfIdle()
	end
end

function ViewportPool.ClearFocus()
	setGlobalFocusedCard(nil)
end

function ViewportPool.CreateGrid(parent: Instance, layoutOrder: number, cellSize: UDim2?): GridHandle
	local gridFrame = Instance.new("Frame")
	gridFrame.Name = "ViewportGrid"
	gridFrame.Size = UDim2.new(1, 0, 0, 0)
	gridFrame.AutomaticSize = Enum.AutomaticSize.Y
	gridFrame.BackgroundTransparency = 1
	gridFrame.LayoutOrder = layoutOrder
	gridFrame.ZIndex = 21
	gridFrame.Parent = parent

	local grid = Instance.new("UIGridLayout")
	grid.CellSize = cellSize or UDim2.fromOffset(130, 152)
	grid.CellPadding = UDim2.fromOffset(8, 8)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = gridFrame

	local activeByKey: { [string]: ViewportCard.PooledCard } = {}
	local freeStack: { ViewportCard.PooledCard } = {}
	local currentFocusedKey: string? = nil

	local function releaseCard(key: string, card: ViewportCard.PooledCard)
		activeByKey[key] = nil
		card.root.Visible = false
		if focusedCardGlobal == card then
			setGlobalFocusedCard(nil)
		end
		if #freeStack < 72 then
			table.insert(freeStack, card)
		else
			card.root:Destroy()
		end
	end

	local function syncItems(specs: { ViewportCard.CardVisualSpec }, focusedKey: string?)
		currentFocusedKey = focusedKey
		local seen: { [string]: boolean } = {}
		for _, spec in ipairs(specs) do
			seen[spec.key] = true
		end
		for existingKey, existingCard in pairs(activeByKey) do
			if not seen[existingKey] then
				releaseCard(existingKey, existingCard)
			end
		end

		local nextFocusCard: ViewportCard.PooledCard? = nil
		for _, spec in ipairs(specs) do
			local card = activeByKey[spec.key]
			if not card then
				local popped = table.remove(freeStack)
				card = popped or ViewportCard.CreateEmpty(gridFrame)
				activeByKey[spec.key] = card
			end
			card.root.Visible = true
			ViewportCard.ApplySpec(card, spec, DEFAULT_YAW)
			if currentFocusedKey ~= nil and spec.key == currentFocusedKey then
				nextFocusCard = card
			end
		end

		if nextFocusCard then
			setGlobalFocusedCard(nextFocusCard)
		elseif focusedCardGlobal and focusedCardGlobal.root.Parent == gridFrame then
			setGlobalFocusedCard(nil)
		end
	end

	local function clearAll()
		for k, c in pairs(activeByKey) do
			releaseCard(k, c)
		end
	end

	local function setFocusedKey(key: string?)
		currentFocusedKey = key
		local found = if key then activeByKey[key] else nil
		setGlobalFocusedCard(found)
	end

	return {
		frame = gridFrame,
		SyncItems = syncItems,
		ClearAll = clearAll,
		SetFocusedKey = setFocusedKey,
	}
end

return ViewportPool
