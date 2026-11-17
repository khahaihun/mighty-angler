--!strict
-- PetsPanel.luau: Giao dien Kho Pet (Equip Best, Equip/Unequip, Delete) & Ap 10 Trung Pet cua 5 Dao

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local PetsConfig = require(Shared:WaitForChild("Config"):WaitForChild("PetsConfig"))

local Theme = require(script.Parent.Parent.Theme)
local WindowFrame = require(script.Parent.Parent.Components.WindowFrame)

local PetsPanel = {}

local win: WindowFrame.BuiltWindow? = nil
local currentTab = "MyPets"
local petsList: { Types.PetInstance } = {}
local equippedUids: { string } = {}
local maxSlotsCache = GameConfig.BASE_PET_EQUIP_SLOTS

local function clearBody(body: ScrollingFrame)
	for _, ch in ipairs(body:GetChildren()) do
		if ch:IsA("GuiObject") then
			ch:Destroy()
		end
	end
end

local function isUidEquipped(uid: string): boolean
	for _, eq in ipairs(equippedUids) do
		if eq == uid then
			return true
		end
	end
	return false
end

function PetsPanel.Render()
	local w = win
	if not w then
		return
	end
	clearBody(w.body)

	if currentTab == "MyPets" then
		local topRow = Instance.new("Frame")
		topRow.Size = UDim2.new(1, 0, 0, 42)
		topRow.BackgroundTransparency = 1
		topRow.LayoutOrder = 0
		topRow.ZIndex = 22
		topRow.Parent = w.body

		local info = Instance.new("TextLabel")
		info.Size = UDim2.new(0.48, 0, 1, 0)
		info.BackgroundTransparency = 1
		info.Font = Theme.FontTitle
		info.TextSize = 17
		info.TextXAlignment = Enum.TextXAlignment.Left
		info.TextColor3 = Theme.Colors.TextPrimary
		info.Text = string.format("Equipped: %d / %d • Owned: %d/%d", #equippedUids, maxSlotsCache, #petsList, GameConfig.MAX_PET_INVENTORY)
		info.ZIndex = 22
		info.Parent = topRow
		Theme.AddTextStroke(info, 1.5)

		local bestBtn = Theme.CreateButton(topRow, "EquipBestBtn", "⚡ EQUIP BEST", UDim2.fromOffset(138, 36), UDim2.new(1, -262, 0.5, -18), Theme.Colors.Success, function()
			Net.FireServer(Net.ClientToServer.EquipBestPets)
		end)
		bestBtn.TextSize = 14
		bestBtn.ZIndex = 23

		local uneqAll = Theme.CreateButton(topRow, "UnequipAllBtn", "Unequip All", UDim2.fromOffset(114, 36), UDim2.new(1, -116, 0.5, -18), Theme.Colors.CardBg, function()
			Net.FireServer(Net.ClientToServer.UnequipPet, "ALL")
		end)
		uneqAll.TextSize = 14
		uneqAll.ZIndex = 23

		if #petsList == 0 then
			local empty = Instance.new("TextLabel")
			empty.Size = UDim2.new(1, 0, 0, 68)
			empty.BackgroundTransparency = 1
			empty.Font = Theme.FontBody
			empty.TextSize = 16
			empty.TextColor3 = Theme.Colors.TextMuted
			empty.Text = "No Pets hatched yet! Switch to 'Hatch Eggs' tab or visit an Egg Pedestal."
			empty.ZIndex = 22
			empty.Parent = w.body
			return
		end

		local sorted = table.clone(petsList)
		table.sort(sorted, function(a: Types.PetInstance, b: Types.PetInstance): boolean
			local eqA = isUidEquipped(a.uid)
			local eqB = isUidEquipped(b.uid)
			if eqA ~= eqB then
				return eqA
			end
			local dA = PetsConfig.PetsById[a.petId]
			local dB = PetsConfig.PetsById[b.petId]
			local sA = if dA then PetsConfig.GetPowerScore(dA) else 0
			local sB = if dB then PetsConfig.GetPowerScore(dB) else 0
			return sA > sB
		end)

		for idx, inst in ipairs(sorted) do
			local def = PetsConfig.PetsById[inst.petId]
			if def then
				local equipped = isUidEquipped(inst.uid)
				local rCol = Theme.RarityColors[def.rarity] or Theme.Colors.TextPrimary

				local card = Instance.new("Frame")
				card.Size = UDim2.new(1, 0, 0, 62)
				card.BackgroundColor3 = if equipped then Theme.Colors.CardOwned else Theme.Colors.CardBg
				card.LayoutOrder = idx
				card.ZIndex = 22
				card.Parent = w.body
				Theme.AddCorner(card, 10)
				Theme.AddStroke(card, rCol, 2)

				local title = Instance.new("TextLabel")
				title.Size = UDim2.new(0.60, 0, 0, 26)
				title.Position = UDim2.fromOffset(12, 5)
				title.BackgroundTransparency = 1
				title.Font = Theme.FontTitle
				title.TextSize = 17
				title.TextXAlignment = Enum.TextXAlignment.Left
				title.TextColor3 = rCol
				title.Text = string.format("🐾 %s [%s]%s", def.name, def.rarity, if equipped then " ★" else "")
				title.ZIndex = 23
				title.Parent = card
				Theme.AddTextStroke(title, 1.5)

				local sub = Instance.new("TextLabel")
				sub.Size = UDim2.new(0.60, 0, 0, 22)
				sub.Position = UDim2.fromOffset(12, 32)
				sub.BackgroundTransparency = 1
				sub.Font = Theme.FontBody
				sub.TextSize = 13
				sub.TextXAlignment = Enum.TextXAlignment.Left
				sub.TextColor3 = Theme.Colors.TextMuted
				sub.Text = string.format(
					"+%d%% Gold • +%d%% Str • +%d%% Luck",
					math.floor(def.sellBonus * 100 + 0.5),
					math.floor(def.strengthBonus * 100 + 0.5),
					math.floor(def.luckBonus * 100 + 0.5)
				)
				sub.ZIndex = 23
				sub.Parent = card

				local eqBtn = Theme.CreateButton(
					card,
					"EqBtn",
					if equipped then "UNEQUIP" else "EQUIP",
					UDim2.fromOffset(102, 36),
					UDim2.new(1, -166, 0.5, -18),
					if equipped then Theme.Colors.Warning else Theme.Colors.Primary,
					function()
						if equipped then
							Net.FireServer(Net.ClientToServer.UnequipPet, inst.uid)
						else
							Net.FireServer(Net.ClientToServer.EquipPet, inst.uid)
						end
					end
				)
				eqBtn.TextSize = 14
				eqBtn.ZIndex = 23

				local delBtn = Theme.CreateButton(card, "DelBtn", "🗑️", UDim2.fromOffset(44, 36), UDim2.new(1, -54, 0.5, -18), Theme.Colors.Danger, function()
					Net.FireServer(Net.ClientToServer.DeletePet, inst.uid)
				end)
				delBtn.TextSize = 15
				delBtn.ZIndex = 23
			end
		end
	else
		for idx, egg in ipairs(PetsConfig.Eggs) do
			local card = Instance.new("Frame")
			card.Size = UDim2.new(1, 0, 0, 66)
			card.BackgroundColor3 = Theme.Colors.CardBg
			card.LayoutOrder = idx
			card.ZIndex = 22
			card.Parent = w.body
			Theme.AddCorner(card, 10)
			Theme.AddStroke(card, egg.eggColor, 2)

			local t = Instance.new("TextLabel")
			t.Size = UDim2.new(0.66, 0, 0, 26)
			t.Position = UDim2.fromOffset(12, 6)
			t.BackgroundTransparency = 1
			t.Font = Theme.FontTitle
			t.TextSize = 17
			t.TextXAlignment = Enum.TextXAlignment.Left
			t.TextColor3 = egg.eggColor
			t.Text = string.format("🥚 Island %d: %s", egg.islandId, egg.name)
			t.ZIndex = 23
			t.Parent = card
			Theme.AddTextStroke(t, 1.5)

			local names: { string } = {}
			for _, p in ipairs(egg.pets) do
				table.insert(names, string.format("%s (%d%%)", p.name, p.weightChance))
			end

			local s = Instance.new("TextLabel")
			s.Size = UDim2.new(0.66, 0, 0, 22)
			s.Position = UDim2.fromOffset(12, 34)
			s.BackgroundTransparency = 1
			s.Font = Theme.FontBody
			s.TextSize = 12
			s.TextXAlignment = Enum.TextXAlignment.Left
			s.TextColor3 = Theme.Colors.TextMuted
			s.Text = table.concat(names, " • ")
			s.TextTruncate = Enum.TextTruncate.AtEnd
			s.ZIndex = 23
			s.Parent = card

			local curIcon = if egg.currency == "Gold" then "🪙 " else "💎 "
			local curCol = if egg.currency == "Gold" then Theme.Colors.Gold else Theme.Colors.Gems
			local hatchBtn = Theme.CreateButton(
				card,
				"HatchBtn",
				curIcon .. Util.FormatNumber(egg.cost),
				UDim2.fromOffset(138, 38),
				UDim2.new(1, -150, 0.5, -19),
				curCol,
				function()
					Net.FireServer(Net.ClientToServer.HatchEgg, egg.id)
				end
			)
			hatchBtn.TextSize = 15
			hatchBtn.ZIndex = 23
		end
	end
end

function PetsPanel.Mount(rootGui: ScreenGui): WindowFrame.BuiltWindow
	local built = WindowFrame.Create(rootGui, "PetsWindow", "🐾 PET COMPANIONS", UDim2.fromOffset(600, 430), Color3.fromRGB(192, 98, 255))
	win = built

	local myTab = built.AddTab("My Pets", function()
		currentTab = "MyPets"
		PetsPanel.Render()
	end)
	built.AddTab("Hatch Eggs", function()
		currentTab = "Eggs"
		PetsPanel.Render()
	end)
	built.SetActiveTab(myTab)
	PetsPanel.Render()
	return built
end

function PetsPanel.SyncFromProfile(p: any)
	if type(p) ~= "table" then
		return
	end
	petsList = if type(p.pets) == "table" then p.pets else {}
	equippedUids = if type(p.equippedPetUids) == "table" then p.equippedPetUids else {}
	if win and win.IsVisible() then
		PetsPanel.Render()
	end
end

function PetsPanel.SyncPayload(payload: any)
	if type(payload) ~= "table" then
		return
	end
	petsList = if type(payload.pets) == "table" then payload.pets else petsList
	equippedUids = if type(payload.equippedPetUids) == "table" then payload.equippedPetUids else equippedUids
	maxSlotsCache = tonumber(payload.maxSlots) or maxSlotsCache
	if win and win.IsVisible() then
		PetsPanel.Render()
	end
end

return PetsPanel
