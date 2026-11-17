--!strict
-- BagPanel.luau: Tui do 3 tab (Fish, Potions, Bait) kem nut Sell All & chon Bait/dung Potion

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local IslandsRegistry = require(Shared:WaitForChild("Config"):WaitForChild("Islands"))

local Theme = require(script.Parent.Parent.Theme)
local WindowFrame = require(script.Parent.Parent.Components.WindowFrame)

local BagPanel = {}

local win: WindowFrame.BuiltWindow? = nil
local currentTab = "Fish"
local fishBagCache: { Types.CaughtFish } = {}
local potionsCache: { [string]: number } = {}
local baitCache: { [string]: number } = {}
local activeBaitCache: string? = nil

local potionsConfigRef: any = nil
local baitConfigRef: any = nil

local function ensureOptionalConfigs()
	local cfgFolder = Shared:FindFirstChild("Config")
	if not cfgFolder then
		return
	end
	if not potionsConfigRef then
		local pMod = cfgFolder:FindFirstChild("PotionsConfig")
		if pMod and pMod:IsA("ModuleScript") then
			potionsConfigRef = require(pMod) :: any
		end
	end
	if not baitConfigRef then
		local bMod = cfgFolder:FindFirstChild("BaitConfig")
		if bMod and bMod:IsA("ModuleScript") then
			baitConfigRef = require(bMod) :: any
		end
	end
end

local function clearBody(body: ScrollingFrame)
	for _, child in ipairs(body:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function createEmptyLabel(body: ScrollingFrame, text: string)
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 0, 64)
	lbl.BackgroundTransparency = 1
	lbl.Font = Theme.FontBody
	lbl.TextSize = 16
	lbl.TextColor3 = Theme.Colors.TextMuted
	lbl.Text = text
	lbl.ZIndex = 22
	lbl.Parent = body
end

function BagPanel.Render()
	local w = win
	if not w then
		return
	end
	ensureOptionalConfigs()
	clearBody(w.body)

	if currentTab == "Fish" then
		local topRow = Instance.new("Frame")
		topRow.Size = UDim2.new(1, 0, 0, 44)
		topRow.BackgroundTransparency = 1
		topRow.LayoutOrder = 0
		topRow.ZIndex = 22
		topRow.Parent = w.body

		local totalVal = 0
		for _, f in ipairs(fishBagCache) do
			totalVal += f.sellValue
		end

		local summary = Instance.new("TextLabel")
		summary.Size = UDim2.new(0.62, 0, 1, 0)
		summary.BackgroundTransparency = 1
		summary.Font = Theme.FontTitle
		summary.TextSize = 18
		summary.TextXAlignment = Enum.TextXAlignment.Left
		summary.TextColor3 = Theme.Colors.TextPrimary
		summary.Text = string.format("Fish: %d / %d • Base Value: %s Gold", #fishBagCache, GameConfig.BAG_CAPACITY, Util.FormatNumber(totalVal))
		summary.ZIndex = 22
		summary.Parent = topRow
		Theme.AddTextStroke(summary, 1.6)

		local sellAllBtn = Theme.CreateButton(
			topRow,
			"SellAllBtn",
			"💰 SELL ALL FISH",
			UDim2.fromOffset(170, 38),
			UDim2.new(1, -172, 0.5, -19),
			Theme.Colors.Success,
			function()
				Net.FireServer(Net.ClientToServer.SellAllFish)
			end
		)
		sellAllBtn.TextSize = 15
		sellAllBtn.ZIndex = 23

		if #fishBagCache == 0 then
			createEmptyLabel(w.body, "Your Fish Bag is empty! Cast your rod near the ocean to catch fish.")
			return
		end

		for idx = #fishBagCache, 1, -1 do
			local caught = fishBagCache[idx]
			local def = IslandsRegistry.GetFish(caught.fishId)
			local fishName = if def then def.name else caught.fishId
			local rarity = if def then def.rarity else "Common"
			local rColor = Theme.RarityColors[rarity] or Theme.Colors.TextMuted

			local card = Instance.new("Frame")
			card.Name = "Fish_" .. caught.uid
			card.Size = UDim2.new(1, 0, 0, 56)
			card.BackgroundColor3 = Theme.Colors.CardBg
			card.LayoutOrder = #fishBagCache - idx + 1
			card.ZIndex = 22
			card.Parent = w.body
			Theme.AddCorner(card, 10)
			Theme.AddStroke(card, rColor, 2)

			local mutTag = if caught.mutation ~= "None" then ("[" .. caught.mutation .. "] ") else ""
			local nameLbl = Instance.new("TextLabel")
			nameLbl.Size = UDim2.new(0.68, 0, 0, 28)
			nameLbl.Position = UDim2.fromOffset(12, 4)
			nameLbl.BackgroundTransparency = 1
			nameLbl.Font = Theme.FontTitle
			nameLbl.TextSize = 17
			nameLbl.TextXAlignment = Enum.TextXAlignment.Left
			nameLbl.TextColor3 = rColor
			nameLbl.Text = string.format("%s%s (%s)", mutTag, fishName, rarity)
			nameLbl.ZIndex = 23
			nameLbl.Parent = card
			Theme.AddTextStroke(nameLbl, 1.5)

			local subLbl = Instance.new("TextLabel")
			subLbl.Size = UDim2.new(0.68, 0, 0, 20)
			subLbl.Position = UDim2.fromOffset(12, 30)
			subLbl.BackgroundTransparency = 1
			subLbl.Font = Theme.FontBody
			subLbl.TextSize = 13
			subLbl.TextXAlignment = Enum.TextXAlignment.Left
			subLbl.TextColor3 = Theme.Colors.TextMuted
			subLbl.Text = string.format("Weight: %s • Base: %s Gold", Util.FormatWeight(caught.weight), Util.FormatNumber(caught.sellValue))
			subLbl.ZIndex = 23
			subLbl.Parent = card

			local sellOne = Theme.CreateButton(
				card,
				"SellOne",
				"Sell",
				UDim2.fromOffset(82, 36),
				UDim2.new(1, -94, 0.5, -18),
				Theme.Colors.Gold,
				function()
					Net.FireServer(Net.ClientToServer.SellSingleFish, caught.uid)
				end
			)
			sellOne.TextSize = 15
			sellOne.ZIndex = 23
		end
	elseif currentTab == "Potions" then
		if not potionsConfigRef then
			createEmptyLabel(w.body, "Potions unlock with Island Drops, Achievements & Events!")
			return
		end
		local hasAny = false
		for idx, pDef in ipairs(potionsConfigRef.List) do
			local cnt = potionsCache[pDef.id] or 0
			if cnt > 0 then
				hasAny = true
				local card = Instance.new("Frame")
				card.Size = UDim2.new(1, 0, 0, 58)
				card.BackgroundColor3 = Theme.Colors.CardBg
				card.LayoutOrder = idx
				card.ZIndex = 22
				card.Parent = w.body
				Theme.AddCorner(card, 10)
				Theme.AddStroke(card, pDef.color, 2)

				local title = Instance.new("TextLabel")
				title.Size = UDim2.new(0.68, 0, 0, 26)
				title.Position = UDim2.fromOffset(12, 5)
				title.BackgroundTransparency = 1
				title.Font = Theme.FontTitle
				title.TextSize = 17
				title.TextXAlignment = Enum.TextXAlignment.Left
				title.TextColor3 = pDef.color
				title.Text = string.format("🧪 %s (x%d)", pDef.name, cnt)
				title.ZIndex = 23
				title.Parent = card
				Theme.AddTextStroke(title, 1.5)

				local desc = Instance.new("TextLabel")
				desc.Size = UDim2.new(0.68, 0, 0, 20)
				desc.Position = UDim2.fromOffset(12, 31)
				desc.BackgroundTransparency = 1
				desc.Font = Theme.FontBody
				desc.TextSize = 13
				desc.TextXAlignment = Enum.TextXAlignment.Left
				desc.TextColor3 = Theme.Colors.TextMuted
				desc.Text = pDef.description
				desc.ZIndex = 23
				desc.Parent = card

				local useBtn = Theme.CreateButton(card, "UseBtn", "DRINK", UDim2.fromOffset(96, 36), UDim2.new(1, -108, 0.5, -18), Theme.Colors.Success, function()
					Net.FireServer(Net.ClientToServer.UsePotion, pDef.id)
				end)
				useBtn.TextSize = 15
				useBtn.ZIndex = 23
			end
		end
		if not hasAny then
			createEmptyLabel(w.body, "No Potions in Bag yet! Catch Rare/Boss fish or complete Achievements.")
		end
	else
		if not baitConfigRef then
			createEmptyLabel(w.body, "Visit the Angler Shop to buy Bait packs!")
			return
		end
		local hasBait = false
		for idx, bDef in ipairs(baitConfigRef.List) do
			local cnt = baitCache[bDef.id] or 0
			if cnt > 0 then
				hasBait = true
				local isActive = (activeBaitCache == bDef.id)
				local card = Instance.new("Frame")
				card.Size = UDim2.new(1, 0, 0, 58)
				card.BackgroundColor3 = if isActive then Theme.Colors.CardOwned else Theme.Colors.CardBg
				card.LayoutOrder = idx
				card.ZIndex = 22
				card.Parent = w.body
				Theme.AddCorner(card, 10)
				Theme.AddStroke(card, bDef.color, 2)

				local title = Instance.new("TextLabel")
				title.Size = UDim2.new(0.66, 0, 0, 26)
				title.Position = UDim2.fromOffset(12, 5)
				title.BackgroundTransparency = 1
				title.Font = Theme.FontTitle
				title.TextSize = 17
				title.TextXAlignment = Enum.TextXAlignment.Left
				title.TextColor3 = bDef.color
				title.Text = string.format("🪱 %s (x%d)", bDef.name, cnt)
				title.ZIndex = 23
				title.Parent = card
				Theme.AddTextStroke(title, 1.5)

				local desc = Instance.new("TextLabel")
				desc.Size = UDim2.new(0.66, 0, 0, 20)
				desc.Position = UDim2.fromOffset(12, 31)
				desc.BackgroundTransparency = 1
				desc.Font = Theme.FontBody
				desc.TextSize = 13
				desc.TextXAlignment = Enum.TextXAlignment.Left
				desc.TextColor3 = Theme.Colors.TextMuted
				desc.Text = bDef.description
				desc.ZIndex = 23
				desc.Parent = card

				local selBtn = Theme.CreateButton(
					card,
					"SelectBtn",
					if isActive then "ACTIVE" else "EQUIP",
					UDim2.fromOffset(102, 36),
					UDim2.new(1, -114, 0.5, -18),
					if isActive then Theme.Colors.Warning else Theme.Colors.Primary,
					function()
						Net.FireServer(Net.ClientToServer.SelectBait, if isActive then "" else bDef.id)
					end
				)
				selBtn.TextSize = 15
				selBtn.ZIndex = 23
			end
		end
		if not hasBait then
			createEmptyLabel(w.body, "No Bait owned! Buy Worm, Shiny, Boss or Cosmic Bait in the Shop.")
		end
	end
end

function BagPanel.Mount(rootGui: ScreenGui): WindowFrame.BuiltWindow
	local built = WindowFrame.Create(rootGui, "BagWindow", "🎒 ANGLER BAG", UDim2.fromOffset(580, 420), Theme.Colors.Primary)
	win = built

	local fishTab = built.AddTab("Fish", function()
		currentTab = "Fish"
		BagPanel.Render()
	end)
	built.AddTab("Potions", function()
		currentTab = "Potions"
		BagPanel.Render()
	end)
	built.AddTab("Bait", function()
		currentTab = "Bait"
		BagPanel.Render()
	end)
	built.SetActiveTab(fishTab)
	BagPanel.Render()
	return built
end

function BagPanel.UpdateFishBag(fishList: { Types.CaughtFish })
	fishBagCache = fishList
	if win and win.IsVisible() and currentTab == "Fish" then
		BagPanel.Render()
	end
end

function BagPanel.UpdateItems(potions: { [string]: number }, bait: { [string]: number }, activeBait: string?)
	potionsCache = potions
	baitCache = bait
	activeBaitCache = activeBait
	if win and win.IsVisible() and currentTab ~= "Fish" then
		BagPanel.Render()
	end
end

return BagPanel
