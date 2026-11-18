--!strict
-- EnchantAndBountyModal.luau: Bệ Xoay Dòng Enchant (3 Exclusive Rods + Bảng % Công Khai) & Hợp Đồng Fish Bounty

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local RodsConfig = require(Shared:WaitForChild("Config"):WaitForChild("RodsConfig"))
local EnchantsConfig = require(Shared:WaitForChild("Config"):WaitForChild("EnchantsConfig"))
local BountiesConfig = require(Shared:WaitForChild("Config"):WaitForChild("BountiesConfig"))
local IslandsRegistry = require(Shared:WaitForChild("Config"):WaitForChild("Islands"))

local Theme = require(script.Parent.Parent.Theme)
local WindowFrame = require(script.Parent.Parent.Components.WindowFrame)

local EnchantAndBountyModal = {}

local win: WindowFrame.BuiltWindow? = nil
local tabRefs: { [string]: TextButton } = {}
local currentTab = "Enchants"

local gemsCache = 0
local relicsCache = 0
local curRodId = "Twig"
local ownedRodsCache: { [string]: boolean } = { Twig = true }
local rodEnchantsCache: { [string]: string } = {}
local unlockedIslandsCache: { [string]: boolean } = { ["1"] = true }
local fishBagCache: { any } = {}
local selectedExclRod = "RelicTrident"

local fishDefs: { [string]: any } = {}
for _, isl in ipairs(IslandsRegistry.List) do
	for _, f in ipairs(isl.fishPool) do
		fishDefs[f.id] = f
	end
end

local function clearBody(body: ScrollingFrame)
	for _, ch in ipairs(body:GetChildren()) do
		if ch:IsA("GuiObject") then
			ch:Destroy()
		end
	end
end

local function makeRowCard(body: ScrollingFrame, order: number, h: number, strokeCol: Color3, bgCol: Color3): Frame
	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, 0, 0, h)
	card.BackgroundColor3 = bgCol
	card.LayoutOrder = order
	card.ZIndex = 22
	card.Parent = body
	Theme.AddCorner(card, 10)
	Theme.AddStroke(card, strokeCol, 2)
	return card
end

local function addCardText(card: Frame, title: string, sub: string, col: Color3, rightMargin: number)
	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(1, -rightMargin, 0, 24)
	t.Position = UDim2.fromOffset(12, 6)
	t.BackgroundTransparency = 1
	t.Font = Theme.FontTitle
	t.TextSize = 15
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.TextColor3 = col
	t.Text = title
	t.ZIndex = 23
	t.Parent = card
	Theme.AddTextStroke(t, 1.4)

	local s = Instance.new("TextLabel")
	s.Size = UDim2.new(1, -rightMargin, 0, 34)
	s.Position = UDim2.fromOffset(12, 29)
	s.BackgroundTransparency = 1
	s.Font = Theme.FontBody
	s.TextSize = 12
	s.TextWrapped = true
	s.TextXAlignment = Enum.TextXAlignment.Left
	s.TextColor3 = Theme.Colors.TextMuted
	s.Text = sub
	s.ZIndex = 23
	s.Parent = card
end

local function findBestMatchingFishForBounty(bDef: any): any?
	local reqOrder = GameConfig.RarityOrder[bDef.rarityReq] or 1
	for _, entry in ipairs(fishBagCache) do
		local fDef = fishDefs[tostring(entry.fishId)]
		if fDef then
			local rOrder = GameConfig.RarityOrder[fDef.rarity] or 1
			local w = tonumber(entry.weight) or 0
			local mut = tostring(entry.mutation or "None")
			local mutOk = (bDef.mutationReq == nil) or (bDef.mutationReq == "AnyMutated" and mut ~= "None") or (mut == bDef.mutationReq)
			if rOrder >= reqOrder and w >= bDef.minWeight and mutOk then
				return entry
			end
		end
	end
	return nil
end

function EnchantAndBountyModal.Render()
	local w = win
	if not w then
		return
	end
	clearBody(w.body)

	if currentTab == "Exclusive" then
		local bestBase = RodsConfig.GetBestNormalRod(ownedRodsCache)
		local banner = makeRowCard(w.body, 0, 56, Theme.Colors.Gold, Theme.Colors.CardOwned)
		addCardText(
			banner,
			string.format("⚡ Scaling Baseline: %s (%s Max Kg)", bestBase.name, Util.FormatWeight(bestBase.maxWeight)),
			"Exclusive Rods scale 115%–130% off your best Normal Rod, stay after Rebirth & unlock Ancient Enchants!",
			Theme.Colors.Gold,
			20
		)

		for idx, ex in ipairs(RodsConfig.ExclusiveList) do
			local owned = ownedRodsCache[ex.id] == true
			local equipped = (curRodId == ex.id)
			local eff = RodsConfig.GetEffectiveStats(ex.id, ownedRodsCache, rodEnchantsCache)
			local ench = if eff.enchantId then EnchantsConfig.ById[eff.enchantId] else nil
			local card = makeRowCard(w.body, idx, 74, ex.accentColor, if owned then Theme.Colors.CardOwned else Theme.Colors.CardBg)
			local enchTxt = if ench then (" • 🔮 " .. ench.name) else ""
			addCardText(
				card,
				string.format("👑 %s (%d%% Scaling)%s", ex.name, math.floor((ex.scaleFactor or 1.15) * 100), enchTxt),
				string.format("Effective: %s Max • +%d%% Lure • +%d%% Luck • +%d%% Ctrl  |  %s", Util.FormatWeight(eff.maxWeight), math.floor(eff.lureSpeed * 100), math.floor(eff.luckBonus * 100), math.floor(eff.controlBonus * 100), ex.unlockHint or ""),
				ex.accentColor,
				154
			)

			local btnLabel = if equipped then "EQUIPPED" elseif owned then "EQUIP" elseif ex.id == "SeraphimDragon" then "PASS (399 R$)" elseif ex.id == "VoidScythe" then "2,200 GEMS" else "EXCHANGE"
			local btnCol = if equipped then Theme.Colors.Primary elseif owned then Theme.Colors.Success else Theme.Colors.Gems
			local actBtn = Theme.CreateButton(card, "ActBtn", btnLabel, UDim2.fromOffset(132, 38), UDim2.new(1, -144, 0.5, -19), btnCol, function()
				if owned then
					selectedExclRod = ex.id
					Net.FireServer(Net.ClientToServer.EquipRod, ex.id)
				elseif ex.id == "SeraphimDragon" then
					Net.FireServer(Net.ClientToServer.PromptGamepass, "ExclusiveDragonRod")
				else
					Net.FireServer(Net.ClientToServer.UnlockExclusiveRod, ex.id, nil)
				end
			end)
			actBtn.TextSize = 13
			actBtn.ZIndex = 24
		end
	elseif currentTab == "Enchants" then
		local curDef = RodsConfig.Get(curRodId)
		if curDef.isExclusive and ownedRodsCache[curDef.id] then
			selectedExclRod = curDef.id
		else
			for _, ex in ipairs(RodsConfig.ExclusiveList) do
				if ownedRodsCache[ex.id] then
					selectedExclRod = ex.id
					break
				end
			end
		end

		local targetDef = RodsConfig.Get(selectedExclRod)
		local ownsTarget = ownedRodsCache[selectedExclRod] == true
		local curEnchId = rodEnchantsCache[selectedExclRod]
		local curEnch = if curEnchId then EnchantsConfig.ById[curEnchId] else nil

		local topCard = makeRowCard(w.body, 0, 82, Theme.Colors.Gems, Theme.Colors.CardOwned)
		addCardText(
			topCard,
			string.format("🔮 Altar Target: %s  •  Relics: %d  •  Gems: %s", targetDef.name, relicsCache, Util.FormatNumber(gemsCache)),
			if not ownsTarget
				then "Unlock any Exclusive Rod (Exclusive Tab) to roll Ancient Enchants!"
				elseif curEnch then string.format("Current Enchant: [%s] %s — %s", curEnch.rarity, curEnch.name, curEnch.description)
				else "No Enchant yet — Roll with 1 Relic or 75 Gems! (Guaranteed different Enchant each roll)",
			Theme.Colors.Gems,
			264
		)

		local rBtn = Theme.CreateButton(topCard, "RollRelicBtn", "🔮 1 RELIC", UDim2.fromOffset(116, 36), UDim2.new(1, -250, 0.5, -18), Theme.Colors.Success, function()
			Net.FireServer(Net.ClientToServer.RollEnchant, selectedExclRod, false)
		end)
		rBtn.TextSize = 13
		rBtn.ZIndex = 24

		local gBtn = Theme.CreateButton(topCard, "RollGemBtn", "💎 75 GEMS", UDim2.fromOffset(116, 36), UDim2.new(1, -126, 0.5, -18), Theme.Colors.Gems, function()
			Net.FireServer(Net.ClientToServer.RollEnchant, selectedExclRod, true)
		end)
		gBtn.TextSize = 13
		gBtn.ZIndex = 24

		for idx, e in ipairs(EnchantsConfig.List) do
			local isActive = (curEnchId == e.id)
			local row = makeRowCard(w.body, idx, 62, e.color, if isActive then Theme.Colors.CardOwned else Theme.Colors.CardBg)
			addCardText(
				row,
				string.format("[%s] %s — %.0f%% Drop Chance %s", e.rarity, e.name, e.chance * 100, if isActive then "(ACTIVE ✅)" else ""),
				e.description,
				e.color,
				20
			)
		end
	else
		local info = makeRowCard(w.body, 0, 54, Theme.Colors.Gold, Theme.Colors.CardOwned)
		addCardText(
			info,
			"📜 Collector Finn's Fish Bounties (Soulbound Trophies Accepted!)",
			"Turn in qualifying catches to earn Gems, Potions & Ancient Enchant Relics!",
			Theme.Colors.Gold,
			20
		)

		for idx, bDef in ipairs(BountiesConfig.List) do
			local islOk = unlockedIslandsCache[tostring(bDef.islandReq)] == true
			local candidate = if islOk then findBestMatchingFishForBounty(bDef) else nil
			local fName = if candidate and fishDefs[tostring(candidate.fishId)] then fishDefs[tostring(candidate.fishId)].name else ""
			local row = makeRowCard(w.body, idx, 74, Theme.Colors.Primary, Theme.Colors.CardBg)
			local matchNote = if not islOk
				then string.format("🔒 Unlock Island %d first!", bDef.islandReq)
				elseif candidate then string.format("✅ Ready: %s (%s)%s", fName, Util.FormatWeight(tonumber(candidate.weight) or 0), if candidate.soulbound then " [Trophy]" else "")
				else "Catch a matching fish to turn in!"
			addCardText(
				row,
				string.format("📋 %s  •  +%d Gems, +%d Relic", bDef.title, bDef.gemReward, bDef.relicReward),
				bDef.description .. "  |  " .. matchNote,
				if candidate then Theme.Colors.Success else Theme.Colors.TextPrimary,
				146
			)

			local tBtn = Theme.CreateButton(
				row,
				"TurnInBtn",
				if candidate then "TURN IN" else "NEED FISH",
				UDim2.fromOffset(126, 38),
				UDim2.new(1, -138, 0.5, -19),
				if candidate then Theme.Colors.Success else Color3.fromRGB(72, 82, 106),
				function()
					if candidate and type(candidate.uid) == "string" then
						Net.FireServer(Net.ClientToServer.TurnInBounty, bDef.id, candidate.uid)
					end
				end
			)
			tBtn.TextSize = 13
			tBtn.ZIndex = 24
		end
	end
end

function EnchantAndBountyModal.OpenTab(tabKey: string)
	currentTab = tabKey
	if win and tabRefs[tabKey] then
		win.SetActiveTab(tabRefs[tabKey])
	end
	EnchantAndBountyModal.Render()
end

function EnchantAndBountyModal.Mount(rootGui: ScreenGui): WindowFrame.BuiltWindow
	local built = WindowFrame.Create(rootGui, "EnchantAndBountyWindow", "🔮 EXCLUSIVE RODS, ENCHANTS & BOUNTIES", UDim2.fromOffset(650, 450), Color3.fromRGB(168, 96, 255))
	win = built

	tabRefs["Exclusive"] = built.AddTab("Exclusive", function() currentTab = "Exclusive"; EnchantAndBountyModal.Render() end)
	tabRefs["Enchants"] = built.AddTab("Enchants", function() currentTab = "Enchants"; EnchantAndBountyModal.Render() end)
	tabRefs["Bounties"] = built.AddTab("Bounties", function() currentTab = "Bounties"; EnchantAndBountyModal.Render() end)
	built.SetActiveTab(tabRefs["Enchants"])
	return built
end

function EnchantAndBountyModal.SyncState(
	gems: number,
	rodId: string,
	ownedRods: { [string]: boolean },
	rodEnchants: { [string]: string },
	relics: number,
	unlockedIslands: { [string]: boolean }?,
	fishBag: { any }?
)
	gemsCache = gems
	curRodId = rodId
	ownedRodsCache = ownedRods
	rodEnchantsCache = rodEnchants
	relicsCache = relics
	if unlockedIslands then unlockedIslandsCache = unlockedIslands end
	if fishBag then fishBagCache = fishBag end
	if win and win.IsVisible() then
		EnchantAndBountyModal.Render()
	end
end

return EnchantAndBountyModal
