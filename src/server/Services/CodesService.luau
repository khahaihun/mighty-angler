--!strict
-- CodesService.luau: Nhap Ma Qua Tang (Redeem Code) — chuan hoa, gioi han toc do, kiem han UTC, trao thuong nguyen tu 1 lan.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local CodesConfig = require(Shared:WaitForChild("Config"):WaitForChild("CodesConfig"))
local PotionsConfig = require(Shared:WaitForChild("Config"):WaitForChild("PotionsConfig"))

local DataService = require(script.Parent.DataService)
local CurrencyService = require(script.Parent.CurrencyService)
local ShopAndItemsService = require(script.Parent.ShopAndItemsService)
local AnalyticsHelper = require(script.Parent.AnalyticsHelper)

local CodesService = {}

export type RedeemStatus = "Redeemed" | "Invalid" | "Expired" | "AlreadyRedeemed" | "RateLimited" | "ReadOnly"

local MESSAGES: { [string]: string } = {
	Invalid = "That code doesn't exist. Check the spelling and try again!",
	Expired = "That code has expired. Watch our socials for new ones!",
	AlreadyRedeemed = "You've already redeemed this code!",
	RateLimited = "Slow down! Please wait a moment before trying another code.",
	ReadOnly = "Your save is still loading or protected. Try the code again in a moment!",
}

local attempts: { [Player]: { windowStart: number, count: number, lastAt: number } } = {}

local function allowAttempt(player: Player): boolean
	local now = os.clock()
	local bucket = attempts[player]
	if not bucket or now - bucket.windowStart >= GameConfig.CODE_REDEEM_WINDOW_SEC then
		attempts[player] = { windowStart = now, count = 1, lastAt = now }
		return true
	end
	if now - bucket.lastAt < GameConfig.CODE_REDEEM_MIN_GAP_SEC or bucket.count >= GameConfig.CODE_REDEEM_MAX_PER_WINDOW then
		return false
	end
	bucket.count += 1
	bucket.lastAt = now
	return true
end

function CodesService.Redeem(player: Player, rawCode: any): (RedeemStatus, string, string?)
	if not allowAttempt(player) then
		return "RateLimited", MESSAGES.RateLimited, nil
	end
	local code = CodesConfig.Normalize(rawCode)
	local def = if code then CodesConfig.ByCode[code] else nil
	if not code or not def then
		return "Invalid", MESSAGES.Invalid, code
	end
	local profile = DataService.Get(player)
	if not profile or not DataService.CanWritePersistent(player) then
		return "ReadOnly", MESSAGES.ReadOnly, code
	end
	if def.expiresAtUtc and os.time() >= def.expiresAtUtc then
		return "Expired", MESSAGES.Expired, code
	end
	if profile.redeemedCodes[code] then
		return "AlreadyRedeemed", MESSAGES.AlreadyRedeemed, code
	end

	-- Nguyen tu: danh dau ma + cong moi phan thuong trong cung mot buoc khong yield (ban chup luu co du ca, hoac khong co gi).
	local reward = def.reward
	profile.redeemedCodes[code] = true
	local gems = math.max(0, math.floor(reward.gems or 0))
	local gold = math.max(0, math.floor(reward.gold or 0))
	profile.gems += gems
	profile.gold += gold
	local potionsGranted = false
	for potionId, qty in pairs(reward.potions or {}) do
		if PotionsConfig.ById[potionId] and qty > 0 then
			profile.potions[potionId] = math.min(99, (profile.potions[potionId] or 0) + math.floor(qty))
			potionsGranted = true
		end
	end
	DataService.MarkDirty(player)

	CurrencyService.PushCurrencies(player)
	if potionsGranted then ShopAndItemsService.PushInventory(player) end
	if gems > 0 then AnalyticsHelper.LogEconomySource(player, "Gems", gems, profile.gems, "Gameplay", "Code_" .. code) end
	if gold > 0 then AnalyticsHelper.LogEconomySource(player, "Gold", gold, profile.gold, "Gameplay", "Code_" .. code) end
	return "Redeemed", "Code " .. code .. " redeemed: " .. def.label .. "!", code
end

function CodesService.Init()
	Net.OnServerEvent(Net.ClientToServer.RedeemCode, function(player: Player, rawCode: any)
		local status, message, code = CodesService.Redeem(player, rawCode)
		if not player:IsDescendantOf(Players) then
			return
		end
		Net.FireClient(player, Net.ServerToClient.CodeRedeemResult, { ok = status == "Redeemed", status = status, message = message, code = code })
		Net.FireClient(player, Net.ServerToClient.Toast, { kind = if status == "Redeemed" then "Success" else "Error", text = message })
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		attempts[player] = nil
	end)
end

return CodesService
