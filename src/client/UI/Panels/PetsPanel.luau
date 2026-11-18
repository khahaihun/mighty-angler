--!strict
-- PetsPanel.luau: Kho Pet & Ap Trung O Luoi 3D (ViewportPool) kem ty le % minh bach

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
local topBarFrame: Frame? = nil
local emptyLbl: TextLabel? = nil
local gridHandle: ViewportPool.GridHandle? = nil
local currentTab = "MyPets"
local focusedKey: string? = nil

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
	if not tb then return end
	for _, ch in ipairs(tb:GetChildren()) do
		if ch:IsA("GuiObject") then ch:Destroy() end
	end

	if currentTab ~= "MyPets" then
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.fromScale(1, 1)
		lbl.BackgroundTransparency = 1
		lbl.Font = Theme.FontBody
		lbl.TextSize = 13
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.TextColor3 = Theme.Colors.TextMuted
		lbl.Text = "🥚 Hatch 3D Companion Eggs (Exact % drop chances shown per egg!)"
		lbl.ZIndex = 23
		lbl.Parent = tb
		return
	end

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
					key = inst.uid,
					order = idx,
					title = def.name,
					subtitle = string.format("+%d%%G • +%d%%Str • +%d%%Lk", math.floor(def.sellBonus * 100), math.floor(def.strengthBonus * 100), math.floor(def.luckBonus * 100)),
					footerText = if equipped then "UNEQUIP ★" else "EQUIP",
					footerColor = if equipped then Theme.Colors.Warning else Theme.Colors.Primary,
					strokeColor = rCol,
					bgColor = if equipped then Theme.Colors.CardOwned else Theme.Colors.CardBg,
					topLeftBadge = if equipped then "★ EQUIPPED" else def.rarity,
					topLeftColor = rCol,
					cornerIcon = "🗑️",
					cornerColor = Theme.Colors.Danger,
					modelSignature = "Pet_" .. def.id,
					modelSpec = { kind = "Pet", primaryColor = def.primaryColor, secondaryColor = def.secondaryColor, modelRefData = def },
					onActivate = function()
						focusedKey = inst.uid
						if equipped then Net.FireServer(Net.ClientToServer.UnequipPet, inst.uid)
						else Net.FireServer(Net.ClientToServer.EquipPet, inst.uid) end
					end,
					onCornerActivate = function()
						Net.FireServer(Net.ClientToServer.DeletePet, inst.uid)
					end,
				})
			end
		end
	else
		for idx, egg in ipairs(PetsConfig.Eggs) do
			local oddsParts: { string } = {}
			for _, p in ipairs(egg.pets) do
				table.insert(oddsParts, string.format("%d%%", p.weightChance))
			end
			local curIcon = if egg.currency == "Gold" then "🪙 " else "💎 "
			local curCol = if egg.currency == "Gold" then Theme.Colors.Gold else Theme.Colors.Gems
			table.insert(specs, {
				key = "egg_" .. egg.id,
				order = idx,
				title = egg.name,
				subtitle = "Odds: " .. table.concat(oddsParts, " / "),
				footerText = curIcon .. Util.FormatNumber(egg.cost),
				footerColor = curCol,
				strokeColor = egg.eggColor,
				bgColor = Theme.Colors.CardBg,
				topLeftBadge = "Isl." .. tostring(egg.islandId),
				topLeftColor = egg.accentColor,
				modelSignature = "Egg_" .. egg.id,
				modelSpec = { kind = "Egg", primaryColor = egg.eggColor, secondaryColor = egg.accentColor },
				onActivate = function()
					focusedKey = "egg_" .. egg.id
					Net.FireServer(Net.ClientToServer.HatchEgg, egg.id)
				end,
			})
		end
	end

	if emptyLbl then
		emptyLbl.Visible = (#specs == 0)
		emptyLbl.Text = "No Pets hatched yet! Open the 'Hatch Eggs' tab to hatch your first 3D Companion!"
	end
	gh.SyncItems(specs, focusedKey)
end

function PetsPanel.Mount(rootGui: ScreenGui): WindowFrame.BuiltWindow
	local built = WindowFrame.Create(rootGui, "PetsWindow", "🐾 3D PET COMPANIONS", UDim2.fromOffset(610, 455), Color3.fromRGB(192, 98, 255))
	win = built

	local tb = Instance.new("Frame")
	tb.Size = UDim2.new(1, 0, 0, 38)
	tb.BackgroundTransparency = 1
	tb.LayoutOrder = 1
	tb.ZIndex = 22
	tb.Parent = built.body
	topBarFrame = tb

	local emp = Instance.new("TextLabel")
	emp.Size = UDim2.new(1, 0, 0, 54)
	emp.BackgroundTransparency = 1
	emp.Font = Theme.FontBody
	emp.TextSize = 15
	emp.TextColor3 = Theme.Colors.TextMuted
	emp.LayoutOrder = 2
	emp.ZIndex = 22
	emp.Parent = built.body
	emptyLbl = emp

	gridHandle = ViewportPool.CreateGrid(built.body, 3, UDim2.fromOffset(136, 154))
	built.OnVisibilityChanged(function(vis: boolean)
		if not vis then ViewportPool.ClearFocus() end
	end)

	local myTab = built.AddTab("My Pets", function() currentTab = "MyPets"; PetsPanel.Render() end)
	built.AddTab("Hatch Eggs", function() currentTab = "Eggs"; PetsPanel.Render() end)
	built.SetActiveTab(myTab)
	return built
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
