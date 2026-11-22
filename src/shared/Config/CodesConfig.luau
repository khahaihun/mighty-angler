--!strict
-- CodesConfig.luau: Ma Qua Tang (Redeem Codes). Ma luu CHU HOA khong khoang trang; expiresAtUtc la giay Unix UTC (tuy chon).

export type CodeReward = {
	gems: number?,
	gold: number?,
	potions: { [string]: number }?,
}

export type CodeDef = {
	code: string,
	label: string,
	reward: CodeReward,
	expiresAtUtc: number?,
}

local CodesConfig = {}

CodesConfig.MAX_CODE_LENGTH = 24

CodesConfig.List = {
	{ code = "RELEASE", label = "+150 Gems & +2,500 Gold", reward = { gems = 150, gold = 2500 } },
	-- Het han 2027-12-31 23:59:59 UTC
	{ code = "SUNNY", label = "+50 Gems & 1x Lucky Elixir", reward = { gems = 50, potions = { lucky_elixir_s = 1 } }, expiresAtUtc = 1830297599 },
	-- Het han 2027-06-30 23:59:59 UTC
	{ code = "BIGCATCH", label = "+5,000 Gold & 1x Titan Brew", reward = { gold = 5000, potions = { titan_brew_s = 1 } }, expiresAtUtc = 1814399999 },
} :: { CodeDef }

CodesConfig.ByCode = {} :: { [string]: CodeDef }
for _, def in ipairs(CodesConfig.List) do
	CodesConfig.ByCode[def.code] = def
end

-- Chuan hoa: bo moi khoang trang, doi chu hoa; chi nhan A-Z va 0-9.
function CodesConfig.Normalize(raw: any): string?
	if type(raw) ~= "string" or #raw > 64 then
		return nil
	end
	local code = string.upper((string.gsub(raw, "%s+", "")))
	if code == "" or #code > CodesConfig.MAX_CODE_LENGTH or string.find(code, "[^A-Z0-9]") then
		return nil
	end
	return code
end

return CodesConfig
