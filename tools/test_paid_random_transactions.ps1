param([string]$LuauExe = (Join-Path $PSScriptRoot 'luau.exe'))
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
[IO.Directory]::CreateDirectory((Join-Path $root 'build')) | Out-Null
function Read-Section($path, $start, $end) {
    $source = [IO.File]::ReadAllText((Join-Path $root $path))
    $offset = $source.IndexOf($start)
    return $source.Substring($offset, $source.IndexOf($end, $offset) - $offset)
}
$policy = Read-Section 'src/server/Services/PerkService.luau' 'local function loadPolicyForPlayer' 'local function syncExclusivePassRodIfNeeded'
$hatch = Read-Section 'src/server/Services/PetsService.luau' 'function PetsService.HandleHatchEgg' 'local function handleEquipPet'
$enchant = Read-Section 'src/server/Services/EnchantAndBountyService.luau' 'local function handleRollEnchant' 'local function handleUnlockExclusiveRod'
$runner = @'
local paidRandomPolicyState, profile = {}, {}
local PerkService = { PushPerks = function() end }
local Players, player = {}, { IsDescendantOf = function() return true end }
local response, apiFails = {}, false
local PolicyService = { GetPolicyInfoForPlayerAsync = function() if apiFails then error("offline") end; return response end }
local task = { wait = function() end }
local DataService = { Get = function() return profile end, IsTransactionLocked = function() return false end, MarkDirty = function() end }
local spendCalls = 0
local CurrencyService = {}
function CurrencyService.SpendGems(_, cost) spendCalls += 1; profile.gems -= cost; return true end
function CurrencyService.SpendGold(_, cost) profile.gold -= cost; return true end
local Net = { FireClient = function() end, ServerToClient = { Toast = "Toast", EnchantAndRelicsUpdated = "Enchant" } }
local pet = { id = "Pet", weightChance = 1 }
local PetsConfig = { EggsById = {
    Gems = { id = "Gems", currency = "Gems", cost = 100, islandId = 1, pets = { pet } },
    Gold = { id = "Gold", currency = "Gold", cost = 50, islandId = 1, pets = { pet } },
} }
local PetsService = { AwardPetDirect = function(_, result) table.insert(profile.pets, result) end }
local GameConfig = { MAX_PET_INVENTORY = 100 }
local Util = { PickWeighted = function(list) return list[1] end }
local RodsConfig = { ById = { Exclusive = { isExclusive = true, name = "Exclusive" } } }
local checkNearAltarOrCrafter = function() return true end
local EnchantsConfig = { ROLL_GEM_COST = 200, ROLL_REL_COST = 1, RollEnchant = function() return { id = "Swift", rarity = "Rare", name = "Swift" } end }
local ShopAndItemsService = { PushInventory = function() end }
local function reset()
    profile = { gems = 1000, gold = 1000, pets = {}, stats = { eggsHatched = 0 }, unlockedIslands = { ["1"] = true }, ownedRods = { Exclusive = true }, rodEnchants = {}, enchantRelics = 2, currentIsland = 1 }
    spendCalls = 0
end
'@
$runner += "`n" + $policy + "`n" + $hatch + "`n" + $enchant + "`n" + @'
local function assertDenied()
    reset()
    PetsService.HandleHatchEgg(player, "Gems")
    handleRollEnchant(player, "Exclusive", true)
    assert(profile.gems == 1000 and #profile.pets == 0 and profile.stats.eggsHatched == 0)
    assert(profile.rodEnchants.Exclusive == nil and profile.enchantRelics == 2 and spendCalls == 0)
    PetsService.HandleHatchEgg(player, "Gold")
    handleRollEnchant(player, "Exclusive", false)
    assert(profile.gold == 950 and #profile.pets == 1 and profile.enchantRelics == 1)
    assert(profile.gems == 1000 and profile.rodEnchants.Exclusive == "Swift")
end
assertDenied() -- pending
for _, info in ipairs({ {}, { ArePaidRandomItemsRestricted = "false" }, { ArePaidRandomItemsRestricted = true }, { ArePaidRandomItemsRestricted = 0 } }) do
    response = info; loadPolicyForPlayer(player); assertDenied()
end
apiFails = true; loadPolicyForPlayer(player); assertDenied()
apiFails = false; response = { ArePaidRandomItemsRestricted = false }; loadPolicyForPlayer(player)
reset(); PetsService.HandleHatchEgg(player, "Gems"); assert(profile.gems == 900 and spendCalls == 1 and #profile.pets == 1)
reset(); handleRollEnchant(player, "Exclusive", true); assert(profile.gems == 800 and spendCalls == 1 and profile.rodEnchants.Exclusive == "Swift")
print("PASS paid random handlers: 6 deny cases preserve Gems/items; Gold/Relic succeed; false spends once per action")
'@
$path = Join-Path $root 'build/test_paid_random_transactions.luau'
[IO.File]::WriteAllText($path, $runner, [Text.UTF8Encoding]::new($false))
& $LuauExe $path
exit $LASTEXITCODE
