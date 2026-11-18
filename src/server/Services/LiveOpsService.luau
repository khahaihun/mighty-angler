--!strict
-- LiveOpsService.luau: Su kien toan Server 30 phut + 2 Bang Xep Hang Top Strength & Top Gold tai Dao 1

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))
local EventsConfig = require(Shared:WaitForChild("Config"):WaitForChild("EventsConfig"))
local IslandsRegistry = require(Shared:WaitForChild("Config"):WaitForChild("Islands"))

local DataService = require(script.Parent.DataService)
local BuffAggregator = require(script.Parent.BuffAggregator)
local ShopAndItemsService = require(script.Parent.ShopAndItemsService)
local PartFactory = require(script.Parent.Parent.World.PartFactory)

local LiveOpsService = {}

local activeEvent: EventsConfig.ServerEventDef? = nil
local eventEndsAt = 0
local nextEventStartsAt = os.time() + EventsConfig.CYCLE_INTERVAL_SEC
local lastEventId = ""

local strengthLeaderList: Frame? = nil
local goldLeaderList: Frame? = nil

local function buildEventBannerText(now: number): string
	if activeEvent and eventEndsAt > now then
		local rem = math.max(0, eventEndsAt - now)
		return string.format("%s: %s (%s)", activeEvent.name, activeEvent.description, Util.FormatDuration(rem))
	end
	local waitRem = math.max(0, nextEventStartsAt - now)
	return string.format("⏳ Next Server Event in %s", Util.FormatDuration(waitRem))
end

local function broadcastEventBanner()
	local txt = buildEventBannerText(os.time())
	Net.FireAllClients(Net.ServerToClient.ServerEventChanged, {
		bannerText = txt,
		activeId = if activeEvent then activeEvent.id else nil,
	})
end

function LiveOpsService.TriggerNewServerEvent()
	local candidates: { EventsConfig.ServerEventDef } = {}
	for _, ev in ipairs(EventsConfig.List) do
		if ev.id ~= lastEventId then
			table.insert(candidates, ev)
		end
	end
	local picked = candidates[math.random(1, #candidates)]
	activeEvent = picked
	lastEventId = picked.id
	eventEndsAt = os.time() + EventsConfig.ACTIVE_DURATION_SEC
	nextEventStartsAt = eventEndsAt + EventsConfig.CYCLE_INTERVAL_SEC

	for _, player in ipairs(Players:GetPlayers()) do
		local p = DataService.Get(player)
		if p then
			p.stats.eventsJoined += 1
			DataService.MarkDirty(player)
		end
		ShopAndItemsService.GrantPotion(player, picked.giftPotionId, 1, false)
	end

	Net.FireAllClients(Net.ServerToClient.Toast, {
		kind = "Epic",
		text = string.format("%s STARTED! %s (+1 Free Potion!)", picked.name, picked.description),
	})
	broadcastEventBanner()
end

local function createLeaderboardBoard(parent: Instance, pos: Vector3, titleText: string, accent: Color3): Frame
	local board = PartFactory.Block(
		parent,
		"Leaderboard_" .. titleText,
		Vector3.new(11, 10, 0.9),
		CFrame.new(pos + Vector3.new(0, 6.2, 0)),
		Color3.fromRGB(28, 36, 56)
	)
	PartFactory.Block(parent, "PostL", Vector3.new(0.8, 6.5, 0.8), CFrame.new(pos + Vector3.new(-4.6, 3.2, 0)), Color3.fromRGB(64, 76, 104))
	PartFactory.Block(parent, "PostR", Vector3.new(0.8, 6.5, 0.8), CFrame.new(pos + Vector3.new(4.6, 3.2, 0)), Color3.fromRGB(64, 76, 104))

	local sGui = Instance.new("SurfaceGui")
	sGui.Face = Enum.NormalId.Back
	sGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sGui.PixelsPerStud = 38
	sGui.Parent = board

	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(22, 28, 46)
	bg.BorderSizePixel = 0
	bg.Parent = sGui

	local header = Instance.new("TextLabel")
	header.Size = UDim2.new(1, 0, 0, 52)
	header.BackgroundColor3 = accent
	header.BorderSizePixel = 0
	header.Font = Enum.Font.FredokaOne
	header.TextSize = 26
	header.TextColor3 = Color3.fromRGB(20, 24, 36)
	header.Text = titleText
	header.Parent = bg

	local listFrame = Instance.new("Frame")
	listFrame.Size = UDim2.new(1, -24, 1, -66)
	listFrame.Position = UDim2.fromOffset(12, 58)
	listFrame.BackgroundTransparency = 1
	listFrame.Parent = bg

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = listFrame

	return listFrame
end

local function renderRows(listFrame: Frame?, entries: { { name: string, score: number } }, color: Color3)
	if not listFrame then
		return
	end
	for _, ch in ipairs(listFrame:GetChildren()) do
		if ch:IsA("GuiObject") then
			ch:Destroy()
		end
	end
	for idx = 1, math.min(8, #entries) do
		local item = entries[idx]
		local row = Instance.new("TextLabel")
		row.Size = UDim2.new(1, 0, 0, 34)
		row.BackgroundColor3 = Color3.fromRGB(34, 44, 72)
		row.BorderSizePixel = 0
		row.Font = Enum.Font.GothamBold
		row.TextSize = 20
		row.TextColor3 = if idx == 1 then color else Color3.fromRGB(240, 246, 255)
		row.Text = string.format(" #%d  %s — %s", idx, item.name, Util.FormatNumber(item.score))
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.LayoutOrder = idx
		row.Parent = listFrame
	end
end

local function refreshLeaderboards()
	local strEntries: { { name: string, score: number } } = {}
	local goldEntries: { { name: string, score: number } } = {}

	for _, p in ipairs(Players:GetPlayers()) do
		local prof = DataService.Get(p)
		if prof then
			table.insert(strEntries, { name = p.DisplayName, score = prof.strength })
			table.insert(goldEntries, { name = p.DisplayName, score = prof.stats.goldEarned })
		end
	end

	-- Co gang cap nhat OrderedDataStore neu Place da publish (PlaceId > 0)
	if game.PlaceId > 0 then
		pcall(function()
			local strStore = DataStoreService:GetOrderedDataStore("MightyAngler_TopStr_v2")
			local goldStore = DataStoreService:GetOrderedDataStore("MightyAngler_TopGold_v2")
			for _, p in ipairs(Players:GetPlayers()) do
				local prof = DataService.Get(p)
				if prof then
					strStore:SetAsync(tostring(p.UserId), math.floor(prof.strength))
					goldStore:SetAsync(tostring(p.UserId), math.floor(prof.stats.goldEarned))
				end
			end
		end)
	end

	table.sort(strEntries, function(a, b)
		return a.score > b.score
	end)
	table.sort(goldEntries, function(a, b)
		return a.score > b.score
	end)

	renderRows(strengthLeaderList, strEntries, Color3.fromRGB(255, 128, 92))
	renderRows(goldLeaderList, goldEntries, Color3.fromRGB(255, 212, 68))
end

function LiveOpsService.Init()
	-- Dung 2 bang Leaderboard tren quang truong Dao 1
	local world = Workspace:FindFirstChild("MightyWorld")
	local isl1 = if world then world:FindFirstChild("Island_1") else nil
	if isl1 then
		local c = IslandsRegistry.Get(1).centerPosition
		strengthLeaderList = createLeaderboardBoard(isl1, c + Vector3.new(-24, 0, -28), "💪 TOP STRENGTH", Color3.fromRGB(255, 126, 86))
		goldLeaderList = createLeaderboardBoard(isl1, c + Vector3.new(24, 0, -28), "🪙 TOP GOLD EARNED", Color3.fromRGB(255, 212, 68))
	end

	BuffAggregator.RegisterProvider(function(_player: Player, _profile: Types.PlayerProfile)
		local now = os.time()
		if not activeEvent or eventEndsAt <= now then
			return {}
		end
		return {
			luckAdd = activeEvent.luckAdd,
			mutationAdd = activeEvent.mutationAdd,
			strengthAdd = activeEvent.strengthAdd,
			sellAdd = activeEvent.sellAdd,
			biteSpeedAdd = activeEvent.biteSpeedAdd,
		}
	end)

	Net.OnServerEvent(Net.ClientToServer.RequestInitialState, function(player: Player)
		Net.FireClient(player, Net.ServerToClient.ServerEventChanged, {
			bannerText = buildEventBannerText(os.time()),
			activeId = if activeEvent then activeEvent.id else nil,
		})
	end)

	-- Vong lap dem nguoc Event & cap nhat Leaderboard dinh ky
	task.spawn(function()
		local lbTick = 0
		refreshLeaderboards()
		while true do
			task.wait(5)
			local now = os.time()
			if activeEvent and now >= eventEndsAt then
				local endedName = activeEvent.name
				activeEvent = nil
				Net.FireAllClients(Net.ServerToClient.Toast, {
					kind = "Info",
					text = endedName .. " has ended!",
				})
			elseif not activeEvent and now >= nextEventStartsAt then
				LiveOpsService.TriggerNewServerEvent()
			end
			broadcastEventBanner()

			lbTick += 5
			if lbTick >= 20 then
				lbTick = 0
				refreshLeaderboards()
			end
		end
	end)
end

return LiveOpsService
