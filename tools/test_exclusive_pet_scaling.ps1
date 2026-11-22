param([string]$LuauExe = (Join-Path $PSScriptRoot 'luau.exe'))
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
[IO.Directory]::CreateDirectory((Join-Path $root 'build')) | Out-Null

$modules = [ordered]@{
	Types = 'src/shared/Types.luau'
	Util = 'src/shared/Util.luau'
	CatchControl = 'src/shared/CatchControl.luau'
	GameConfig = 'src/shared/Config/GameConfig.luau'
	RodsConfig = 'src/shared/Config/RodsConfig.luau'
	EnchantsConfig = 'src/shared/Config/EnchantsConfig.luau'
	BaitConfig = 'src/shared/Config/BaitConfig.luau'
	PotionsConfig = 'src/shared/Config/PotionsConfig.luau'
	EventsConfig = 'src/shared/Config/EventsConfig.luau'
	PetsConfig = 'src/shared/Config/PetsConfig.luau'
	Island1 = 'src/shared/Config/Islands/Island1_SunnyShores.luau'
	Island2 = 'src/shared/Config/Islands/Island2_CoralDepths.luau'
	Island3 = 'src/shared/Config/Islands/Island3_MysticSwamp.luau'
	Island4 = 'src/shared/Config/Islands/Island4_EmberIsle.luau'
	Island5 = 'src/shared/Config/Islands/Island5_CelestialDeep.luau'
	Islands = 'src/shared/Config/Islands/init.luau'
	OddsCalculator = 'src/shared/OddsCalculator.luau'
	BuffAggregator = 'src/server/Services/BuffAggregator.luau'
	PetsService = 'src/server/Services/PetsService.luau'
}
$suiteSrc = [IO.File]::ReadAllText((Join-Path $root 'tests/exclusive_pet_scaling.luau'))

$runner = @'
local Color3 = { fromRGB = function(r, g, b) return { R = r, G = g, B = b } end }
local Vector3 = { new = function(x, y, z) return { X = x or 0, Y = y or 0, Z = z or 0 } end }
local task = { spawn = function(fn, ...) fn(...) end }

local loaded = {}
local tokens = {}
local function tok(name)
	if not tokens[name] then
		tokens[name] = { _key = name, Name = name, FindFirstChild = function(_, k) return tok(k) end, WaitForChild = function(_, k) return tok(k) end }
	end
	return tokens[name]
end
local function require(t) return loaded[t._key] end

local currentProfile = {}
local handlers = {}
local playerObj = { DisplayName = "Tester", SetAttribute = function() end }
loaded["Net"] = {
	ClientToServer = { HatchEgg = "HatchEgg", EquipPet = "EquipPet", UnequipPet = "UnequipPet", EquipBestPets = "EquipBestPets", DeletePet = "DeletePet" },
	ServerToClient = { PetsUpdated = "PetsUpdated", EggHatched = "EggHatched", Toast = "Toast" },
	OnServerEvent = function(k, fn) handlers[k] = fn end,
	FireClient = function() end,
	FireAllClients = function() end,
}
loaded["DataService"] = {
	Get = function() return currentProfile end,
	IsTransactionLocked = function() return false end,
	MarkDirty = function() end,
	OnProfileLoaded = function() end,
}
loaded["PerkService"] = {
	HasGamepass = function() return false end,
	ArePaidRandomItemsRestricted = function() return false end,
	GetPolicyState = function() return "Allowed" end,
}
loaded["CurrencyService"] = {
	SpendGold = function() return true end,
	SpendGems = function() return true end,
}

local SharedNode = {
	WaitForChild = function(_, k)
		if k == "Config" then
			return {
				WaitForChild = function(_, c) return tok(c) end,
				GameConfig = tok("GameConfig"), RodsConfig = tok("RodsConfig"), EnchantsConfig = tok("EnchantsConfig"),
				BaitConfig = tok("BaitConfig"), PotionsConfig = tok("PotionsConfig"), EventsConfig = tok("EventsConfig"),
				PetsConfig = tok("PetsConfig"), Islands = tok("Islands"),
			}
		end
		return tok(k)
	end,
}
local game = {
	GetService = function(_, s)
		if s == "ReplicatedStorage" then return { WaitForChild = function() return SharedNode end } end
		return {}
	end,
}
local function makeScriptCtx(key)
	if key == "Islands" then
		return {
			Parent = { Parent = { Types = tok("Types") } },
			Island1_SunnyShores = tok("Island1"),
			Island2_CoralDepths = tok("Island2"),
			Island3_MysticSwamp = tok("Island3"),
			Island4_EmberIsle = tok("Island4"),
			Island5_CelestialDeep = tok("Island5"),
		}
	elseif key == "Island1" or key == "Island2" or key == "Island3" or key == "Island4" or key == "Island5" then
		return { Parent = { Parent = { Parent = { Types = tok("Types") } } } }
	elseif key == "OddsCalculator" then
		return {
			Parent = {
				Types = tok("Types"),
				Config = {
					GameConfig = tok("GameConfig"), RodsConfig = tok("RodsConfig"), EnchantsConfig = tok("EnchantsConfig"),
					BaitConfig = tok("BaitConfig"), PotionsConfig = tok("PotionsConfig"), PetsConfig = tok("PetsConfig"),
					EventsConfig = tok("EventsConfig"), Islands = tok("Islands"),
				},
			},
		}
	elseif key == "BuffAggregator" or key == "PetsService" then
		return {
			Parent = {
				DataService = tok("DataService"),
				PerkService = tok("PerkService"),
				BuffAggregator = tok("BuffAggregator"),
				CurrencyService = tok("CurrencyService"),
			},
		}
	else
		local cfgTbl = {
			GameConfig = tok("GameConfig"), RodsConfig = tok("RodsConfig"), EnchantsConfig = tok("EnchantsConfig"),
			BaitConfig = tok("BaitConfig"), PotionsConfig = tok("PotionsConfig"), PetsConfig = tok("PetsConfig"),
			EventsConfig = tok("EventsConfig"), Islands = tok("Islands"),
		}
		return {
			Parent = {
				Parent = { Types = tok("Types"), Util = tok("Util"), Config = cfgTbl, CatchControl = tok("CatchControl") },
				Types = tok("Types"),
				Util = tok("Util"),
				Config = cfgTbl,
				GameConfig = tok("GameConfig"),
				CatchControl = tok("CatchControl"),
			},
		}
	end
end
'@

foreach ($kv in $modules.GetEnumerator()) {
	$src = [IO.File]::ReadAllText((Join-Path $root $kv.Value))
	$runner += "`ndo`nlocal script = makeScriptCtx('$($kv.Key)')`nlocal function _load()`n" + $src + "`nend`nloaded['$($kv.Key)'] = _load()`nend`n"
}

$runner += "`nlocal function loadSuite()`n" + $suiteSrc + "`nend`n" + @'
loaded["PetsService"].Init()
local runSuite = loadSuite()
runSuite({
	PetsConfig = loaded["PetsConfig"],
	Islands = loaded["Islands"],
	OddsCalculator = loaded["OddsCalculator"],
	PetsService = loaded["PetsService"],
	BuffAggregator = loaded["BuffAggregator"],
}, {
	player = playerObj,
	setProfile = function(p) currentProfile = p end,
	getProfile = function() return currentProfile end,
	equipBest = function() handlers["EquipBestPets"](playerObj) end,
	unequip = function(uid) handlers["UnequipPet"](playerObj, uid) end,
	deletePet = function(uid) handlers["DeletePet"](playerObj, uid) end,
})
'@

$path = Join-Path $root 'build/test_exclusive_pet_scaling.luau'
[IO.File]::WriteAllText($path, $runner, [Text.UTF8Encoding]::new($false))
& $LuauExe $path
exit $LASTEXITCODE
