--!strict
-- IndexGridSection.luau: So Suu Tap Fish & Pet O Luoi 3D (Persistent GridHandle + Virtualized ViewportPool, Zero Rebuild Spike!)

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

local CONTAINER_NAME = "PersistentIndexContainer"
local indexContainer: Frame? = nil
local headerTitleLbl: TextLabel? = nil
local gridHandle: ViewportPool.GridHandle? = nil
local focusedIndexKey: string? = nil
local lastIndexSignature = ""

function IndexGridSection.GetContainerName(): string
	return CONTAINER_NAME
end

local function ensureMounted(body: ScrollingFrame): (Frame, TextLabel, ViewportPool.GridHandle)
	if indexContainer and indexContainer.Parent == body and headerTitleLbl and gridHandle then
		return indexContainer, headerTitleLbl, gridHandle
	end

	local wrap = Instance.new("Frame")
	wrap.Name = CONTAINER_NAME
	wrap.Size = UDim2.new(1, 0, 0, 0)
	wrap.AutomaticSize = Enum.AutomaticSize.Y
	wrap.BackgroundTransparency = 1
	wrap.LayoutOrder = 1
	wrap.Visible = false
	wrap.ZIndex = 21
	wrap.Parent = body

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 8)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = wrap

	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0, 48)
	header.BackgroundColor3 = Theme.Colors.CardOwned
	header.LayoutOrder = 0
	header.ZIndex = 22
	header.Parent = wrap
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
	hTitle.ZIndex = 23
	hTitle.Parent = header
	Theme.AddTextStroke(hTitle, 1.4)

	local gh = ViewportPool.CreateGrid(wrap, 1, UDim2.fromOffset(132, 150))

	indexContainer = wrap
	headerTitleLbl = hTitle
	gridHandle = gh
	lastIndexSignature = ""
	return wrap, hTitle, gh
end

function IndexGridSection.SetVisible(body: ScrollingFrame, visible: boolean)
	local wrap = ensureMounted(body)
	wrap.Visible = visible
end

local function computeDataSignature(indexFish: { [string]: number }, indexPets: { [string]: number }): string
	local parts: { string } = {}
	for _, isl in ipairs(IslandsRegistry.List) do
		for _, f in ipairs(isl.fishPool) do
			local w = indexFish[f.id] or 0
			if w > 0 then
				table.insert(parts, string.format("f:%s:%.1f", f.id, w))
			end
		end
	end
	for _, egg in ipairs(PetsConfig.Eggs) do
		for _, p in ipairs(egg.pets) do
			local c = indexPets[p.id] or 0
			if c > 0 then
				table.insert(parts, string.format("p:%s:%d", p.id, c))
			end
		end
	end
	return table.concat(parts, "|")
end

function IndexGridSection.Render(body: ScrollingFrame, indexFish: { [string]: number }, indexPets: { [string]: number })
	local wrap, hTitle, gh = ensureMounted(body)
	wrap.Visible = true

	local sig = computeDataSignature(indexFish, indexPets)
	if sig == lastIndexSignature and lastIndexSignature ~= "__uninit__" and hTitle.Text ~= "" then
		return
	end
	lastIndexSignature = sig

	local foundFish, totalFish = 0, 0
	local foundPets, totalPets = 0, 0
	local specs: { ViewportCard.CardVisualSpec } = {}
	local order = 0

	for _, isl in ipairs(IslandsRegistry.List) do
		for _, f in ipairs(isl.fishPool) do
			totalFish += 1
			order += 1
			local bestW = indexFish[f.id] or 0
			local seen = bestW > 0
			if seen then foundFish += 1 end
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
			totalPets += 1
			order += 1
			local cnt = indexPets[p.id] or 0
			local seen = cnt > 0
			if seen then foundPets += 1 end
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

	hTitle.Text = string.format("📖 3D Index: %d/%d Fish • %d/%d Pets  (+%d Gems per new species!)", foundFish, totalFish, foundPets, totalPets, AchievementsConfig.INDEX_DISCOVERY_GEMS)
	gh.SyncItems(specs, focusedIndexKey)
end

return IndexGridSection
