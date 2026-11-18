param([string]$LuauExe = (Join-Path $PSScriptRoot 'luau.exe'))
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
[IO.Directory]::CreateDirectory((Join-Path $root 'build')) | Out-Null
$source = [IO.File]::ReadAllText((Join-Path $root 'src/client/Controllers/ParticleBudgetController.luau'))
$runner = @'
local added, removed
local myRoot = { Position = 0, IsA = function() return true end }
local character = { FindFirstChild = function() return myRoot end }
local players = { LocalPlayer = { Character = character } }
local distance = 20
local pos = setmetatable({}, { __sub = function() return { Magnitude = distance } end })
local function makeEmitter(selfOwned)
    local attrs = {}
    return { Enabled = true, Rate = 10, IsA = function(_, class) return class == "ParticleEmitter" end,
        GetAttribute = function(_, key) return attrs[key] end, SetAttribute = function(_, key, value) attrs[key] = value end,
        FindFirstAncestorWhichIsA = function() return { Position = pos } end,
        IsDescendantOf = function() return selfOwned end }
end
local selfEmitter, otherFish = makeEmitter(true), makeEmitter(false)
local scans = 0
local workspace = { DescendantAdded = { Connect = function(_, cb) added = cb end }, DescendantRemoving = { Connect = function(_, cb) removed = cb end },
    GetDescendants = function() scans += 1; return { selfEmitter, otherFish } end }
local game = { GetService = function(_, key) return if key == "Players" then players else workspace end }
local function loadModule()
'@
$runner += "`n" + $source + "`nend`n" + @'
local budget = loadModule()
budget.Update(false); assert(selfEmitter.Enabled and otherFish.Enabled)
budget.Update(true); assert(selfEmitter.Enabled and not otherFish.Enabled)
distance = 220; budget.Update(false); assert(not selfEmitter.Enabled and not otherFish.Enabled)
removed(nil, otherFish) -- unused signal compatibility below
removed(otherFish); added(otherFish)
distance = 20; budget.Update(false); assert(otherFish.Enabled, "reparent must restore authored visibility")
for _ = 1, 20 do budget.Update(false) end
assert(scans == 1, "periodic updates must never rescan model descendants")
print("PASS particle budget: held fish near/far, low GFX, reparent, one initial scan")
'@
$runner = $runner.Replace('removed(nil, otherFish) -- unused signal compatibility below', '')
$path = Join-Path $root 'build/test_particle_budget.luau'
[IO.File]::WriteAllText($path, $runner, [Text.UTF8Encoding]::new($false))
& $LuauExe $path
exit $LASTEXITCODE
