--!strict
-- EnchantAndBountyModal.luau: 3 Exclusive Rods (Chon Boss Mo Khoa), Be Enchant (Base % vs Effective % + Policy) & Fish Bounty Picker

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))
local OddsCalculator = require(Shared:WaitForChild("OddsCalculator"))
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local RodsConfig = require(Shared:WaitForChild("Config"):WaitForChild("RodsConfig"))
local EnchantsConfig = require(Shared:WaitForChild("Config"):WaitForChild("EnchantsConfig"))
local BountiesConfig = require(Shared:WaitForChild("Config"):WaitForChild("BountiesConfig"))
local IslandsRegistry = require(Shared:WaitForChild("Config"):WaitForChild("Islands"))

local Theme = require(script.Parent.Parent.Theme)
local PurchaseOddsController = require(script.Parent.Parent.Parent.Controllers.PurchaseOddsController)
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
local policyStateCache = "Loading"
local selectedExclRod = "RelicTrident"
local selectedTridentIdx = 1
local selectedBountyIdx: { [string]: number } = {}

local fishDefs: { [string]: any } = {}
for _, isl in ipairs(IslandsRegistry.List) do
	for _, f in ipairs(isl.fishPool) do
		fishDefs[f.id] = f
	end
end

local function clearBody(body: ScrollingFrame)
	for _, ch in ipairs(body:GetChildren()) do
		if ch:IsA("GuiObject") then ch:Destroy() end
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
	t.Size = UDim2.new(1, -rightMargin, 0, 23)
	t.Position = UDim2.fromOffset(12, 5)
	t.BackgroundTransparency = 1
	t.Font = Theme.FontTitle
	t.TextSize = 14
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.TextColor3 = col
	t.Text = title
	t.ZIndex = 23
	t.Parent = card
	Theme.AddTextStroke(t, 1.4)

	local s = Instance.new("TextLabel")
	s.Size = UDim2.new(1, -rightMargin, 1, -31)
	s.Position = UDim2.fromOffset(12, 28)
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

local function getEligibleTridentBosses(): ({ any }, number)
	local unlocked: { any } = {}
	local protectedCount = 0
	for _, entry in ipairs(fishBagCache) do
		local fDef = fishDefs[tostring(entry.fishId)]
		if fDef and fDef.rarity == "Boss" and fDef.islandId >= 3 then
			if entry.soulbound == true or entry.locked == true then
				protectedCount += 1
			else
				table.insert(unlocked, entry)
			end
		end
	end
	table.sort(unlocked, function(a: any, b: any): boolean
		local va = tonumber(a.originalValue) or tonumber(a.sellValue) or 0
		local vb = tonumber(b.originalValue) or tonumber(b.sellValue) or 0
		if va ~= vb then return va < vb end
		return tostring(a.uid) < tostring(b.uid)
	end)
	return unlocked, protectedCount
end

local function getMatchingBountyFishList(bDef: any): { any }
	local reqOrder = GameConfig.RarityOrder[bDef.rarityReq] or 1
	local matches: { any } = {}
	for _, entry in ipairs(fishBagCache) do
		local fDef = fishDefs[tostring(entry.fishId)]
		if fDef then
			local rOrder = GameConfig.RarityOrder[fDef.rarity] or 1
			local w = tonumber(entry.weight) or 0
			local mut = tostring(entry.mutation or "None")
			local mutOk = (bDef.mutationReq == nil) or (bDef.mutationReq == "AnyMutated" and mut ~= "None") or (mut == bDef.mutationReq)
			if rOrder >= reqOrder and w >= bDef.minWeight and mutOk then
				table.insert(matches, entry)
			end
		end
	end
	-- Uu tien ca mo khoa thuong re nhat truoc -> ca khoa -> Soulbound Trophy xep sau cung!
	table.sort(matches, function(a: any, b: any): boolean
		local rankA = if a.soulbound == true then 3 elseif a.locked == true then 2 else 1
		local rankB = if b.soulbound == true then 3 elseif b.locked == true then 2 else 1
		if rankA ~= rankB then return rankA < rankB end
		local va = tonumber(a.originalValue) or tonumber(a.sellValue) or 0
		local vb = tonumber(b.originalValue) or tonumber(b.sellValue) or 0
		if va ~= vb then return va < vb end
		return tostring(a.uid) < tostring(b.uid)
	end)
	return matches
end

function EnchantAndBountyModal.Render()
	local w = win
	if not w then return end
	clearBody(w.body)

	if currentTab == "Exclusive" then
		local bestBase = RodsConfig.GetBestNormalRod(ownedRodsCache)
		local banner = makeRowCard(w.body, 0, 54, Theme.Colors.Gold, Theme.Colors.CardOwned)
		addCardText(banner, string.format("⚡ Scaling Baseline: %s (%s Max Kg)", bestBase.name, Util.FormatWeight(bestBase.maxWeight)), "Exclusive Rods scale 115%–130% off your best Normal Rod, persist Rebirth & unlock Enchants!", Theme.Colors.Gold, 20)

		local unlockedBosses, protectedBosses = getEligibleTridentBosses()
		if selectedTridentIdx > #unlockedBosses then selectedTridentIdx = 1 end
		local pickedBoss = unlockedBosses[selectedTridentIdx]

		for idx, ex in ipairs(RodsConfig.ExclusiveList) do
			local owned = ownedRodsCache[ex.id] == true
			local equipped = (curRodId == ex.id)
			local eff = RodsConfig.GetEffectiveStats(ex.id, ownedRodsCache, rodEnchantsCache)
			local ench = if eff.enchantId then EnchantsConfig.ById[eff.enchantId] else nil
			local card = makeRowCard(w.body, idx, 84, ex.accentColor, if owned then Theme.Colors.CardOwned else Theme.Colors.CardBg)
			local enchTxt = if ench then (" • 🔮 " .. ench.name) else ""
			local subLine = string.format("Effective: %s Max • +%d%% Lure • +%d%% Luck • +%d%% Ctrl • %d%% Stdy", Util.FormatWeight(eff.maxWeight), math.floor(eff.lureSpeed * 100), math.floor(eff.luckBonus * 100), math.floor(eff.controlBonus * 100), math.floor(eff.steadiness * 100))
			if not owned and ex.id == "RelicTrident" then
				if pickedBoss then
					local bName = if fishDefs[tostring(pickedBoss.fishId)] then fishDefs[tostring(pickedBoss.fishId)].name else "Boss"
					subLine = subLine .. string.format("\n🎯 Sacrifice (%d/%d): %s (%s • Unlocked) + 800 Gems", selectedTridentIdx, #unlockedBosses, bName, Util.FormatWeight(tonumber(pickedBoss.weight) or 1))
				elseif protectedBosses > 0 then
					subLine = subLine .. "\n🔒 Protected Island 3+ Boss in Bag (Locked/Trophy)! Unlock a non-Trophy Boss to trade."
				else
					subLine = subLine .. "\n" .. tostring(ex.unlockHint or "")
				end
			elseif not owned then
				subLine = subLine .. "\n" .. tostring(ex.unlockHint or "")
			end

			local rightPad = if not owned and ex.id == "RelicTrident" and #unlockedBosses > 1 then 232 else 154
			addCardText(card, string.format("👑 %s (%d%% Scaling)%s", ex.name, math.floor((ex.scaleFactor or 1.15) * 100), enchTxt), subLine, ex.accentColor, rightPad)

			if not owned and ex.id == "RelicTrident" and #unlockedBosses > 1 then
				local cyc = Theme.CreateButton(card, "CycleBossBtn", "🔄 Next", UDim2.fromOffset(72, 36), UDim2.new(1, -222, 0.5, -18), Theme.Colors.CardBg, function()
					selectedTridentIdx = (selectedTridentIdx % #unlockedBosses) + 1
					EnchantAndBountyModal.Render()
				end)
				cyc.TextSize = 12; cyc.ZIndex = 24
			end

			local canTradeTrident = (ex.id ~= "RelicTrident") or (pickedBoss ~= nil)
			local btnLabel = if equipped then "EQUIPPED" elseif owned then "EQUIP" elseif ex.id == "SeraphimDragon" then "PASS (399 R$)" elseif ex.id == "VoidScythe" then "2,200 GEMS" elseif pickedBoss then "EXCHANGE" else "NEED BOSS"
			local btnCol = if equipped then Theme.Colors.Primary elseif owned then Theme.Colors.Success elseif not canTradeTrident then Color3.fromRGB(78, 86, 108) else Theme.Colors.Gems
			local actBtn = Theme.CreateButton(card, "ActBtn", btnLabel, UDim2.fromOffset(132, 38), UDim2.new(1, -144, 0.5, -19), btnCol, function()
				if owned then
					selectedExclRod = ex.id; Net.FireServer(Net.ClientToServer.EquipRod, ex.id)
				elseif ex.id == "SeraphimDragon" then
					PurchaseOddsController.Show("ExclusiveDragonRod")
				elseif ex.id == "RelicTrident" then
					if pickedBoss and type(pickedBoss.uid) == "string" then
						Net.FireServer(Net.ClientToServer.UnlockExclusiveRod, ex.id, pickedBoss.uid)
					end
				else
					Net.FireServer(Net.ClientToServer.UnlockExclusiveRod, ex.id, nil)
				end
			end)
			actBtn.TextSize = 13; actBtn.ZIndex = 24
		end
	elseif currentTab == "Enchants" then
		local curDef = RodsConfig.Get(curRodId)
		if curDef.isExclusive and ownedRodsCache[curDef.id] then selectedExclRod = curDef.id
		else
			for _, ex in ipairs(RodsConfig.ExclusiveList) do
				if ownedRodsCache[ex.id] then selectedExclRod = ex.id; break end
			end
		end

		local targetDef = RodsConfig.Get(selectedExclRod)
		local ownsTarget = ownedRodsCache[selectedExclRod] == true
		local curEnchId = rodEnchantsCache[selectedExclRod]
		local curEnch = if curEnchId then EnchantsConfig.ById[curEnchId] else nil

		local topCard = makeRowCard(w.body, 0, 82, Theme.Colors.Gems, Theme.Colors.CardOwned)
		addCardText(topCard, string.format("🔮 Altar Target: %s  •  Relics: %d  •  Gems: %s", targetDef.name, relicsCache, Util.FormatNumber(gemsCache)),
			if not ownsTarget then "Unlock any Exclusive Rod (Exclusive Tab) & stand at Island Enchant Altar to roll!"
			elseif curEnch then string.format("Active: [%s] %s — Next roll excludes %s & re-normalizes remaining 5 Enchants!", curEnch.rarity, curEnch.name, curEnch.name)
			else "No Enchant yet — Stand near the Ancient Enchant Altar & roll with 1 Relic or 75 Gems!",
			Theme.Colors.Gems, 268)

		local rBtn = Theme.CreateButton(topCard, "RollRelicBtn", "🔮 1 RELIC", UDim2.fromOffset(116, 36), UDim2.new(1, -252, 0.5, -18), Theme.Colors.Success, function()
			Net.FireServer(Net.ClientToServer.RollEnchant, selectedExclRod, false)
		end)
		rBtn.TextSize = 13; rBtn.ZIndex = 24

		local gemAllowed = (policyStateCache == "Allowed")
		local gemTxt = if policyStateCache == "Loading" then "⏳ POLICY..." elseif policyStateCache == "Restricted" then "🚫 RESTRICTED" else "💎 75 GEMS"
		local gBtn = Theme.CreateButton(topCard, "RollGemBtn", gemTxt, UDim2.fromOffset(118, 36), UDim2.new(1, -128, 0.5, -18), if gemAllowed then Theme.Colors.Gems else Color3.fromRGB(78, 84, 104), function()
			if gemAllowed then Net.FireServer(Net.ClientToServer.RollEnchant, selectedExclRod, true) end
		end)
		gBtn.TextSize = 12; gBtn.ZIndex = 24

		local oddsList = OddsCalculator.ComputeEnchantOdds(curEnchId)
		for idx, item in ipairs(oddsList) do
			local e = item.enchant
			local isActive = (curEnchId == e.id)
			local row = makeRowCard(w.body, idx, 62, e.color, if isActive then Theme.Colors.CardOwned else Theme.Colors.CardBg)
			addCardText(row, string.format("[%s] %s — Base %.0f%%  →  Effective %.2f%% %s", e.rarity, e.name, item.basePct, item.effectivePct, if isActive then "(ACTIVE — 0% Next Roll)" else ""), e.description, e.color, 20)
		end
	else
		local info = makeRowCard(w.body, 0, 54, Theme.Colors.Gold, Theme.Colors.CardOwned)
		addCardText(info, "📜 Collector Finn's Fish Bounties (Stand near Old Man Finn!)", "Unlocked normal fish are picked first; cycle [🔄] if you wish to turn in another catch or Soulbound Trophy!", Theme.Colors.Gold, 20)

		for idx, bDef in ipairs(BountiesConfig.List) do
			local islOk = unlockedIslandsCache[tostring(bDef.islandReq)] == true
			local matches = if islOk then getMatchingBountyFishList(bDef) else {}
			local pickIdx = selectedBountyIdx[bDef.id] or 1
			if pickIdx > #matches then pickIdx = 1; selectedBountyIdx[bDef.id] = 1 end
			local candidate = matches[pickIdx]
			local fName = if candidate and fishDefs[tostring(candidate.fishId)] then fishDefs[tostring(candidate.fishId)].name else ""
			local isTrophy = candidate ~= nil and candidate.soulbound == true
			local isLocked = candidate ~= nil and candidate.locked == true
			local tagTxt = if isTrophy then " [⚠️ CONSUMES TROPHY]" elseif isLocked then " [🔒 Locked]" else ""

			local row = makeRowCard(w.body, idx, 78, if isTrophy then Theme.Colors.Warning else Theme.Colors.Primary, Theme.Colors.CardBg)
			local matchNote = if not islOk then string.format("🔒 Unlock Island %d first!", bDef.islandReq)
				elseif candidate then string.format("🎯 Selected (%d/%d): %s (%s)%s", pickIdx, #matches, fName, Util.FormatWeight(tonumber(candidate.weight) or 0), tagTxt)
				else "Catch a matching fish to turn in!"

			local rightPad = if #matches > 1 then 224 else 146
			addCardText(row, string.format("📋 %s  •  +%d Gems, +%d Relic", bDef.title, bDef.gemReward, bDef.relicReward), bDef.description .. "\n" .. matchNote, if candidate then Theme.Colors.Success else Theme.Colors.TextPrimary, rightPad)

			if #matches > 1 then
				local cycBtn = Theme.CreateButton(row, "NextFishBtn", string.format("🔄 %d/%d", pickIdx, #matches), UDim2.fromOffset(72, 36), UDim2.new(1, -216, 0.5, -18), Theme.Colors.CardBg, function()
					selectedBountyIdx[bDef.id] = (pickIdx % #matches) + 1
					EnchantAndBountyModal.Render()
				end)
				cycBtn.TextSize = 12; cycBtn.ZIndex = 24
			end

			local btnTxt = if not candidate then "NEED FISH" elseif isTrophy then "GIVE TROPHY" else "TURN IN"
			local btnCol = if not candidate then Color3.fromRGB(72, 82, 106) elseif isTrophy then Theme.Colors.Warning else Theme.Colors.Success
			local tBtn = Theme.CreateButton(row, "TurnInBtn", btnTxt, UDim2.fromOffset(128, 38), UDim2.new(1, -138, 0.5, -19), btnCol, function()
				if candidate and type(candidate.uid) == "string" then
					Net.FireServer(Net.ClientToServer.TurnInBounty, bDef.id, candidate.uid)
				end
			end)
			tBtn.TextSize = 12; tBtn.ZIndex = 24
		end
	end
end

function EnchantAndBountyModal.OpenTab(tabKey: string)
	currentTab = tabKey
	if win and tabRefs[tabKey] then win.SetActiveTab(tabRefs[tabKey]) end
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

function EnchantAndBountyModal.SyncPolicyState(policyState: string)
	policyStateCache = policyState
	if win and win.IsVisible() and currentTab == "Enchants" then EnchantAndBountyModal.Render() end
end

function EnchantAndBountyModal.SyncState(gems: number, rodId: string, ownedRods: { [string]: boolean }, rodEnchants: { [string]: string }, relics: number, unlockedIslands: { [string]: boolean }?, fishBag: { any }?)
	gemsCache = gems; curRodId = rodId; ownedRodsCache = ownedRods; rodEnchantsCache = rodEnchants; relicsCache = relics
	if unlockedIslands then unlockedIslandsCache = unlockedIslands end
	if fishBag then fishBagCache = fishBag end
	if win and win.IsVisible() then EnchantAndBountyModal.Render() end
end

return EnchantAndBountyModal
