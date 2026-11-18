param([string]$LuauExe = (Join-Path $PSScriptRoot 'luau.exe'))
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
$source = [IO.File]::ReadAllText((Join-Path $root 'src/server/Services/PerkService.luau'))
$start = $source.IndexOf('local function loadPolicyForPlayer')
$end = $source.IndexOf('local function syncExclusivePassRodIfNeeded')
$body = $source.Substring($start, $end - $start)
$runner = @'
local paidRandomPolicyState = {}
local PerkService = { PushPerks = function() end }
local Players = {}
local player = { IsDescendantOf = function() return true end }
local response: any = nil
local apiFails = false
local PolicyService = { GetPolicyInfoForPlayerAsync = function()
    if apiFails then error("offline") end
    return response
end }
local task = { wait = function() end }
'@
$runner += "`n" + $body + @'
assert(PerkService.ArePaidRandomItemsRestricted(player), "pending must deny")
local cases = { {}, { ArePaidRandomItemsRestricted = "false" }, { ArePaidRandomItemsRestricted = true }, { ArePaidRandomItemsRestricted = 0 } }
for _, info in ipairs(cases) do
    response = info
    loadPolicyForPlayer(player)
    assert(PerkService.ArePaidRandomItemsRestricted(player), "malformed/restricted must deny")
end
apiFails = true
loadPolicyForPlayer(player)
assert(PerkService.ArePaidRandomItemsRestricted(player), "API failure must deny even offline")
apiFails = false
response = { ArePaidRandomItemsRestricted = false }
loadPolicyForPlayer(player)
assert(not PerkService.ArePaidRandomItemsRestricted(player), "boolean false must allow")
print("PASS paid_random_policy: pending, API error, missing, string, numeric, true, false")
'@
$path = Join-Path $root 'build/test_paid_random_policy.luau'
[IO.File]::WriteAllText($path, $runner, [Text.UTF8Encoding]::new($false))
& $LuauExe $path
exit $LASTEXITCODE
