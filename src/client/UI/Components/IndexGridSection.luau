--!strict
-- IndexGridSection.luau: So Suu Tap Fish & Pet O Luoi 3D (ViewportPool + Silhouette bong den cho loai chua mo)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Util = require(Shared:WaitForChild("Util"))
local AchievementsConfig = require(Shared:WaitForChild("Config"):WaitForChild("AchievementsConfig"))
local IslandsRegistry = require(Shared:WaitForChild("Config"):WaitForChild("Islands"))
local PetsConfig = require(Shared:WaitForChild("Config"):WaitForChild("PetsConfig"))

local Theme = require(script.Parent.Parent.Theme)
local ViewportCard = require(script.Parent.ViewportCard)
local ViewportPool = require(script.Parent.ViewportPool)

local IndexGridSection = {}

local focusedIndexKey: string? = nil

function IndexGridSection.Render(body: ScrollingFrame, indexFish: { [string]: number }, indexPets: { [string]: number })
	local foundFish, totalFish = 0, 0
	for _, isl in ipairs(IslandsRegistry.List) do
		for _, f in ipairs(isl.fishPool) do
			totalFish += 1
			if (indexFish[f.id] or 0) > 0 then foundFish += 1 end
		end
	end

	local foundPets, totalPets = 0, 0
	for _, egg in ipairs(PetsConfig.Eggs) do
		for _, p in ipairs(egg.pets) do
			totalPets += 1
			if (indexPets[p.id] or 0) > 0 then foundPets += 1 end
		end
	end

	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0, 48)
	header.BackgroundColor3 = Theme.Colors.CardOwned
	header.LayoutOrder = 0
	header.ZIndex = 22
	header.Parent = body
	Theme.AddCorner(header, 10)
	Theme.AddStroke(header, Theme.Colors.Gold, 2)

	local hTitle = Instance.new("TextLabel")
	hTitle.Size = UDim2.new(1, -20, 1, 0)
	hTitle.Position = UDim2.fromOffset(10, 0)
	hTitle.BackgroundTransparency = 1
	hTitle.Font = Theme.FontTitle
	hTitle.TextSize = 15
	hTitle.TextXAlignment = Enum.TextXAlignment.Left
	hTitle.TextColor3 = Theme.Colors.Gold
	hTitle.Text = string.format("📖 3D Index: %d/%d Fish • %d/%d Pets  (+%d Gems per new species!)", foundFish, totalFish, foundPets, totalPets, AchievementsConfig.INDEX_DISCOVERY_GEMS)
	hTitle.ZIndex = 23
	hTitle.Parent = header
	Theme.AddTextStroke(hTitle, 1.4)

	local gh = ViewportPool.CreateGrid(body, 1, UDim2.fromOffset(132, 150))
	local specs: { ViewportCard.CardVisualSpec } = {}
	local order = 0

	for _, isl in ipairs(IslandsRegistry.List) do
		for _, f in ipairs(isl.fishPool) do
			order += 1
			local bestW = indexFish[f.id] or 0
			local seen = bestW > 0
			local rCol = if seen then (Theme.RarityColors[f.rarity] or Theme.Colors.TextPrimary) else Theme.Colors.TextMuted
			local key = "idxfish_" .. f.id
			table.insert(specs, {
				key = key,
				order = order,
				title = if seen then f.name else "???",
				subtitle = string.format("Isl.%d • %s", isl.id, f.rarity),
				footerText = if seen then ("Best: " .. Util.FormatWeight(bestW)) else "+15 Gems",
				footerColor = if seen then Theme.Colors.Success else Color3.fromRGB(54, 62, 86),
				strokeColor = rCol,
				bgColor = if seen then Theme.Colors.CardBg else Color3.fromRGB(16, 20, 32),
				topLeftBadge = if seen then "✅" else "❓",
				topLeftColor = rCol,
				modelSignature = string.format("IdxFish_%s_%s", f.id, tostring(seen)),
				modelSpec = { kind = "Fish", primaryColor = f.primaryColor, secondaryColor = f.secondaryColor, silhouette = not seen, modelRefData = f },
				onActivate = function()
					focusedIndexKey = key
					gh.SetFocusedKey(key)
				end,
			})
		end
	end

	for _, egg in ipairs(PetsConfig.Eggs) do
		for _, p in ipairs(egg.pets) do
			order += 1
			local cnt = indexPets[p.id] or 0
			local seen = cnt > 0
			local rCol = if seen then (Theme.RarityColors[p.rarity] or Theme.Colors.TextPrimary) else Theme.Colors.TextMuted
			local key = "idxpet_" .. p.id
			table.insert(specs, {
				key = key,
				order = order,
				title = if seen then p.name else "???",
				subtitle = string.format("Pet • %s", p.rarity),
				footerText = if seen then ("Hatched: " .. tostring(cnt)) else "+15 Gems",
				footerColor = if seen then Theme.Colors.Primary else Color3.fromRGB(54, 62, 86),
				strokeColor = rCol,
				bgColor = if seen then Theme.Colors.CardBg else Color3.fromRGB(16, 20, 32),
				topLeftBadge = if seen then "🐾" else "❓",
				topLeftColor = rCol,
				modelSignature = string.format("IdxPet_%s_%s", p.id, tostring(seen)),
				modelSpec = { kind = "Pet", primaryColor = p.primaryColor, secondaryColor = p.secondaryColor, silhouette = not seen, modelRefData = p },
				onActivate = function()
					focusedIndexKey = key
					gh.SetFocusedKey(key)
				end,
			})
		end
	end

	gh.SyncItems(specs, focusedIndexKey)
end

return IndexGridSection
