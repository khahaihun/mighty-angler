--!strict
-- ViewportPool.luau: Quan ly tai su dung o luoi ViewportCard + Scroll-Window Virtualization (+1 hang dem)

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
local PAD_X = 8
local PAD_Y = 8
local MAX_FREE_POOL = 32

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

local function getUiScale(inst: Instance): number
	local sg = inst:FindFirstAncestorOfClass("ScreenGui")
	local sc = if sg then sg:FindFirstChildOfClass("UIScale") else nil
	return if sc then math.max(0.4, sc.Scale) else 1.0
end

function ViewportPool.CreateGrid(parent: Instance, layoutOrder: number, cellSize: UDim2?): GridHandle
	local resolvedCell = cellSize or UDim2.fromOffset(130, 152)
	local cellW = math.max(80, resolvedCell.X.Offset)
	local cellH = math.max(90, resolvedCell.Y.Offset)

	local gridFrame = Instance.new("Frame")
	gridFrame.Name = "ViewportGrid"
	gridFrame.Size = UDim2.new(1, 0, 0, 0)
	gridFrame.BackgroundTransparency = 1
	gridFrame.LayoutOrder = layoutOrder
	gridFrame.ZIndex = 21
	gridFrame.Parent = parent

	local scrollParent = if parent:IsA("ScrollingFrame")
		then parent
		else gridFrame:FindFirstAncestorWhichIsA("ScrollingFrame")

	local activeByKey: { [string]: ViewportCard.PooledCard } = {}
	local freeStack: { ViewportCard.PooledCard } = {}
	local currentSpecs: { ViewportCard.CardVisualSpec } = {}
	local currentFocusedKey: string? = nil

	local function releaseCard(key: string, card: ViewportCard.PooledCard)
		activeByKey[key] = nil
		card.root.Visible = false
		if focusedCardGlobal == card then
			setGlobalFocusedCard(nil)
		end
		if #freeStack < MAX_FREE_POOL then
			table.insert(freeStack, card)
		else
			card.root:Destroy()
		end
	end

	local function renderVisibleWindow()
		local totalItems = #currentSpecs
		if totalItems == 0 then
			gridFrame.Size = UDim2.new(1, 0, 0, 0)
			for k, c in pairs(activeByKey) do
				releaseCard(k, c)
			end
			return
		end

		local uiScale = getUiScale(gridFrame)
		local unscaledW = if gridFrame.AbsoluteSize.X > 8 then (gridFrame.AbsoluteSize.X / uiScale) else 564
		local cols = math.max(1, math.floor((unscaledW + PAD_X) / (cellW + PAD_X)))
		local totalRows = math.ceil(totalItems / cols)
		local totalHeight = totalRows * cellH + math.max(0, totalRows - 1) * PAD_Y
		gridFrame.Size = UDim2.new(1, 0, 0, totalHeight)

		local firstRow = 0
		local lastRow = totalRows - 1
		if scrollParent and totalItems > 16 then
			if scrollParent.AbsoluteSize.Y <= 4 then
				firstRow = 0
				lastRow = math.min(totalRows - 1, 3)
			else
				local visTop = math.max(0, (scrollParent.AbsolutePosition.Y - gridFrame.AbsolutePosition.Y) / uiScale)
				local visH = scrollParent.AbsoluteSize.Y / uiScale
				firstRow = math.max(0, math.floor(visTop / (cellH + PAD_Y)) - 1)
				lastRow = math.min(totalRows - 1, math.ceil((visTop + visH) / (cellH + PAD_Y)) + 1)
			end
		end

		local startIdx = firstRow * cols + 1
		local endIdx = math.min(totalItems, (lastRow + 1) * cols)
		local visibleKeys: { [string]: boolean } = {}
		for idx = startIdx, endIdx do
			visibleKeys[currentSpecs[idx].key] = true
		end

		for existingKey, existingCard in pairs(activeByKey) do
			if not visibleKeys[existingKey] then
				releaseCard(existingKey, existingCard)
			end
		end

		local nextFocusCard: ViewportCard.PooledCard? = nil
		for idx = startIdx, endIdx do
			local spec = currentSpecs[idx]
			local card = activeByKey[spec.key]
			if not card then
				local popped = table.remove(freeStack)
				card = popped or ViewportCard.CreateEmpty(gridFrame)
				activeByKey[spec.key] = card
			end
			local row = math.floor((idx - 1) / cols)
			local col = (idx - 1) % cols
			card.root.Size = UDim2.fromOffset(cellW, cellH)
			card.root.Position = UDim2.fromOffset(col * (cellW + PAD_X), row * (cellH + PAD_Y))
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

	if scrollParent then
		scrollParent:GetPropertyChangedSignal("CanvasPosition"):Connect(renderVisibleWindow)
		scrollParent:GetPropertyChangedSignal("AbsoluteSize"):Connect(renderVisibleWindow)
	end
	gridFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(renderVisibleWindow)

	local function syncItems(specs: { ViewportCard.CardVisualSpec }, focusedKey: string?)
		currentSpecs = specs
		currentFocusedKey = focusedKey
		renderVisibleWindow()
	end

	local function clearAll()
		currentSpecs = {}
		for k, c in pairs(activeByKey) do
			releaseCard(k, c)
		end
		gridFrame.Size = UDim2.new(1, 0, 0, 0)
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
