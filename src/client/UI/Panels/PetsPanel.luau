--!strict
-- PetsPanel.luau: Kho Pet & Ap Trung O Luoi 3D (ViewportPool) + Bang Chi Tiet Ten/Bac/% Pet & PolicyService

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local PetsConfig = require(Shared:WaitForChild("Config"):WaitForChild("PetsConfig"))

local Theme = require(script.Parent.Parent.Theme)
local WindowFrame = require(script.Parent.Parent.Components.WindowFrame)
local ViewportCard = require(script.Parent.Parent.Components.ViewportCard)
local ViewportPool = require(script.Parent.Parent.Components.ViewportPool)

local PetsPanel = {}

local win: WindowFrame.BuiltWindow? = nil
local tabRefs: { [string]: TextButton } = {}
local topBarFrame: Frame? = nil
local eggOddsBanner: Frame? = nil
local emptyLbl: TextLabel? = nil
local gridHandle: ViewportPool.GridHandle? = nil
local currentTab = "MyPets"
local focusedKey: string? = nil
local selectedEggId = if PetsConfig.Eggs[1] then PetsConfig.Eggs[1].id else ""
local policyStateCache = "Loading"

local petsList: { Types.PetInstance } = {}
local equippedUids: { string } = {}
local maxSlotsCache = GameConfig.BASE_PET_EQUIP_SLOTS

local function isUidEquipped(uid: string): boolean
	for _, eq in ipairs(equippedUids) do
		if eq == uid then return true end
	end
	return false
end

local function rebuildTopToolbar()
	local tb = topBarFrame
	local ob = eggOddsBanner
	if not tb or not ob then return end
	for _, ch in ipairs(tb:GetChildren()) do
		if ch:IsA("GuiObject") then ch:Destroy() end
	end
	for _, ch in ipairs(ob:GetChildren()) do
		if ch:IsA("GuiObject") then ch:Destroy() end
	end

	if currentTab ~= "MyPets" then
		tb.Visible = false
		ob.Visible = true
		local egg = PetsConfig.EggsById[selectedEggId] or PetsConfig.Eggs[1]
		if not egg then return end

		local lines: { string } = {}
		local weightSum = 0
		for _, p in ipairs(egg.pets) do weightSum += p.weightChance end
		for _, p in ipairs(egg.pets) do
			local pct = (p.weightChance / math.max(0.01, weightSum)) * 100
			table.insert(lines, string.format("• [%s] %s: Base %.1f%% → Effective %.1f%% (+%d%%G/+%d%%Str/+%d%%Lk)", p.rarity, p.name, pct, pct, math.floor(p.sellBonus * 100), math.floor(p.strengthBonus * 100), math.floor(p.luckBonus * 100)))
		end

		local title = Instance.new("TextLabel")
		title.Size = UDim2.new(1, -162, 0, 22)
		title.Position = UDim2.fromOffset(10, 6)
		title.BackgroundTransparency = 1
		title.Font = Theme.FontTitle
		title.TextSize = 15
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.TextColor3 = egg.eggColor
		title.Text = string.format("🥚 %s (%s %s • Isl.%d)", egg.name, Util.FormatNumber(egg.cost), egg.currency, egg.islandId)
		title.ZIndex = 23
		title.Parent = ob
		Theme.AddTextStroke(title, 1.4)

		local desc = Instance.new("TextLabel")
		desc.Size = UDim2.new(1, -162, 0, 56)
		desc.Position = UDim2.fromOffset(10, 28)
		desc.BackgroundTransparency = 1
		desc.Font = Theme.FontBody
		desc.TextSize = 11
		desc.TextWrapped = true
		desc.TextXAlignment = Enum.TextXAlignment.Left
		desc.TextColor3 = Theme.Colors.TextPrimary
		desc.Text = table.concat(lines, "\n")
		desc.ZIndex = 23
		desc.Parent = ob

		local isGemEgg = (egg.currency == "Gems")
		local canHatch = (not isGemEgg) or (policyStateCache == "Allowed")
		local btnLabel = if not isGemEgg then ("HATCH (" .. Util.FormatNumber(egg.cost) .. "G)")
			elseif policyStateCache == "Loading" then "⏳ POLICY..."
			elseif policyStateCache == "Restricted" then "🚫 RESTRICTED"
			else ("HATCH (" .. Util.FormatNumber(egg.cost) .. "💎)")
		local btnCol = if not canHatch then Color3.fromRGB(78, 84, 104) elseif isGemEgg then Theme.Colors.Gems else Theme.Colors.Success

		local hBtn = Theme.CreateButton(ob, "HatchSelectedBtn", btnLabel, UDim2.fromOffset(140, 42), UDim2.new(1, -150, 0.5, -21), btnCol, function()
			if canHatch then Net.FireServer(Net.ClientToServer.HatchEgg, egg.id) end
		end)
		hBtn.TextSize = 13; hBtn.ZIndex = 24
		return
	end

	tb.Visible = true
	ob.Visible = false

	local info = Instance.new("TextLabel")
	info.Size = UDim2.new(0.48, 0, 1, 0)
	info.BackgroundTransparency = 1
	info.Font = Theme.FontTitle
	info.TextSize = 15
	info.TextXAlignment = Enum.TextXAlignment.Left
	info.TextColor3 = Theme.Colors.TextPrimary
	info.Text = string.format("🐾 Equipped: %d/%d  •  Owned: %d/%d", #equippedUids, maxSlotsCache, #petsList, GameConfig.MAX_PET_INVENTORY)
	info.ZIndex = 23
	info.Parent = tb
	Theme.AddTextStroke(info, 1.4)

	local bestBtn = Theme.CreateButton(tb, "EquipBestBtn", "⚡ EQUIP BEST", UDim2.fromOffset(132, 34), UDim2.new(1, -252, 0.5, -17), Theme.Colors.Success, function()
		Net.FireServer(Net.ClientToServer.EquipBestPets)
	end)
	bestBtn.TextSize = 13; bestBtn.ZIndex = 24

	local uneqBtn = Theme.CreateButton(tb, "UnequipAllBtn", "Unequip All", UDim2.fromOffset(110, 34), UDim2.new(1, -112, 0.5, -17), Theme.Colors.CardBg, function()
		Net.FireServer(Net.ClientToServer.UnequipPet, "ALL")
	end)
	uneqBtn.TextSize = 13; uneqBtn.ZIndex = 24
end

function PetsPanel.Render()
	local w = win
	local gh = gridHandle
	if not w or not gh then return end

	rebuildTopToolbar()
	local specs: { ViewportCard.CardVisualSpec } = {}

	if currentTab == "MyPets" then
		local sorted = table.clone(petsList)
		table.sort(sorted, function(a: Types.PetInstance, b: Types.PetInstance): boolean
			local eqA, eqB = isUidEquipped(a.uid), isUidEquipped(b.uid)
			if eqA ~= eqB then return eqA end
			local dA, dB = PetsConfig.PetsById[a.petId], PetsConfig.PetsById[b.petId]
			return (if dA then PetsConfig.GetPowerScore(dA) else 0) > (if dB then PetsConfig.GetPowerScore(dB) else 0)
		end)

		for idx, inst in ipairs(sorted) do
			local def = PetsConfig.PetsById[inst.petId]
			if def then
				local equipped = isUidEquipped(inst.uid)
				local rCol = Theme.RarityColors[def.rarity] or Theme.Colors.TextPrimary
				table.insert(specs, {
					key = inst.uid, order = idx, title = def.name,
					subtitle = string.format("+%d%%G • +%d%%Str • +%d%%Lk", math.floor(def.sellBonus * 100), math.floor(def.strengthBonus * 100), math.floor(def.luckBonus * 100)),
					footerText = if equipped then "UNEQUIP ★" else "EQUIP",
					footerColor = if equipped then Theme.Colors.Warning else Theme.Colors.Primary,
					strokeColor = rCol, bgColor = if equipped then Theme.Colors.CardOwned else Theme.Colors.CardBg,
					topLeftBadge = if equipped then "★ EQUIPPED" else def.rarity, topLeftColor = rCol,
					cornerIcon = "🗑️", cornerColor = Theme.Colors.Danger,
					modelSignature = "Pet_" .. def.id,
					modelSpec = { kind = "Pet", primaryColor = def.primaryColor, secondaryColor = def.secondaryColor, modelRefData = def },
					onActivate = function()
						focusedKey = inst.uid
						if equipped then Net.FireServer(Net.ClientToServer.UnequipPet, inst.uid)
						else Net.FireServer(Net.ClientToServer.EquipPet, inst.uid) end
					end,
					onCornerActivate = function() Net.FireServer(Net.ClientToServer.DeletePet, inst.uid) end,
				})
			end
		end
	else
		for idx, egg in ipairs(PetsConfig.Eggs) do
			local isSel = (selectedEggId == egg.id)
			local isGem = (egg.currency == "Gems")
			local allowed = (not isGem) or (policyStateCache == "Allowed")
			local shortPets: { string } = {}
			for _, p in ipairs(egg.pets) do
				table.insert(shortPets, string.format("%s %d%%", string.match(p.name, "%S+$") or p.name, p.weightChance))
			end
			local curIcon = if isGem then "💎 " else "🪙 "
			local fTxt = if not allowed then (if policyStateCache == "Loading" then "⏳ POLICY" else "🚫 RESTRICTED")
				elseif isSel then ("HATCH " .. curIcon .. Util.FormatNumber(egg.cost))
				else ("VIEW • " .. curIcon .. Util.FormatNumber(egg.cost))
			local fCol = if not allowed then Color3.fromRGB(78, 84, 104) elseif isSel then Theme.Colors.Success elseif isGem then Theme.Colors.Gems else Theme.Colors.Gold

			table.insert(specs, {
				key = "egg_" .. egg.id, order = idx, title = egg.name,
				subtitle = table.concat(shortPets, " • "),
				footerText = fTxt, footerColor = fCol,
				strokeColor = if isSel then Theme.Colors.Gold else egg.eggColor,
				bgColor = if isSel then Theme.Colors.CardOwned else Theme.Colors.CardBg,
				topLeftBadge = "Isl." .. tostring(egg.islandId), topLeftColor = egg.accentColor,
				modelSignature = "Egg_" .. egg.id,
				modelSpec = { kind = "Egg", primaryColor = egg.eggColor, secondaryColor = egg.accentColor },
				onActivate = function()
					focusedKey = "egg_" .. egg.id
					if selectedEggId ~= egg.id then
						selectedEggId = egg.id
						PetsPanel.Render()
					elseif allowed then
						Net.FireServer(Net.ClientToServer.HatchEgg, egg.id)
					end
				end,
			})
		end
	end

	if emptyLbl then
		emptyLbl.Visible = (currentTab == "MyPets" and #specs == 0)
		emptyLbl.Text = "No Pets hatched yet! Open the 'Hatch Eggs' tab to inspect drop rates & hatch 3D Companions!"
	end
	gh.SyncItems(specs, focusedKey)
end

function PetsPanel.OpenEggPreview(eggId: string)
	if PetsConfig.EggsById[eggId] then
		selectedEggId = eggId
		focusedKey = "egg_" .. eggId
	end
	currentTab = "Eggs"
	if win and tabRefs["Eggs"] then win.SetActiveTab(tabRefs["Eggs"]) end
	PetsPanel.Render()
end

function PetsPanel.Mount(rootGui: ScreenGui): WindowFrame.BuiltWindow
	local built = WindowFrame.Create(rootGui, "PetsWindow", "🐾 3D PET COMPANIONS & EGG ODDS", UDim2.fromOffset(620, 465), Color3.fromRGB(192, 98, 255))
	win = built

	local tb = Instance.new("Frame")
	tb.Size = UDim2.new(1, 0, 0, 38)
	tb.BackgroundTransparency = 1
	tb.LayoutOrder = 1
	tb.ZIndex = 22
	tb.Parent = built.body
	topBarFrame = tb

	local ob = Instance.new("Frame")
	ob.Size = UDim2.new(1, 0, 0, 88)
	ob.BackgroundColor3 = Theme.Colors.CardOwned
	ob.Visible = false
	ob.LayoutOrder = 1
	ob.ZIndex = 22
	ob.Parent = built.body
	Theme.AddCorner(ob, 10)
	Theme.AddStroke(ob, Theme.Colors.Gold, 2)
	eggOddsBanner = ob

	local emp = Instance.new("TextLabel")
	emp.Size = UDim2.new(1, 0, 0, 50)
	emp.BackgroundTransparency = 1
	emp.Font = Theme.FontBody
	emp.TextSize = 14
	emp.TextColor3 = Theme.Colors.TextMuted
	emp.LayoutOrder = 2
	emp.ZIndex = 22
	emp.Parent = built.body
	emptyLbl = emp

	gridHandle = ViewportPool.CreateGrid(built.body, 3, UDim2.fromOffset(136, 154))
	built.OnVisibilityChanged(function(vis: boolean)
		if not vis then ViewportPool.ClearFocus() else PetsPanel.Render() end
	end)

	tabRefs["MyPets"] = built.AddTab("My Pets", function() currentTab = "MyPets"; PetsPanel.Render() end)
	tabRefs["Eggs"] = built.AddTab("Hatch Eggs", function() currentTab = "Eggs"; PetsPanel.Render() end)
	built.SetActiveTab(tabRefs["MyPets"])
	return built
end

function PetsPanel.SyncPolicyState(policyState: string)
	policyStateCache = policyState
	if win and win.IsVisible() and currentTab == "Eggs" then PetsPanel.Render() end
end

function PetsPanel.SyncFromProfile(p: any)
	if type(p) ~= "table" then return end
	petsList = if type(p.pets) == "table" then p.pets else {}
	equippedUids = if type(p.equippedPetUids) == "table" then p.equippedPetUids else {}
	if win and win.IsVisible() then PetsPanel.Render() end
end

function PetsPanel.SyncPayload(payload: any)
	if type(payload) ~= "table" then return end
	petsList = if type(payload.pets) == "table" then payload.pets else petsList
	equippedUids = if type(payload.equippedPetUids) == "table" then payload.equippedPetUids else equippedUids
	maxSlotsCache = tonumber(payload.maxSlots) or maxSlotsCache
	if win and win.IsVisible() then PetsPanel.Render() end
end

return PetsPanel
