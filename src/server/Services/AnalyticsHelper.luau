--!strict
-- AnalyticsHelper.luau: Boc pcall 100% quanh AnalyticsService (Funnel tan thu + Economy). Thieu dich vu (VM/Studio) thi im lang bo qua.

local Players = game:GetService("Players")

local AnalyticsHelper = {}

-- Thu tu buoc Funnel tan thu: chi tang dan, moi nguoi choi ghi moi buoc toi da 1 lan/phien.
AnalyticsHelper.OnboardingSteps = {
	{ step = 1, name = "JoinedGame" },
	{ step = 2, name = "FirstCatch" },
	{ step = 3, name = "FirstGoldEarned" },
	{ step = 4, name = "FirstGymRep" },
	{ step = 5, name = "FirstIslandUnlock" },
	{ step = 6, name = "FirstEggHatch" },
}

local stepByName: { [string]: number } = {}
for _, entry in ipairs(AnalyticsHelper.OnboardingSteps) do
	stepByName[entry.name] = entry.step
end

local loggedSteps: { [Player]: { [string]: boolean } } = setmetatable({}, { __mode = "k" }) :: any
local cachedService: any = nil
local lookedUp = false
local failures = 0

local function getService(): any
	if not lookedUp then
		lookedUp = true
		local ok, service = pcall(function()
			return game:GetService("AnalyticsService")
		end)
		cachedService = if ok then service else nil
	end
	return cachedService
end

local function safeCall(fn: (any) -> ()): boolean
	local service = getService()
	if service == nil then
		return false
	end
	local ok, err = pcall(function()
		fn(service)
	end)
	if not ok then
		failures += 1
		if failures <= 5 then
			warn("[AnalyticsHelper] analytics call failed (ignored):", tostring(err))
		end
	end
	return ok
end

function AnalyticsHelper.FailureCount(): number
	return failures
end

function AnalyticsHelper.LogOnboardingStep(player: Player, stepName: string): boolean
	local step = stepByName[stepName]
	if not step then
		return false
	end
	local okPlayer, inGame = pcall(function()
		return player:IsDescendantOf(Players)
	end)
	if not okPlayer or not inGame then
		return false
	end
	local logged = loggedSteps[player] or {}
	loggedSteps[player] = logged
	if logged[stepName] then
		return false
	end
	logged[stepName] = true
	return safeCall(function(service: any)
		service:LogOnboardingFunnelStepEvent(player, step, stepName)
	end)
end

-- currency: "Gems" | "Gold"; transactionType: ten Enum.AnalyticsEconomyTransactionType (IAP, Gameplay, TimedReward...).
function AnalyticsHelper.LogEconomySource(player: Player, currency: string, amount: number, endingBalance: number, transactionType: string, itemSku: string?): boolean
	if type(amount) ~= "number" or amount <= 0 then
		return false
	end
	return safeCall(function(service: any)
		local flow = (Enum :: any).AnalyticsEconomyFlowType.Source
		local kind = (Enum :: any).AnalyticsEconomyTransactionType[transactionType].Name
		service:LogEconomyEvent(player, flow, currency, amount, endingBalance, kind, itemSku)
	end)
end

function AnalyticsHelper.Forget(player: Player)
	loggedSteps[player] = nil
end

return AnalyticsHelper
