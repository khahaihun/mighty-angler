param([string]$LuauExe = (Join-Path $PSScriptRoot 'luau.exe'))
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
[IO.Directory]::CreateDirectory((Join-Path $root 'build')) | Out-Null
$source = [IO.File]::ReadAllText((Join-Path $root 'src/shared/CatchControl.luau'))
$config = [IO.File]::ReadAllText((Join-Path $root 'src/shared/Config/GameConfig.luau'))
$max = [regex]::Match($config, 'GameConfig.MINIGAME_MAX_WIDTH = ([\d.]+)').Groups[1].Value
$bonus = [regex]::Match($config, 'GameConfig.STRENGTH_MAX_BAR_BONUS = ([\d.]+)').Groups[1].Value
$source = $source.Replace('local GameConfig = require(script.Parent.Config.GameConfig)', "local GameConfig = { MINIGAME_MAX_WIDTH = $max, STRENGTH_MAX_BAR_BONUS = $bonus }")
$runner = "local function loadModule()`n" + $source + "`nend`n" + @'
local control = loadModule()
local function near(a, b) assert(math.abs(a-b) < 1e-9, string.format("%f ~= %f", a, b)) end
near(control.ComputeWidth(false, 0), 0.28)
near(control.ComputeWidth(true, 0), 0.22)
for _, baseline in ipairs({ 0, 1500, 4500000 }) do
    for _, strength in ipairs({ 0, 100, 10000, 1e12 }) do
        local mastery = math.clamp(math.log10(1 + strength / math.max(baseline, 300)) / 2, 0, 1)
        for _, bonus in ipairs({ 0, 0.06, 0.35 }) do
            local actual = control.ComputeWidthBonus(strength, baseline, bonus)
            assert(actual >= bonus and actual <= bonus + 1)
            for _, boss in ipairs({ false, true }) do
                assert(control.ComputeWidth(boss, actual) >= 0.20)
            end
        end
        near(control.ComputeMastery(strength, baseline), mastery)
    end
end
print("PASS catch control: Rare/Boss bases and 36 strength/control combinations")
'@
$path = Join-Path $root 'build/test_catch_control.luau'
[IO.File]::WriteAllText($path, $runner, [Text.UTF8Encoding]::new($false))
& $LuauExe $path
exit $LASTEXITCODE
