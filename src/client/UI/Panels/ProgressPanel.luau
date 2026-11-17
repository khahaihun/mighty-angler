--!strict
-- ProgressPanel.luau: Giao dien 4 tab (Rebirth, Quests & Daily, Collection Index, Achievements)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))
local RebirthConfig = require(Shared:WaitForChild("Config"):WaitForChild("RebirthConfig"))
local AchievementsConfig = require(Shared:WaitForChild("Config"):WaitForChild("AchievementsConfig"))
local IslandsRegistry = require(Shared:WaitForChild("Config"):WaitForChild("Islands"))
local PetsConfig = require(Shared:WaitForChild("Config"):WaitForChild("PetsConfig"))

local Theme = require(script.Parent.Parent.Theme)
local WindowFrame = require(script.Parent.Parent.Components.WindowFrame)
local IslandsModal = require(script.Parent.Parent.Components.IslandsModal)

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

local function clearBody(body: ScrollingFrame)
	for _, ch in ipairs(body:GetChildren()) do
		if ch:IsA("GuiObject") then
			ch:Destroy()
		end
	end
end

local function makeSimpleRow(body: ScrollingFrame, order: number, titleText: string, subText: string, col: Color3, bg: Color3): Frame
	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, 0, 0, 58)
	card.BackgroundColor3 = bg
	card.LayoutOrder = order
	card.ZIndex = 22
	card.Parent = body
	Theme.AddCorner(card, 10)
	Theme.AddStroke(card, col, 2)

	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(0.66, 0, 0, 26)
	t.Position = UDim2.fromOffset(12, 5)
	t.BackgroundTransparency = 1
	t.Font = Theme.FontTitle
	t.TextSize = 16
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.TextColor3 = col
	t.Text = titleText
	t.ZIndex = 23
	t.Parent = card
	Theme.AddTextStroke(t, 1.5)

	local s = Instance.new("TextLabel")
	s.Size = UDim2.new(0.66, 0, 0, 20)
	s.Position = UDim2.fromOffset(12, 31)
	s.BackgroundTransparency = 1
	s.Font = Theme.FontBody
	s.TextSize = 13
	s.TextXAlignment = Enum.TextXAlignment.Left
	s.TextColor3 = Theme.Colors.TextMuted
	s.Text = subText
	s.ZIndex = 23
	s.Parent = card

	return card
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
			string.format("Next Rank: %.1fx Permanent Multiplier + %d Gems + 3 Potions!", nextMult, gemGain),
			Theme.Colors.Gems,
			Theme.Colors.CardBg
		)

		local reqCard = makeSimpleRow(
			w.body,
			2,
			string.format("Strength Progress: %s / %s", Util.FormatNumber(curStrength), Util.FormatNumber(reqStr)),
			"Keeps Gems, Pets, Potions, Index & Achievements! Resets Gold, Strength & Islands.",
			if ready then Theme.Colors.Success else Theme.Colors.Strength,
			Theme.Colors.CardBg
		)

		local rebBtn = Theme.CreateButton(
			reqCard,
			"RebirthBtn",
			if ready then "✨ REBIRTH!" else "NEED STR",
			UDim2.fromOffset(138, 38),
			UDim2.new(1, -150, 0.5, -19),
			if ready then Theme.Colors.Success else Color3.fromRGB(88, 68, 82),
			function()
				Net.FireServer(Net.ClientToServer.DoRebirth)
			end
		)
		rebBtn.TextSize = 15
		rebBtn.ZIndex = 23
	elseif currentTab == "Quests" then
		local nextStreak = if canClaimDaily then (dailyStreak + 1) else math.max(1, dailyStreak)
		local dailyGems = AchievementsConfig.GetDailyLoginGems(nextStreak)
		local loginCard = makeSimpleRow(
			w.body,
			1,
			string.format("🎁 Daily Login Streak (Day %d)", nextStreak),
			string.format("Reward: +%d Gems + 1 Random Potion", dailyGems),
			Theme.Colors.Gold,
			if canClaimDaily then Theme.Colors.CardBg else Theme.Colors.CardOwned
		)
		local dBtn = Theme.CreateButton(
			loginCard,
			"ClaimDailyBtn",
			if canClaimDaily then "CLAIM GIFT" else "CLAIMED",
			UDim2.fromOffset(132, 36),
			UDim2.new(1, -144, 0.5, -18),
			if canClaimDaily then Theme.Colors.Success else Theme.Colors.Primary,
			function()
				if canClaimDaily then
					Net.FireServer(Net.ClientToServer.ClaimDailyReward)
				end
			end
		)
		dBtn.TextSize = 14
		dBtn.ZIndex = 23

		for idx, qDef in ipairs(AchievementsConfig.DailyQuests) do
			local st = dailyQuests[qDef.id] or { progress = 0, claimed = false }
			local prog = tonumber(st.progress) or 0
			local claimed = (st.claimed == true)
			local done = (prog >= qDef.target)
			local row = makeSimpleRow(
				w.body,
				idx + 1,
				string.format("📋 %s (%d / %d)", qDef.title, prog, qDef.target),
				string.format("Reward: +%d Gems + 1 Potion", qDef.gemReward),
				Theme.Colors.Primary,
				if claimed then Theme.Colors.CardOwned else Theme.Colors.CardBg
			)
			local qBtn = Theme.CreateButton(
				row,
				"ClaimQuestBtn",
				if claimed then "DONE" elseif done then "CLAIM" else "IN PROGRESS",
				UDim2.fromOffset(132, 36),
				UDim2.new(1, -144, 0.5, -18),
				if claimed then Theme.Colors.Primary elseif done then Theme.Colors.Success else Color3.fromRGB(72, 82, 108),
				function()
					if done and not claimed then
						Net.FireServer(Net.ClientToServer.ClaimQuest, qDef.id)
					end
				end
			)
			qBtn.TextSize = 13
			qBtn.ZIndex = 23
		end
	elseif currentTab == "Index" then
		local foundFish = 0
		local totalFish = 0
		for _, isl in ipairs(IslandsRegistry.List) do
			for _, f in ipairs(isl.fishPool) do
				totalFish += 1
				if (indexFish[f.id] or 0) > 0 then
					foundFish += 1
				end
			end
		end
		local foundPets = 0
		local totalPets = 0
		for _, egg in ipairs(PetsConfig.Eggs) do
			for _, p in ipairs(egg.pets) do
				totalPets += 1
				if (indexPets[p.id] or 0) > 0 then
					foundPets += 1
				end
			end
		end

		makeSimpleRow(
			w.body,
			0,
			string.format("📖 Collection: %d/%d Fish • %d/%d Pets", foundFish, totalFish, foundPets, totalPets),
			string.format("First discovery of EVERY species grants +%d Gems automatically!", AchievementsConfig.INDEX_DISCOVERY_GEMS),
			Theme.Colors.Gold,
			Theme.Colors.CardOwned
		)

		local order = 1
		for _, isl in ipairs(IslandsRegistry.List) do
			for _, f in ipairs(isl.fishPool) do
				order += 1
				local bestW = indexFish[f.id] or 0
				local seen = bestW > 0
				local rCol = if seen then (Theme.RarityColors[f.rarity] or Theme.Colors.TextPrimary) else Theme.Colors.TextMuted
				makeSimpleRow(
					w.body,
					order,
					if seen then string.format("🐟 [%s] %s (%s)", isl.name, f.name, f.rarity) else string.format("❓ [%s] ??? (%s)", isl.name, f.rarity),
					if seen then ("Discovered ✅ • Best Weight: " .. Util.FormatWeight(bestW)) else "Catch this fish to unlock +15 Gems!",
					rCol,
					Theme.Colors.CardBg
				)
			end
		end
	else
		for idx, ach in ipairs(AchievementsConfig.List) do
			local unlocked = claimedAch[ach.id] == true
			local curVal = if ach.statKey == "rebirths" then curRebirths else (tonumber(statsCache[ach.statKey]) or 0)
			makeSimpleRow(
				w.body,
				idx,
				string.format("🏆 %s %s", ach.title, if unlocked then "✅" else ""),
				string.format("Progress: %s / %s • Reward: +%d Gems", Util.FormatNumber(math.min(curVal, ach.target)), Util.FormatNumber(ach.target), ach.gemReward),
				if unlocked then Theme.Colors.Success else Theme.Colors.Warning,
				if unlocked then Theme.Colors.CardOwned else Theme.Colors.CardBg
			)
		end
	end
end

function ProgressPanel.Mount(rootGui: ScreenGui): WindowFrame.BuiltWindow
	local built = WindowFrame.Create(rootGui, "ProgressWindow", "🏆 PROGRESSION & INDEX", UDim2.fromOffset(620, 440), Color3.fromRGB(245, 134, 72))
	win = built

	local rebTab = built.AddTab("Rebirth", function()
		currentTab = "Rebirth"
		ProgressPanel.Render()
	end)
	built.AddTab("Quests", function()
		currentTab = "Quests"
		ProgressPanel.Render()
	end)
	built.AddTab("Index", function()
		currentTab = "Index"
		ProgressPanel.Render()
	end)
	built.AddTab("Trophies", function()
		currentTab = "Achievements"
		ProgressPanel.Render()
	end)
	built.SetActiveTab(rebTab)
	ProgressPanel.Render()
	return built
end

function ProgressPanel.GetIslandsWindow(rootGui: ScreenGui): WindowFrame.BuiltWindow
	local existing = islandsWin
	if existing then
		return existing
	end
	local created = IslandsModal.Mount(rootGui)
	islandsWin = created
	return created
end

function ProgressPanel.SyncFromProfile(p: any)
	if type(p) ~= "table" then
		return
	end
	curStrength = tonumber(p.strength) or curStrength
	curRebirths = tonumber(p.rebirths) or curRebirths
	indexFish = if type(p.indexFish) == "table" then p.indexFish else {}
	indexPets = if type(p.indexPets) == "table" then p.indexPets else {}
	claimedAch = if type(p.claimedAchievements) == "table" then p.claimedAchievements else {}
	dailyQuests = if type(p.dailyQuests) == "table" then p.dailyQuests else {}
	dailyStreak = tonumber(p.dailyStreak) or 0
	canClaimDaily = (tonumber(p.lastDailyClaimDay) or 0) < Util.GetUtcDayIndex()
	statsCache = if type(p.stats) == "table" then p.stats else {}
	IslandsModal.Sync(tonumber(p.currentIsland) or 1, if type(p.unlockedIslands) == "table" then p.unlockedIslands else { ["1"] = true })
	if win and win.IsVisible() then
		ProgressPanel.Render()
	end
end

function ProgressPanel.SyncCurrencies(_gold: number, _gems: number, strength: number, rebirths: number)
	curStrength = strength
	curRebirths = rebirths
	if win and win.IsVisible() and currentTab == "Rebirth" then
		ProgressPanel.Render()
	end
end

function ProgressPanel.SyncPayload(payload: any)
	if type(payload) ~= "table" then
		return
	end
	curRebirths = tonumber(payload.rebirths) or curRebirths
	indexFish = if type(payload.indexFish) == "table" then payload.indexFish else indexFish
	indexPets = if type(payload.indexPets) == "table" then payload.indexPets else indexPets
	claimedAch = if type(payload.claimedAchievements) == "table" then payload.claimedAchievements else claimedAch
	dailyQuests = if type(payload.dailyQuests) == "table" then payload.dailyQuests else dailyQuests
	dailyStreak = tonumber(payload.dailyStreak) or dailyStreak
	if payload.canClaimDaily ~= nil then
		canClaimDaily = (payload.canClaimDaily == true)
	end
	statsCache = if type(payload.stats) == "table" then payload.stats else statsCache
	if win and win.IsVisible() then
		ProgressPanel.Render()
	end
end

function ProgressPanel.SyncIslands(islandId: number, unlocked: { [string]: boolean })
	IslandsModal.Sync(islandId, unlocked)
end

function ProgressPanel.RenderIslands()
	IslandsModal.Render()
end

return ProgressPanel
