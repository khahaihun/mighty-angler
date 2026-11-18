--!strict
-- IndexGridSection.luau: Bo suu tap Fish & Pet Index tach rieng giu ProgressPanel gon nhe (< 300 dong)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Util = require(Shared:WaitForChild("Util"))
local AchievementsConfig = require(Shared:WaitForChild("Config"):WaitForChild("AchievementsConfig"))
local IslandsRegistry = require(Shared:WaitForChild("Config"):WaitForChild("Islands"))
local PetsConfig = require(Shared:WaitForChild("Config"):WaitForChild("PetsConfig"))

local Theme = require(script.Parent.Parent.Theme)

local IndexGridSection = {}

local function makeRow(body: ScrollingFrame, order: number, titleText: string, subText: string, col: Color3, bg: Color3)
	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, 0, 0, 56)
	card.BackgroundColor3 = bg
	card.LayoutOrder = order
	card.ZIndex = 22
	card.Parent = body
	Theme.AddCorner(card, 10)
	Theme.AddStroke(card, col, 2)

	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(1, -24, 0, 24)
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
	s.Size = UDim2.new(1, -24, 0, 20)
	s.Position = UDim2.fromOffset(12, 30)
	s.BackgroundTransparency = 1
	s.Font = Theme.FontBody
	s.TextSize = 12
	s.TextXAlignment = Enum.TextXAlignment.Left
	s.TextColor3 = Theme.Colors.TextMuted
	s.Text = subText
	s.ZIndex = 23
	s.Parent = card
end

function IndexGridSection.Render(body: ScrollingFrame, indexFish: { [string]: number }, indexPets: { [string]: number })
	local foundFish, totalFish = 0, 0
	for _, isl in ipairs(IslandsRegistry.List) do
		for _, f in ipairs(isl.fishPool) do
			totalFish += 1
			if (indexFish[f.id] or 0) > 0 then
				foundFish += 1
			end
		end
	end

	local foundPets, totalPets = 0, 0
	for _, egg in ipairs(PetsConfig.Eggs) do
		for _, p in ipairs(egg.pets) do
			totalPets += 1
			if (indexPets[p.id] or 0) > 0 then
				foundPets += 1
			end
		end
	end

	makeRow(
		body,
		0,
		string.format("📖 Collection: %d/%d Fish  •  %d/%d Pets", foundFish, totalFish, foundPets, totalPets),
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
			makeRow(
				body,
				order,
				if seen then string.format("🐟 [%s] %s (%s)", isl.name, f.name, f.rarity) else string.format("❓ [%s] ??? (%s)", isl.name, f.rarity),
				if seen then ("Discovered ✅ • Record Weight: " .. Util.FormatWeight(bestW)) else string.format("Requires Power %d • %s–%s", f.minRodPower, Util.FormatWeight(f.minWeight), Util.FormatWeight(f.maxWeight)),
				rCol,
				Theme.Colors.CardBg
			)
		end
	end
end

return IndexGridSection
