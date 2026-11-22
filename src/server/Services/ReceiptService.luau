--!strict
-- ReceiptService.luau: MarketplaceService.ProcessReceipt chong nhan doi cho goi Gems (Developer Products).
-- Chi tra PurchaseGranted khi PurchaseId + Gems da nam trong ban luu DataStore duoc xac nhan; moi truong hop khac tra
-- NotProcessedYet de Roblox goi lai (khong mat Robux, khong cong 2 lan).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local DevProductsConfig = require(Shared:WaitForChild("Config"):WaitForChild("DevProductsConfig"))

local DataService = require(script.Parent.DataService)
local PerkService = require(script.Parent.PerkService)
local CurrencyService = require(script.Parent.CurrencyService)
local AnalyticsHelper = require(script.Parent.AnalyticsHelper)

local ReceiptService = {}

local PROMPT_COOLDOWN_SEC = 1.0
local inFlight: { [string]: boolean } = {}
-- PurchaseId da cong vao RAM nhung lan luu chua xac nhan: chua duoc coi la "da cap".
local unconfirmed: { [Player]: { [string]: boolean } } = {}
local lastPromptAt: { [Player]: number } = {}

local function decision(name: string): any
	return (Enum :: any).ProductPurchaseDecision[name]
end

local function findPlayer(userId: any): Player?
	for _, player in ipairs(Players:GetPlayers()) do
		if player.UserId == userId then
			return player
		end
	end
	return nil
end

local function toast(player: Player, kind: string, text: string)
	if player:IsDescendantOf(Players) then
		Net.FireClient(player, Net.ServerToClient.Toast, { kind = kind, text = text })
	end
end

local function rememberPurchase(list: { string }, purchaseId: string)
	table.insert(list, purchaseId)
	while #list > GameConfig.MAX_PROCESSED_PURCHASE_IDS do
		table.remove(list, 1)
	end
end

local function grantAndConfirm(player: Player, product: DevProductsConfig.DevProductDef, purchaseId: string): any
	local profile = DataService.Get(player)
	if not profile or not DataService.CanWritePersistent(player) then
		return decision("NotProcessedYet")
	end
	local pending = unconfirmed[player] or {}
	unconfirmed[player] = pending
	if not table.find(profile.processedPurchaseIds, purchaseId) then
		-- Cong Gems va ghi PurchaseId trong cung mot buoc khong yield: moi ban chup luu deu co ca hai hoac khong co gi.
		profile.gems += product.gems
		rememberPurchase(profile.processedPurchaseIds, purchaseId)
		pending[purchaseId] = true
		DataService.MarkDirty(player)
	elseif not pending[purchaseId] then
		return decision("PurchaseGranted")
	end
	local result = DataService.SaveProfile(player)
	if result ~= "Saved" then
		-- Giu nguyen RAM (khong hoan tac de tranh am Gems neu nguoi choi da tieu); lan goi lai se thu luu tiep, khong cong them.
		warn(string.format("[ReceiptService] Save not confirmed user=%d purchase=%s result=%s", player.UserId, purchaseId, result))
		return decision("NotProcessedYet")
	end
	pending[purchaseId] = nil
	CurrencyService.PushCurrencies(player)
	if player:IsDescendantOf(Players) then
		Net.FireClient(player, Net.ServerToClient.FloatingGain, { kind = "Gems", amount = product.gems })
	end
	toast(player, "Success", string.format("💎 +%s Gems added. Thank you for supporting Mighty Angler!", Util.FormatNumber(product.gems)))
	AnalyticsHelper.LogEconomySource(player, "Gems", product.gems, profile.gems, "IAP", product.key)
	return decision("PurchaseGranted")
end

function ReceiptService.ProcessReceipt(receiptInfo: any): any
	if type(receiptInfo) ~= "table" or receiptInfo.PurchaseId == nil then
		return decision("NotProcessedYet")
	end
	local purchaseId = tostring(receiptInfo.PurchaseId)
	local product = DevProductsConfig.GetById(receiptInfo.ProductId)
	if not product then
		warn(string.format("[ReceiptService] Unknown product id=%s purchase=%s", tostring(receiptInfo.ProductId), purchaseId))
		return decision("NotProcessedYet")
	end
	local player = findPlayer(receiptInfo.PlayerId)
	if not player or inFlight[purchaseId] then
		return decision("NotProcessedYet")
	end
	inFlight[purchaseId] = true
	local ok, result = pcall(grantAndConfirm, player, product, purchaseId)
	inFlight[purchaseId] = nil
	if not ok then
		warn("[ReceiptService] ProcessReceipt error:", tostring(result))
		return decision("NotProcessedYet")
	end
	return result
end

-- Tra ve (productId, nil) khi duoc phep mo hop mua; (nil, loi nhan Toast) khi phai chan.
function ReceiptService.CheckPrompt(player: Player, rawKey: any): (number?, string?)
	local product = if type(rawKey) == "string" then DevProductsConfig.ByKey[rawKey] else nil
	if not product then
		return nil, nil
	end
	if product.id <= 0 then
		return nil, if RunService:IsStudio()
			then ("Studio: set the Developer Product ID for '" .. product.name .. "' in DevProductsConfig before publishing!")
			else "Gem packs are coming very soon. Stay tuned!"
	end
	if DataService.IsTransactionLocked(player, false) then
		return nil, "Your save is still loading or protected. Please try again in a moment!"
	end
	if PerkService.GetPolicyState(player) == "Loading" then
		return nil, "Checking store rules for your account... try again in a moment!"
	end
	return product.id, nil
end

function ReceiptService.Init()
	local MarketplaceService = game:GetService("MarketplaceService")
	MarketplaceService.ProcessReceipt = ReceiptService.ProcessReceipt

	Net.OnServerEvent(Net.ClientToServer.PromptDevProduct, function(player: Player, rawKey: any)
		local now = os.clock()
		if now - (lastPromptAt[player] or -math.huge) < PROMPT_COOLDOWN_SEC then
			return
		end
		lastPromptAt[player] = now
		local productId, message = ReceiptService.CheckPrompt(player, rawKey)
		if not productId then
			if message then toast(player, "Info", message) end
			return
		end
		if PerkService.ArePaidRandomItemsRestricted(player) then
			toast(player, "Info", "Gem Eggs & Enchant rolls are unavailable for your account. Gems still unlock Bounty rewards & exclusive rods.")
		end
		pcall(function()
			MarketplaceService:PromptProductPurchase(player, productId)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		unconfirmed[player] = nil
		lastPromptAt[player] = nil
	end)
end

return ReceiptService
