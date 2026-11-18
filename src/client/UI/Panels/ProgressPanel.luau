--!strict
-- ProgressPanel.luau: Giao dien 4 tab (Rebirth kem Xem Truoc 12 Soulbound Trophies, Quests, Index, Achievements)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local RebirthConfig = require(Shared:WaitForChild("Config"):WaitForChild("RebirthConfig"))
local AchievementsConfig = require(Shared:WaitForChild("Config"):WaitForChild("AchievementsConfig"))
local IslandsRegistry = require(Shared:WaitForChild("Config"):WaitForChild("Islands"))

local Theme = require(script.Parent.Parent.Theme)
local WindowFrame = require(script.Parent.Parent.Components.WindowFrame)
local IslandsModal = require(script.Parent.Parent.Components.IslandsModal)
local IndexGridSection = require(script.Parent.Parent.Components.IndexGridSection)
local ViewportPool = require(script.Parent.Parent.Components.ViewportPool)

local ProgressPanel = {}

local win: WindowFrame.BuiltWindow? = nil
local islandsWin: WindowFrame.BuiltWindow? = nil
local currentTab = "Rebirth"

local curStrength = 0
local curRebirths = 0
local indexFish: { [string]: number } = {}
local indexPets: { [string]: number } = {}
local claimedAch: { [string]: boolean } = {}
local dailyQuests: { [string]: any } = {}
local dailyStreak = 0
local canClaimDaily = true
local statsCache: { [string]: number } = {}
local fishBagCache: { any } = {}
local pinnedUidsCache: { [string]: string } = {}

local fishNameById: { [string]: string } = {}
for _, isl in ipairs(IslandsRegistry.List) do
	for _, f in ipairs(isl.fishPool) do
		fishNameById[f.id] = f.name
	end
end

local function clearBody(body: ScrollingFrame)
	for _, ch in ipairs(body:GetChildren()) do
		if ch:IsA("GuiObject") then
			ch:Destroy()
		end
	end
end

local function makeSimpleRow(body: ScrollingFrame, order: number, titleText: string, subText: string, col: Color3, bg: Color3, height: number?): Frame
	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, 0, 0, height or 58)
	card.BackgroundColor3 = bg
	card.LayoutOrder = order
	card.ZIndex = 22
	card.Parent = body
	Theme.AddCorner(card, 10)
	Theme.AddStroke(card, col, 2)

	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(0.68, 0, 0, 24)
	t.Position = UDim2.fromOffset(12, 5)
	t.BackgroundTransparency = 1
	t.Font = Theme.FontTitle
	t.TextSize = 15
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.TextColor3 = col
	t.Text = titleText
	t.ZIndex = 23
	t.Parent = card
	Theme.AddTextStroke(t, 1.4)

	local s = Instance.new("TextLabel")
	s.Size = UDim2.new(0.70, 0, 1, -32)
	s.Position = UDim2.fromOffset(12, 29)
	s.BackgroundTransparency = 1
	s.Font = Theme.FontBody
	s.TextSize = 12
	s.TextWrapped = true
	s.TextXAlignment = Enum.TextXAlignment.Left
	s.TextColor3 = Theme.Colors.TextMuted
	s.Text = subText
	s.ZIndex = 23
	s.Parent = card
	return card
end

local function buildRebirthTrophySummary(): (string, string)
	local lockedList: { any } = {}
	for _, entry in ipairs(fishBagCache) do
		if type(entry) == "table" and entry.locked == true then
			table.insert(lockedList, entry)
		end
	end
	table.sort(lockedList, function(a: any, b: any)
		local oa = tonumber(a.originalValue) or tonumber(a.sellValue) or 0
		local ob = tonumber(b.originalValue) or tonumber(b.sellValue) or 0
		return oa > ob
	end)

	local pinSlotByUid: { [string]: string } = {}
	for sKey, uid in pairs(pinnedUidsCache) do
		pinSlotByUid[uid] = sKey
	end

	local keptCount = math.min(#lockedList, GameConfig.MAX_SOULBOUND_TROPHIES)
	local clearedCount = math.max(0, #fishBagCache - keptCount)
	if keptCount == 0 then
		return string.format("🏆 Soulbound Trophies Kept: 0/%d  •  Fish Cleared: %d", GameConfig.MAX_SOULBOUND_TROPHIES, clearedCount),
			"Tip: Lock (🔒) up to 12 prized fish in your Bag before Rebirthing to keep them forever as Soulbound Trophies!"
	end

	local previewNames: { string } = {}
	for i = 1, keptCount do
		local item = lockedList[i]
		local nm = fishNameById[tostring(item.fishId)] or "Fish"
		local pinTag = if pinSlotByUid[tostring(item.uid)] then (" [Slot " .. pinSlotByUid[tostring(item.uid)] .. "]") else ""
		table.insert(previewNames, string.format("%s (%s)%s", nm, Util.FormatWeight(tonumber(item.weight) or 1), pinTag))
	end
	return string.format("🏆 %d/%d Locked Fish Kept as Soulbound Trophies  •  %d Other Fish Cleared", keptCount, GameConfig.MAX_SOULBOUND_TROPHIES, clearedCount),
		table.concat(previewNames, "  •  ")
end

function ProgressPanel.Render()
	local w = win
	if not w then
		return
	end
	clearBody(w.body)

	if currentTab == "Rebirth" then
		local reqStr = RebirthConfig.GetStrengthRequirement(curRebirths)
		local curMult = RebirthConfig.GetPermanentMultiplier(curRebirths)
		local nextMult = RebirthConfig.GetPermanentMultiplier(curRebirths + 1)
		local gemGain = RebirthConfig.GetGemReward(curRebirths)
		local ready = (curStrength >= reqStr)

		makeSimpleRow(
			w.body,
			1,
			string.format("✨ Current Rebirth Rank: %d (%.1fx Gold & Strength)", curRebirths, curMult),
			string.format("Next Rank: %.1fx Permanent Multiplier + %d Gems + 3 Potions! Keeps Exclusive Rods, Pets & Relics.", nextMult, gemGain),
			Theme.Colors.Gems,
			Theme.Colors.CardBg
		)

		local reqCard = makeSimpleRow(
			w.body,
			2,
			string.format("Strength Progress: %s / %s", Util.FormatNumber(curStrength), Util.FormatNumber(reqStr)),
			"Rebirth resets Gold, Strength & Normal Rods/Islands, while preserving Exclusive Rods & top 12 Locked Trophies!",
			if ready then Theme.Colors.Success else Theme.Colors.Strength,
			Theme.Colors.CardBg,
			66
		)
		local rebBtn = Theme.CreateButton(reqCard, "RebirthBtn", if ready then "✨ REBIRTH!" else "NEED STR", UDim2.fromOffset(138, 38), UDim2.new(1, -150, 0.5, -19), if ready then Theme.Colors.Success else Color3.fromRGB(88, 68, 82), function()
			Net.FireServer(Net.ClientToServer.DoRebirth)
		end)
		rebBtn.TextSize = 15
		rebBtn.ZIndex = 23

		local trophyTitle, trophyBody = buildRebirthTrophySummary()
		makeSimpleRow(w.body, 3, trophyTitle, trophyBody, Theme.Colors.Gold, Theme.Colors.CardOwned, 92)
	elseif currentTab == "Quests" then
		local nextStreak = if canClaimDaily then (dailyStreak + 1) else math.max(1, dailyStreak)
		local dailyGems = AchievementsConfig.GetDailyLoginGems(nextStreak)
		local loginCard = makeSimpleRow(w.body, 1, string.format("🎁 Daily Login Streak (Day %d)", nextStreak), string.format("Reward: +%d Gems + 1 Random Potion", dailyGems), Theme.Colors.Gold, if canClaimDaily then Theme.Colors.CardBg else Theme.Colors.CardOwned)
		local dBtn = Theme.CreateButton(loginCard, "ClaimDailyBtn", if canClaimDaily then "CLAIM GIFT" else "CLAIMED", UDim2.fromOffset(132, 36), UDim2.new(1, -144, 0.5, -18), if canClaimDaily then Theme.Colors.Success else Theme.Colors.Primary, function()
			if canClaimDaily then Net.FireServer(Net.ClientToServer.ClaimDailyReward) end
		end)
		dBtn.TextSize = 14
		dBtn.ZIndex = 23

		for idx, qDef in ipairs(AchievementsConfig.DailyQuests) do
			local st = dailyQuests[qDef.id] or { progress = 0, claimed = false }
			local prog = tonumber(st.progress) or 0
			local claimed = (st.claimed == true)
			local done = (prog >= qDef.target)
			local row = makeSimpleRow(w.body, idx + 1, string.format("📋 %s (%d / %d)", qDef.title, prog, qDef.target), string.format("Reward: +%d Gems + 1 Potion", qDef.gemReward), Theme.Colors.Primary, if claimed then Theme.Colors.CardOwned else Theme.Colors.CardBg)
			local qBtn = Theme.CreateButton(row, "ClaimQuestBtn", if claimed then "DONE" elseif done then "CLAIM" else "IN PROGRESS", UDim2.fromOffset(132, 36), UDim2.new(1, -144, 0.5, -18), if claimed then Theme.Colors.Primary elseif done then Theme.Colors.Success else Color3.fromRGB(72, 82, 108), function()
				if done and not claimed then Net.FireServer(Net.ClientToServer.ClaimQuest, qDef.id) end
			end)
			qBtn.TextSize = 13
			qBtn.ZIndex = 23
		end
	elseif currentTab == "Index" then
		IndexGridSection.Render(w.body, indexFish, indexPets)
	else
		for idx, ach in ipairs(AchievementsConfig.List) do
			local unlocked = claimedAch[ach.id] == true
			local curVal = if ach.statKey == "rebirths" then curRebirths else (tonumber(statsCache[ach.statKey]) or 0)
			makeSimpleRow(w.body, idx, string.format("🏆 %s %s", ach.title, if unlocked then "✅" else ""), string.format("Progress: %s / %s • Reward: +%d Gems", Util.FormatNumber(math.min(curVal, ach.target)), Util.FormatNumber(ach.target), ach.gemReward), if unlocked then Theme.Colors.Success else Theme.Colors.Warning, if unlocked then Theme.Colors.CardOwned else Theme.Colors.CardBg)
		end
	end
end

function ProgressPanel.Mount(rootGui: ScreenGui): WindowFrame.BuiltWindow
	local built = WindowFrame.Create(rootGui, "ProgressWindow", "🏆 PROGRESSION & INDEX", UDim2.fromOffset(630, 445), Color3.fromRGB(245, 134, 72))
	win = built
	local rebTab = built.AddTab("Rebirth", function() currentTab = "Rebirth"; ProgressPanel.Render() end)
	built.AddTab("Quests", function() currentTab = "Quests"; ProgressPanel.Render() end)
	built.AddTab("Index", function() currentTab = "Index"; ProgressPanel.Render() end)
	built.AddTab("Trophies", function() currentTab = "Achievements"; ProgressPanel.Render() end)
	built.OnVisibilityChanged(function(vis: boolean)
		if not vis then ViewportPool.ClearFocus() end
	end)
	built.SetActiveTab(rebTab)
	ProgressPanel.Render()
	return built
end

function ProgressPanel.GetIslandsWindow(rootGui: ScreenGui): WindowFrame.BuiltWindow
	local existing = islandsWin
	if existing then return existing end
	local created = IslandsModal.Mount(rootGui)
	islandsWin = created
	return created
end

function ProgressPanel.SyncBagAndHotbar(fishBag: { any }?, pinnedUids: { [string]: string }?)
	if fishBag then fishBagCache = fishBag end
	if pinnedUids then pinnedUidsCache = pinnedUids end
	if win and win.IsVisible() and currentTab == "Rebirth" then
		ProgressPanel.Render()
	end
end

function ProgressPanel.SyncFromProfile(p: any)
	if type(p) ~= "table" then return end
	curStrength = tonumber(p.strength) or curStrength
	curRebirths = tonumber(p.rebirths) or curRebirths
	indexFish = if type(p.indexFish) == "table" then p.indexFish else {}
	indexPets = if type(p.indexPets) == "table" then p.indexPets else {}
	claimedAch = if type(p.claimedAchievements) == "table" then p.claimedAchievements else {}
	dailyQuests = if type(p.dailyQuests) == "table" then p.dailyQuests else {}
	dailyStreak = tonumber(p.dailyStreak) or 0
	canClaimDaily = (tonumber(p.lastDailyClaimDay) or 0) < Util.GetUtcDayIndex()
	statsCache = if type(p.stats) == "table" then p.stats else {}
	fishBagCache = if type(p.fishBag) == "table" then p.fishBag else {}
	pinnedUidsCache = if type(p.pinnedFishUids) == "table" then p.pinnedFishUids else {}
	IslandsModal.Sync(tonumber(p.currentIsland) or 1, if type(p.unlockedIslands) == "table" then p.unlockedIslands else { ["1"] = true })
	if win and win.IsVisible() then ProgressPanel.Render() end
end

function ProgressPanel.SyncCurrencies(_gold: number, _gems: number, strength: number, rebirths: number)
	curStrength = strength
	curRebirths = rebirths
	if win and win.IsVisible() and currentTab == "Rebirth" then ProgressPanel.Render() end
end

function ProgressPanel.SyncPayload(payload: any)
	if type(payload) ~= "table" then return end
	curRebirths = tonumber(payload.rebirths) or curRebirths
	indexFish = if type(payload.indexFish) == "table" then payload.indexFish else indexFish
	indexPets = if type(payload.indexPets) == "table" then payload.indexPets else indexPets
	claimedAch = if type(payload.claimedAchievements) == "table" then payload.claimedAchievements else claimedAch
	dailyQuests = if type(payload.dailyQuests) == "table" then payload.dailyQuests else dailyQuests
	dailyStreak = tonumber(payload.dailyStreak) or dailyStreak
	if payload.canClaimDaily ~= nil then canClaimDaily = (payload.canClaimDaily == true) end
	statsCache = if type(payload.stats) == "table" then payload.stats else statsCache
	if win and win.IsVisible() then ProgressPanel.Render() end
end

function ProgressPanel.SyncIslands(islandId: number, unlocked: { [string]: boolean })
	IslandsModal.Sync(islandId, unlocked)
end

function ProgressPanel.RenderIslands()
	IslandsModal.Render()
end

return ProgressPanel
