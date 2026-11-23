--!strict
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Config = Shared:WaitForChild("Config")
local GameConfig = require(Config:WaitForChild("GameConfig"))
local AchievementsConfig = require(Config:WaitForChild("AchievementsConfig"))
local RebirthConfig = require(Config:WaitForChild("RebirthConfig"))
local RodsConfig = require(Config:WaitForChild("RodsConfig"))
local Islands = require(Config:WaitForChild("Islands"))

local NotificationBadge = {}
function NotificationBadge.Playtime(state: any): boolean
	if type(state) ~= "table" then return false end
	for _, gift in ipairs(GameConfig.PlaytimeGifts) do
		if (tonumber(state.playtimeTodaySec) or 0) >= gift.reqSec
			and not (state.playtimeClaimedToday or {})[tostring(gift.slot)] then return true end
	end
	return false
end

function NotificationBadge.Progress(state: any, today: number): boolean
	if type(state) ~= "table" then return false end
	if state.canClaimDaily == true or (state.canClaimDaily == nil and type(state.lastDailyClaimDay) == "number" and state.lastDailyClaimDay < today) then return true end
	if (tonumber(state.strength) or 0) >= RebirthConfig.GetStrengthRequirement(tonumber(state.rebirths) or 0) then return true end
	if state.questDay ~= nil and state.questDay ~= today then return false end
	for _, quest in ipairs(AchievementsConfig.DailyQuests) do
		local entry = (state.dailyQuests or {})[quest.id]
		if type(entry) == "table" and not entry.claimed and (tonumber(entry.progress) or 0) >= quest.target then return true end
	end
	return false
end

function NotificationBadge.Islands(state: any): boolean
	if type(state) ~= "table" or type(state.unlockedIslands) ~= "table" then return false end
	for _, island in ipairs(Islands.List) do
		if not state.unlockedIslands[tostring(island.id)] then
			return (island.id == 1 or state.unlockedIslands[tostring(island.id - 1)] == true)
				and (tonumber(state.gold) or 0) >= island.unlockCostGold
		end
	end
	return false
end

function NotificationBadge.Shop(state: any): boolean
	if type(state) ~= "table" or type(state.ownedRods) ~= "table" then return false end
	local nextRod = nil
	for _, rod in ipairs(RodsConfig.NormalList) do
		if not state.ownedRods[rod.id] and (not nextRod or rod.order < nextRod.order) then nextRod = rod end
	end
	return nextRod ~= nil and (tonumber(state.gold) or 0) >= nextRod.priceGold
		and (tonumber(state.strength) or 0) >= nextRod.strengthReq
end

function NotificationBadge.Attach(button: GuiObject): Frame
	local dot = Instance.new("Frame")
	dot.Name = "NotificationBadge"
	dot.AnchorPoint = Vector2.new(1, 0)
	dot.Position = UDim2.new(1, -3, 0, 3)
	dot.Size = UDim2.fromOffset(10, 10)
	dot.BackgroundColor3 = Color3.fromRGB(244, 62, 76)
	dot.BorderSizePixel = 0
	dot.ZIndex = button.ZIndex + 2
	dot.Visible = false
	dot.Parent = button
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = dot
	return dot
end

function NotificationBadge.Update(dot: GuiObject, key: string, state: any, today: number)
	local predicates: { [string]: (any) -> boolean } = {
		Gifts = NotificationBadge.Playtime, Shop = NotificationBadge.Shop, Islands = NotificationBadge.Islands,
		Progress = function(s) return NotificationBadge.Progress(s, today) end,
	}
	local predicate = predicates[key]
	dot.Visible = predicate ~= nil and predicate(state)
end

local state: any = {}
local dots: { [string]: Frame } = {}
local offset = 0
local initialized = false
local function refresh()
	for key, dot in pairs(dots) do NotificationBadge.Update(dot, key, state, math.floor((os.time() + offset) / 86400)) end
end
function NotificationBadge.AttachToHud(button: GuiObject, key: string)
	if key ~= "Gifts" and key ~= "Progress" and key ~= "Islands" and key ~= "Shop" then return end
	dots[key] = NotificationBadge.Attach(button)
	refresh()
end
function NotificationBadge.Init()
	if initialized then return end
	initialized = true
	local function merge(payload: any)
		if type(payload) ~= "table" then return end
		for key, value in pairs(payload) do state[key] = value end
		if type(payload.serverNow) == "number" then offset = payload.serverNow - os.time() end
		refresh()
	end
	Net.OnClientEvent(Net.ServerToClient.StateSnapshot, function(snapshot: any)
		if type(snapshot) ~= "table" or type(snapshot.profile) ~= "table" then return end
		state = {}
		if type(snapshot.serverNow) == "number" then offset = snapshot.serverNow - os.time() end
		merge(snapshot.profile)
	end)
	for _, event in ipairs({ "CurrencyUpdated", "InventoryUpdated", "PlaytimeUpdated", "IslandChanged", "ProgressionUpdated" }) do
		Net.OnClientEvent((Net.ServerToClient :: any)[event], function(payload: any)
			if event == "ProgressionUpdated" then state.questDay = math.floor((os.time() + offset) / 86400) end
			merge(payload)
		end)
	end
end
return NotificationBadge
