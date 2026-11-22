--!strict
-- HotbarAndBaitUi.luau: Custom Hotbar (1..5), Nut Auto-Train/Auto-Fish phia tren Hotbar, Chon Moi Nhanh goc duoi phai & Thanh Cast Power

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local RodsConfig = require(Shared:WaitForChild("Config"):WaitForChild("RodsConfig"))
local BaitConfig = require(Shared:WaitForChild("Config"):WaitForChild("BaitConfig"))
local IslandsRegistry = require(Shared:WaitForChild("Config"):WaitForChild("Islands"))

local Theme = require(script.Parent.Parent.Theme)

export type HotbarCallbacks = {
	OnToggleAutoFish: () -> (),
	OnToggleAutoTrain: () -> (),
	OnCancelCast: () -> (),
}

local HotbarAndBaitUi = {}

local slotBtns: { [number]: TextButton } = {}
local autoFishBtn: TextButton? = nil
local autoTrainBtn: TextButton? = nil
local cancelCastBtn: TextButton? = nil
local baitMainBtn: TextButton? = nil
local baitPopup: Frame? = nil
local chargeWrap: Frame? = nil
local chargeFill: Frame? = nil
local chargeLbl: TextLabel? = nil

local equippedSlot = 1
local curRodId = "Twig"
local pinnedUids: { [string]: string } = {}
local bagByUid: { [string]: any } = {}
local baitCounts: { [string]: number } = {}
local curActiveBait: string? = nil

local autoFishOn = false
local autoTrainOn = false
local hasAutoPro = false
local canAutoTrain = false

local fishNames: { [string]: string } = {}
for _, isl in ipairs(IslandsRegistry.List) do
	for _, f in ipairs(isl.fishPool) do
		fishNames[f.id] = f.name
	end
end

local function disableDefaultBackpack()
	task.spawn(function()
		for _ = 1, 8 do
			if pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false) end) then break end
			task.wait(0.4)
		end
	end)
end

local function refreshSlotsVisual()
	local rod = RodsConfig.Get(curRodId)
	local b1 = slotBtns[1]
	if b1 then
		local active = (equippedSlot == 1)
		b1.Text = string.format("[1]\n🎣 %s", string.sub(rod.name, 1, 12))
		b1.BackgroundColor3 = if active then Color3.fromRGB(36, 86, 138) else Theme.Colors.PanelBg
		local st = b1:FindFirstChildOfClass("UIStroke")
		if st then st.Color = if active then Theme.Colors.Gold else Theme.Colors.Primary; st.Thickness = if active then 3 else 2 end
	end
	for slot = 2, 5 do
		local btn = slotBtns[slot]
		if btn then
			local uid = pinnedUids[tostring(slot)]
			local entry = if uid then bagByUid[uid] else nil
			local active = (equippedSlot == slot and entry ~= nil)
			if entry then
				local fName = string.sub(fishNames[tostring(entry.fishId)] or "Fish", 1, 10)
				btn.Text = string.format("[%d]\n🐟 %s\n%s", slot, fName, Util.FormatWeight(tonumber(entry.weight) or 1))
				btn.BackgroundColor3 = if active then Color3.fromRGB(48, 96, 78) else Theme.Colors.CardBg
			else
				btn.Text = string.format("[%d]\n(Pin Fish)", slot)
				btn.BackgroundColor3 = Color3.fromRGB(22, 28, 44)
			end
			local st = btn:FindFirstChildOfClass("UIStroke")
			if st then st.Color = if active then Theme.Colors.Gold else Theme.Colors.StrokeLight; st.Thickness = if active then 3 else 1.8 end
		end
	end
end

local function refreshAutoPills()
	if autoFishBtn then
		autoFishBtn.Text = if autoFishOn then (if hasAutoPro then "🎣 AUTO-FISH PRO: ON" else "🎣 AUTO-FISH: ON") else (if hasAutoPro then "🎣 AUTO-FISH PRO: OFF" else "🎣 AUTO-FISH (FREE): OFF")
		autoFishBtn.BackgroundColor3 = if autoFishOn then Theme.Colors.Success else Theme.Colors.CardBg
	end
	if autoTrainBtn then
		autoTrainBtn.Text = if autoTrainOn then "🏋️ AUTO-TRAIN: ON" elseif canAutoTrain then "🏋️ AUTO-TRAIN: OFF" else "🔒 AUTO-TRAIN (GROUP)"
		autoTrainBtn.BackgroundColor3 = if autoTrainOn then Theme.Colors.Success elseif canAutoTrain then Theme.Colors.CardBg else Color3.fromRGB(64, 82, 112)
	end
end

local function rebuildBaitPopup()
	local pop = baitPopup
	if not pop then return end
	for _, ch in ipairs(pop:GetChildren()) do
		if ch:IsA("GuiObject") then ch:Destroy() end
	end
	local rows = 1
	local noneBtn = Theme.CreateButton(pop, "BaitNone", "🚫 No Bait (Save Bait)", UDim2.new(1, -12, 0, 32), UDim2.new(), Theme.Colors.CardBg, function()
		pop.Visible = false; Net.FireServer(Net.ClientToServer.SelectBait, "")
	end)
	noneBtn.TextSize = 13; noneBtn.LayoutOrder = 0

	for idx, bDef in ipairs(BaitConfig.List) do
		local cnt = tonumber(baitCounts[bDef.id]) or 0
		if cnt > 0 then
			rows += 1
			local btn = Theme.CreateButton(pop, "Bait_" .. bDef.id, string.format("🪱 %s (x%d) +%d%% Luck", bDef.name, cnt, math.floor(bDef.luckBonus * 100)), UDim2.new(1, -12, 0, 32), UDim2.new(), if curActiveBait == bDef.id then Theme.Colors.Success else Theme.Colors.Primary, function()
				pop.Visible = false; Net.FireServer(Net.ClientToServer.SelectBait, bDef.id)
			end)
			Theme.FitText(btn, 13, 12); btn.LayoutOrder = idx
		end
	end
	pop.Size = UDim2.fromOffset(224, rows * 38 + 12)
end

local function refreshBaitButton()
	if not baitMainBtn then
		return
	end
	if curActiveBait and curActiveBait ~= "" then
		local bDef = BaitConfig.ById[curActiveBait]
		local cnt = tonumber(baitCounts[curActiveBait]) or 0
		if bDef and cnt > 0 then
			baitMainBtn.Text = string.format("🪱 %s (x%d) ▴", bDef.name, cnt)
			baitMainBtn.BackgroundColor3 = Theme.Colors.Primary
			return
		end
	end
	baitMainBtn.Text = "🪱 Bait: None ▴"
	baitMainBtn.BackgroundColor3 = Theme.Colors.CardBg
end

function HotbarAndBaitUi.Mount(rootGui: ScreenGui, callbacks: HotbarCallbacks)
	disableDefaultBackpack()

	local function makeRowFrame(name: string, pos: UDim2, sz: UDim2): Frame
		local f = Instance.new("Frame")
		f.Name = name
		f.AnchorPoint = Vector2.new(0.5, 1)
		f.Position = pos
		f.Size = sz
		f.BackgroundTransparency = 1
		f.Parent = rootGui
		local lay = Instance.new("UIListLayout")
		lay.FillDirection = Enum.FillDirection.Horizontal
		lay.HorizontalAlignment = Enum.HorizontalAlignment.Center
		lay.Padding = UDim.new(0, 8)
		lay.Parent = f
		return f
	end

	-- 1. Thanh nap luc Cast Power
	local cWrap = Instance.new("Frame")
	cWrap.Name = "CastPowerBar"
	cWrap.AnchorPoint = Vector2.new(0.5, 1)
	cWrap.Position = UDim2.new(0.5, 0, 1, -138)
	cWrap.Size = UDim2.fromOffset(310, 26)
	cWrap.BackgroundColor3 = Color3.fromRGB(16, 22, 36)
	cWrap.Visible = false
	cWrap.ZIndex = 30
	cWrap.Parent = rootGui
	Theme.AddCorner(cWrap, 10)
	Theme.AddStroke(cWrap, Theme.Colors.Gold, 2.2)
	chargeWrap = cWrap

	local perfBand = Instance.new("Frame")
	perfBand.Position = UDim2.fromScale(GameConfig.PERFECT_HOLD_MIN, 0)
	perfBand.Size = UDim2.fromScale(GameConfig.PERFECT_HOLD_MAX - GameConfig.PERFECT_HOLD_MIN, 1)
	perfBand.BackgroundColor3 = Color3.fromRGB(72, 238, 128)
	perfBand.BackgroundTransparency = 0.35
	perfBand.BorderSizePixel = 0
	perfBand.ZIndex = 31
	perfBand.Parent = cWrap

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Theme.Colors.Gold
	fill.BorderSizePixel = 0
	fill.ZIndex = 32
	fill.Parent = cWrap
	Theme.AddCorner(fill, 10)
	chargeFill = fill

	local cLbl = Instance.new("TextLabel")
	cLbl.Size = UDim2.fromScale(1, 1)
	cLbl.BackgroundTransparency = 1
	cLbl.Font = Theme.FontTitle
	cLbl.TextSize = 13
	cLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
	cLbl.ZIndex = 33
	cLbl.Parent = cWrap
	Theme.AddTextStroke(cLbl, 1.5)
	chargeLbl = cLbl

	-- 2. Cum Auto phia tren Hotbar & 3. Custom Hotbar 5 o
	local autoRow = makeRowFrame("AboveHotbarAutoRow", UDim2.new(0.5, 0, 1, -82), UDim2.fromOffset(520, 36))
	local atBtn = Theme.CreateButton(autoRow, "AutoTrainPill", "🏋️ AUTO-TRAIN: OFF", UDim2.fromOffset(172, 34), UDim2.new(), Theme.Colors.CardBg, callbacks.OnToggleAutoTrain)
	atBtn.TextSize = 13
	autoTrainBtn = atBtn
	local afBtn = Theme.CreateButton(autoRow, "AutoFishPill", "🎣 AUTO-FISH (FREE): OFF", UDim2.fromOffset(196, 34), UDim2.new(), Theme.Colors.CardBg, callbacks.OnToggleAutoFish)
	afBtn.TextSize = 13
	autoFishBtn = afBtn
	local cancelBtn = Theme.CreateButton(autoRow, "CancelCastPill", "✖ REEL IN", UDim2.fromOffset(108, 34), UDim2.new(), Theme.Colors.Danger, callbacks.OnCancelCast)
	cancelBtn.TextSize = 13
	cancelBtn.Visible = false
	cancelCastBtn = cancelBtn

	local hotbar = makeRowFrame("CustomHotbar", UDim2.new(0.5, 0, 1, -10), UDim2.fromOffset(490, 64))
	for slot = 1, 5 do
		local sBtn = Theme.CreateButton(hotbar, "Slot_" .. tostring(slot), "[" .. tostring(slot) .. "]", UDim2.fromOffset(90, 62), UDim2.new(), Theme.Colors.PanelBg, function()
			Net.FireServer(Net.ClientToServer.SelectHotbarSlot, slot)
		end)
		Theme.FitText(sBtn, 13, 12)
		sBtn.TextWrapped = true
		slotBtns[slot] = sBtn
	end

	-- 4. O Chon Moi Nhanh goc duoi ben phai + Popup
	local bBtn = Theme.CreateButton(rootGui, "QuickBaitBtn", "🪱 Bait: None ▴", UDim2.fromOffset(192, 46), UDim2.new(1, -208, 1, -18), Theme.Colors.CardBg, function()
		if baitPopup then
			if not baitPopup.Visible then rebuildBaitPopup() end
			baitPopup.Visible = not baitPopup.Visible
		end
	end)
	bBtn.AnchorPoint = Vector2.new(0, 1)
	bBtn.TextSize = 14
	baitMainBtn = bBtn

	local pop = Instance.new("Frame")
	pop.Name = "QuickBaitPopup"
	pop.AnchorPoint = Vector2.new(0, 1)
	pop.Position = UDim2.new(1, -224, 1, -70)
	pop.Size = UDim2.fromOffset(216, 120)
	pop.BackgroundColor3 = Theme.Colors.PanelBg
	pop.Visible = false
	pop.ZIndex = 35
	pop.Parent = rootGui
	Theme.AddCorner(pop, 12)
	Theme.AddStroke(pop, Theme.Colors.Primary, 2)
	baitPopup = pop

	local pLayout = Instance.new("UIListLayout")
	pLayout.Padding = UDim.new(0, 5)
	pLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	pLayout.SortOrder = Enum.SortOrder.LayoutOrder
	pLayout.Parent = pop
	local pPad = Instance.new("UIPadding")
	pPad.PaddingTop = UDim.new(0, 6)
	pPad.Parent = pop

	refreshSlotsVisual()
	refreshAutoPills()
	refreshBaitButton()
end

function HotbarAndBaitUi.SetCastCharge(visible: boolean, ratio: number)
	if not chargeWrap or not chargeFill or not chargeLbl then
		return
	end
	chargeWrap.Visible = visible
	if visible then
		local r = math.clamp(ratio, 0, 1)
		chargeFill.Size = UDim2.fromScale(r, 1)
		local inPerf = (r >= GameConfig.PERFECT_HOLD_MIN and r <= GameConfig.PERFECT_HOLD_MAX)
		chargeFill.BackgroundColor3 = if inPerf then Theme.Colors.Success else Theme.Colors.Gold
		chargeLbl.Text = if inPerf then "✨ PERFECT ZONE! RELEASE NOW (+25% LUCK)!" else string.format("CAST POWER: %d%%", math.floor(r * 100))
	end
end

function HotbarAndBaitUi.SyncHotbar(slot: number, pinned: any, rodId: string?)
	equippedSlot = slot
	if type(pinned) == "table" then
		pinnedUids = pinned
	end
	if rodId then
		curRodId = rodId
	end
	refreshSlotsVisual()
end

function HotbarAndBaitUi.SyncBag(fishBag: { any })
	table.clear(bagByUid)
	for _, entry in ipairs(fishBag) do
		if type(entry) == "table" and type(entry.uid) == "string" then
			bagByUid[entry.uid] = entry
		end
	end
	refreshSlotsVisual()
end

function HotbarAndBaitUi.SyncBait(baitMap: any, activeBait: any)
	baitCounts = if type(baitMap) == "table" then baitMap else {}
	curActiveBait = if type(activeBait) == "string" then activeBait else nil
	refreshBaitButton()
	if baitPopup and baitPopup.Visible then
		rebuildBaitPopup()
	end
end

function HotbarAndBaitUi.SyncStates(isCasting: boolean, isAutoFish: boolean, isAutoTrain: boolean, canTrain: boolean, autoPro: boolean)
	autoFishOn = isAutoFish
	autoTrainOn = isAutoTrain
	canAutoTrain = canTrain
	hasAutoPro = autoPro
	if cancelCastBtn then
		cancelCastBtn.Visible = isCasting
	end
	refreshAutoPills()
end

function HotbarAndBaitUi.GetEquippedSlot(): number
	return equippedSlot
end

return HotbarAndBaitUi
