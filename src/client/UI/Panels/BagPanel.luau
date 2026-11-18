--!strict
-- BagPanel.luau: Tui do O Luoi 3D (ViewportPool) — Khoa Ca (Lock), Ban Chon Loc (Multi-Select), Ghim Hotbar 2..5 & Bao Ve Soulbound

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local IslandsRegistry = require(Shared:WaitForChild("Config"):WaitForChild("Islands"))
local PotionsConfig = require(Shared:WaitForChild("Config"):WaitForChild("PotionsConfig"))
local BaitConfig = require(Shared:WaitForChild("Config"):WaitForChild("BaitConfig"))

local Theme = require(script.Parent.Parent.Theme)
local WindowFrame = require(script.Parent.Parent.Components.WindowFrame)
local ViewportCard = require(script.Parent.Parent.Components.ViewportCard)
local ViewportPool = require(script.Parent.Parent.Components.ViewportPool)

local BagPanel = {}

local win: WindowFrame.BuiltWindow? = nil
local toolbarFrame: Frame? = nil
local inspectorFrame: Frame? = nil
local emptyLbl: TextLabel? = nil
local gridHandle: ViewportPool.GridHandle? = nil

local currentTab = "Fish"
local multiSelectMode = false
local selectedUids: { [string]: boolean } = {}
local inspectedFishUid: string? = nil

local fishBagCache: { Types.CaughtFish } = {}
local potionsCache: { [string]: number } = {}
local baitCache: { [string]: number } = {}
local activeBaitCache: string? = nil

local function clearFrameChildren(f: Frame)
	for _, ch in ipairs(f:GetChildren()) do
		if ch:IsA("GuiObject") then ch:Destroy() end
	end
end

local function findFishEntry(uid: string?): Types.CaughtFish?
	if not uid then return nil end
	for _, f in ipairs(fishBagCache) do
		if f.uid == uid then return f end
	end
	return nil
end

local function countSelected(): (number, { string })
	local list: { string } = {}
	for _, f in ipairs(fishBagCache) do
		if selectedUids[f.uid] and not f.locked and not f.soulbound then
			table.insert(list, f.uid)
		end
	end
	return #list, list
end

local function rebuildFishToolbarAndInspector()
	local tb = toolbarFrame
	local ins = inspectorFrame
	if not tb or not ins then return end
	clearFrameChildren(tb)
	clearFrameChildren(ins)

	if currentTab ~= "Fish" then
		tb.Visible = false
		ins.Visible = false
		return
	end
	tb.Visible = true

	local unlockedVal = 0
	for _, f in ipairs(fishBagCache) do
		if not f.locked and not f.soulbound then unlockedVal += f.sellValue end
	end
	local selCount, selList = countSelected()

	local sumLbl = Instance.new("TextLabel")
	sumLbl.Size = UDim2.new(0.42, 0, 1, 0)
	sumLbl.BackgroundTransparency = 1
	sumLbl.Font = Theme.FontTitle
	sumLbl.TextSize = 14
	sumLbl.TextXAlignment = Enum.TextXAlignment.Left
	sumLbl.TextColor3 = Theme.Colors.TextPrimary
	sumLbl.Text = string.format("🎒 %d/%d  •  Unlocked: %sG", #fishBagCache, GameConfig.BAG_CAPACITY, Util.FormatNumber(unlockedVal))
	sumLbl.ZIndex = 23
	sumLbl.Parent = tb
	Theme.AddTextStroke(sumLbl, 1.4)

	local modeBtn = Theme.CreateButton(tb, "MultiModeBtn", if multiSelectMode then "✖ Exit Select" else "☑️ Multi-Select", UDim2.fromOffset(118, 34), UDim2.new(1, -284, 0.5, -17), if multiSelectMode then Theme.Colors.Warning else Theme.Colors.Primary, function()
		multiSelectMode = not multiSelectMode
		table.clear(selectedUids)
		BagPanel.Render()
	end)
	modeBtn.TextSize = 13; modeBtn.ZIndex = 24

	local sellBtnLabel = if multiSelectMode then string.format("💰 Sell (%d)", selCount) else "💰 Sell Unlocked"
	local sellBtn = Theme.CreateButton(tb, "MainSellBtn", sellBtnLabel, UDim2.fromOffset(156, 34), UDim2.new(1, -158, 0.5, -17), Theme.Colors.Success, function()
		if multiSelectMode then
			if #selList > 0 then
				Net.FireServer(Net.ClientToServer.SellSelectedFish, selList)
				table.clear(selectedUids)
			end
		else
			Net.FireServer(Net.ClientToServer.SellAllFish)
		end
	end)
	sellBtn.TextSize = 13; sellBtn.ZIndex = 24

	local focused = findFishEntry(inspectedFishUid)
	if not focused or multiSelectMode then
		ins.Visible = false
		return
	end
	ins.Visible = true

	local def = IslandsRegistry.GetFish(focused.fishId)
	local fName = if def then def.name else focused.fishId
	local infoLbl = Instance.new("TextLabel")
	infoLbl.Size = UDim2.new(0.38, 0, 1, 0)
	infoLbl.Position = UDim2.fromOffset(10, 0)
	infoLbl.BackgroundTransparency = 1
	infoLbl.Font = Theme.FontTitle
	infoLbl.TextSize = 13
	infoLbl.TextXAlignment = Enum.TextXAlignment.Left
	infoLbl.TextColor3 = Theme.Colors.Gold
	infoLbl.Text = string.format("%s (%s)%s", fName, Util.FormatWeight(focused.weight), if focused.soulbound then " 🏆" else "")
	infoLbl.ZIndex = 23
	infoLbl.Parent = ins

	local lockBtn = Theme.CreateButton(ins, "LockAct", if focused.locked then "🔓 Unlock" else "🔒 Lock", UDim2.fromOffset(76, 30), UDim2.new(1, -342, 0.5, -15), if focused.locked then Theme.Colors.Warning else Theme.Colors.CardBg, function()
		Net.FireServer(Net.ClientToServer.ToggleLockFish, focused.uid)
	end)
	lockBtn.TextSize = 12; lockBtn.ZIndex = 24

	for slot = 2, 5 do
		local xOff = -260 + (slot - 2) * 46
		local pBtn = Theme.CreateButton(ins, "Pin" .. tostring(slot), "📌" .. tostring(slot), UDim2.fromOffset(42, 30), UDim2.new(1, xOff, 0.5, -15), Theme.Colors.Primary, function()
			Net.FireServer(Net.ClientToServer.PinFishToSlot, tostring(slot), focused.uid)
		end)
		pBtn.TextSize = 12; pBtn.ZIndex = 24
	end

	local canSellOne = (not focused.locked) and (not focused.soulbound)
	local sOne = Theme.CreateButton(ins, "SellOneAct", if focused.soulbound then "TROPHY" elseif focused.locked then "LOCKED" else "Sell", UDim2.fromOffset(66, 30), UDim2.new(1, -72, 0.5, -15), if canSellOne then Theme.Colors.Gold else Color3.fromRGB(74, 82, 104), function()
		if canSellOne then Net.FireServer(Net.ClientToServer.SellSingleFish, focused.uid) end
	end)
	sOne.TextSize = 12; sOne.ZIndex = 24
end

function BagPanel.Render()
	local w = win
	local gh = gridHandle
	if not w or not gh then return end

	rebuildFishToolbarAndInspector()
	local specs: { ViewportCard.CardVisualSpec } = {}

	if currentTab == "Fish" then
		for idx = #fishBagCache, 1, -1 do
			local caught = fishBagCache[idx]
			local def = IslandsRegistry.GetFish(caught.fishId)
			local fName = if def then def.name else caught.fishId
			local rarity = if def then def.rarity else "Common"
			local rCol = Theme.RarityColors[rarity] or Theme.Colors.TextMuted
			local pCol = if def then def.primaryColor else rCol
			local sCol = if def then def.secondaryColor else Color3.fromRGB(240, 246, 255)
			local isSel = selectedUids[caught.uid] == true
			local isInspected = (inspectedFishUid == caught.uid)

			local badge = if caught.soulbound then "🏆 TROPHY"
				elseif caught.mutation ~= "None" then ("✨ " .. caught.mutation)
				elseif caught.sizeTier ~= "Normal" then caught.sizeTier
				else rarity

			local cIcon = if multiSelectMode
				then (if caught.soulbound or caught.locked then "🔒" elseif isSel then "☑️" else "⬜")
				else (if caught.locked then "🔒" else "🔓")

			table.insert(specs, {
				key = caught.uid,
				order = #fishBagCache - idx + 1,
				title = fName,
				subtitle = string.format("%s • %s", Util.FormatWeight(caught.weight), caught.sizeTier),
				footerText = if caught.soulbound then "SOULBOUND" else (Util.FormatNumber(caught.sellValue) .. " Gold"),
				footerColor = if caught.soulbound then Theme.Colors.Gems elseif caught.locked then Color3.fromRGB(84, 92, 118) else Theme.Colors.Gold,
				strokeColor = if isInspected or isSel then Theme.Colors.Gold else rCol,
				bgColor = if isSel or isInspected then Theme.Colors.CardOwned else Theme.Colors.CardBg,
				topLeftBadge = badge,
				topLeftColor = rCol,
				cornerIcon = cIcon,
				cornerColor = if caught.locked then Theme.Colors.Warning else Color3.fromRGB(36, 46, 72),
				modelSignature = string.format("Fish_%s_%s", caught.fishId, caught.mutation),
				modelSpec = { kind = "Fish", primaryColor = pCol, secondaryColor = sCol, mutation = caught.mutation, modelRefData = def },
				onActivate = function()
					if multiSelectMode then
						if not caught.locked and not caught.soulbound then
							selectedUids[caught.uid] = not (selectedUids[caught.uid] == true)
							BagPanel.Render()
						end
					else
						inspectedFishUid = caught.uid
						BagPanel.Render()
					end
				end,
				onCornerActivate = function()
					if multiSelectMode then
						if not caught.locked and not caught.soulbound then
							selectedUids[caught.uid] = not (selectedUids[caught.uid] == true)
							BagPanel.Render()
						end
					else
						Net.FireServer(Net.ClientToServer.ToggleLockFish, caught.uid)
					end
				end,
			})
		end
	elseif currentTab == "Potions" then
		for idx, pDef in ipairs(PotionsConfig.List) do
			local cnt = potionsCache[pDef.id] or 0
			if cnt > 0 then
				table.insert(specs, {
					key = "pot_" .. pDef.id,
					order = idx,
					title = pDef.name,
					subtitle = pDef.description,
					footerText = string.format("DRINK (x%d)", cnt),
					footerColor = Theme.Colors.Success,
					strokeColor = pDef.color,
					bgColor = Theme.Colors.CardBg,
					topLeftBadge = "x" .. tostring(cnt),
					topLeftColor = pDef.color,
					modelSignature = "Potion_" .. pDef.id,
					modelSpec = { kind = "Potion", primaryColor = pDef.color, secondaryColor = Color3.fromRGB(235, 245, 255) },
					onActivate = function() Net.FireServer(Net.ClientToServer.UsePotion, pDef.id) end,
				})
			end
		end
	else
		for idx, bDef in ipairs(BaitConfig.List) do
			local cnt = baitCache[bDef.id] or 0
			if cnt > 0 then
				local active = (activeBaitCache == bDef.id)
				table.insert(specs, {
					key = "bait_" .. bDef.id,
					order = idx,
					title = bDef.name,
					subtitle = string.format("+%d%% Luck", math.floor(bDef.luckBonus * 100)),
					footerText = if active then "EQUIPPED" else string.format("EQUIP (x%d)", cnt),
					footerColor = if active then Theme.Colors.Warning else Theme.Colors.Primary,
					strokeColor = bDef.color,
					bgColor = if active then Theme.Colors.CardOwned else Theme.Colors.CardBg,
					topLeftBadge = "x" .. tostring(cnt),
					topLeftColor = bDef.color,
					modelSignature = "Bait_" .. bDef.id,
					modelSpec = { kind = "Bait", primaryColor = bDef.color, secondaryColor = Theme.Colors.Gold },
					onActivate = function() Net.FireServer(Net.ClientToServer.SelectBait, if active then "" else bDef.id) end,
				})
			end
		end
	end

	if emptyLbl then
		emptyLbl.Visible = (#specs == 0)
		emptyLbl.Text = if currentTab == "Fish" then "Your Fish Bag is empty! Hold click on the ocean with your Rod equipped!"
			elseif currentTab == "Potions" then "No Potions yet! Catch Rare/Boss fish or claim Playtime Gifts!"
			else "No Bait owned! Visit Master Kaito's Shop to buy Bait packs!"
	end
	gh.SyncItems(specs, if currentTab == "Fish" then inspectedFishUid else nil)
end

function BagPanel.EnableMultiSelectMode()
	currentTab = "Fish"
	multiSelectMode = true
	table.clear(selectedUids)
end

function BagPanel.Mount(rootGui: ScreenGui): WindowFrame.BuiltWindow
	local built = WindowFrame.Create(rootGui, "BagWindow", "🎒 ANGLER 3D BAG", UDim2.fromOffset(610, 460), Theme.Colors.Primary)
	win = built

	local tb = Instance.new("Frame")
	tb.Size = UDim2.new(1, 0, 0, 38)
	tb.BackgroundTransparency = 1
	tb.LayoutOrder = 1
	tb.ZIndex = 22
	tb.Parent = built.body
	toolbarFrame = tb

	local ins = Instance.new("Frame")
	ins.Size = UDim2.new(1, 0, 0, 38)
	ins.BackgroundColor3 = Theme.Colors.CardOwned
	ins.LayoutOrder = 2
	ins.Visible = false
	ins.ZIndex = 22
	ins.Parent = built.body
	Theme.AddCorner(ins, 8)
	Theme.AddStroke(ins, Theme.Colors.Gold, 1.5)
	inspectorFrame = ins

	local emp = Instance.new("TextLabel")
	emp.Size = UDim2.new(1, 0, 0, 56)
	emp.BackgroundTransparency = 1
	emp.Font = Theme.FontBody
	emp.TextSize = 15
	emp.TextColor3 = Theme.Colors.TextMuted
	emp.LayoutOrder = 3
	emp.ZIndex = 22
	emp.Parent = built.body
	emptyLbl = emp

	gridHandle = ViewportPool.CreateGrid(built.body, 4)
	built.OnVisibilityChanged(function(vis: boolean)
		if not vis then ViewportPool.ClearFocus() end
	end)

	local fishTab = built.AddTab("Fish", function() currentTab = "Fish"; BagPanel.Render() end)
	built.AddTab("Potions", function() currentTab = "Potions"; BagPanel.Render() end)
	built.AddTab("Bait", function() currentTab = "Bait"; BagPanel.Render() end)
	built.SetActiveTab(fishTab)
	return built
end

function BagPanel.UpdateFishBag(fishList: { Types.CaughtFish })
	fishBagCache = fishList
	if inspectedFishUid and not findFishEntry(inspectedFishUid) then
		inspectedFishUid = if #fishList > 0 then fishList[#fishList].uid else nil
	elseif not inspectedFishUid and #fishList > 0 then
		inspectedFishUid = fishList[#fishList].uid
	end
	if win and win.IsVisible() and currentTab == "Fish" then BagPanel.Render() end
end

function BagPanel.UpdateItems(potions: { [string]: number }, bait: { [string]: number }, activeBait: string?)
	potionsCache = potions
	baitCache = bait
	activeBaitCache = activeBait
	if win and win.IsVisible() and currentTab ~= "Fish" then BagPanel.Render() end
end

return BagPanel
