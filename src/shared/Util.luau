--!strict
-- Util.luau: Ham tien ich dinh dang so, weighted random, deep copy va reconcile

local HttpService = game:GetService("HttpService")

local Util = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa" }

function Util.FormatNumber(n: number): string
	local sign = n < 0 and "-" or ""
	local absVal = math.abs(n)
	if absVal < 1000 then
		if absVal == math.floor(absVal) then
			return sign .. tostring(math.floor(absVal))
		end
		return string.format("%s%.1f", sign, absVal)
	end

	local tier = math.min(math.floor(math.log10(absVal) / 3) + 1, #SUFFIXES)
	local scaled = absVal / (10 ^ ((tier - 1) * 3))
	if scaled >= 100 then
		return string.format("%s%.0f%s", sign, scaled, SUFFIXES[tier])
	elseif scaled >= 10 then
		return string.format("%s%.1f%s", sign, scaled, SUFFIXES[tier])
	else
		return string.format("%s%.2f%s", sign, scaled, SUFFIXES[tier])
	end
end

function Util.FormatDuration(seconds: number): string
	local clamped = math.max(0, math.floor(seconds))
	local mins = math.floor(clamped / 60)
	local secs = clamped % 60
	return string.format("%02d:%02d", mins, secs)
end

function Util.FormatWeight(weightKg: number): string
	return string.format("%.1f kg", weightKg)
end

function Util.NewUid(): string
	return string.sub(string.gsub(HttpService:GenerateGUID(false), "-", ""), 1, 12)
end

function Util.DeepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	local copy: { [any]: any } = {}
	for k, v in pairs(value :: any) do
		copy[Util.DeepCopy(k)] = Util.DeepCopy(v)
	end
	return (copy :: any) :: T
end

function Util.Reconcile(target: { [string]: any }, template: { [string]: any }): { [string]: any }
	for key, defaultVal in pairs(template) do
		local existing = target[key]
		if existing == nil then
			target[key] = Util.DeepCopy(defaultVal)
		elseif type(existing) == "table" and type(defaultVal) == "table" then
			Util.Reconcile(existing, defaultVal)
		end
	end
	return target
end

function Util.PickWeighted<T>(items: { T }, getWeight: (T) -> number): T
	assert(#items > 0, "PickWeighted requires non-empty array")
	local total = 0
	for _, item in ipairs(items) do
		total += math.max(0, getWeight(item))
	end
	if total <= 0 then
		return items[1]
	end
	local roll = math.random() * total
	local cumulative = 0
	for _, item in ipairs(items) do
		cumulative += math.max(0, getWeight(item))
		if roll <= cumulative then
			return item
		end
	end
	return items[#items]
end

function Util.GetUtcDayIndex(timestampSec: number?): number
	local nowSec = timestampSec or os.time()
	return math.floor(nowSec / 86400)
end

-- Song tam giac tat dinh giua [0.02, 0.98] dung chung cho Client 60FPS & Server Per-Strike Verification
function Util.TriangleBounce(startPos: number, speed: number, elapsed: number): number
	local minP = 0.02
	local maxP = 0.98
	local span = maxP - minP -- 0.96
	local period = span * 2
	local d0 = math.clamp(startPos, minP, maxP) - minP
	local u = (d0 + math.max(0.05, speed) * math.max(0, elapsed)) % period
	if u <= span then
		return minP + u
	else
		return maxP - (u - span)
	end
end

return Util
