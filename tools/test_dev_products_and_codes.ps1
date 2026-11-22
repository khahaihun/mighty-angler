param([string]$LuauExe = (Join-Path $PSScriptRoot 'luau.exe'))
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
if (-not (Test-Path -LiteralPath $LuauExe)) { throw 'Can tools/luau.exe (Luau CLI). Xem tests/README.md.' }
[IO.Directory]::CreateDirectory((Join-Path $root 'build')) | Out-Null

# 1. Luau VM: ReceiptService/CodesService/AnalyticsHelper + DataService that, chi gia lap DataStore/Players.
$modulePaths = @{
    Types = 'src/shared/Types.luau'
    Util = 'src/shared/Util.luau'
    GameConfig = 'src/shared/Config/GameConfig.luau'
    DevProductsConfig = 'src/shared/Config/DevProductsConfig.luau'
    CodesConfig = 'src/shared/Config/CodesConfig.luau'
    PotionsConfig = 'src/shared/Config/PotionsConfig.luau'
    DataStoreLockHelper = 'src/server/Services/DataStoreLockHelper.luau'
    DataService = 'src/server/Services/DataService.luau'
    ProfileWriteHelper = 'src/server/Services/ProfileWriteHelper.luau'
    ProfileValidator = 'src/server/Services/ProfileValidator.luau'
    ProfilePersistenceService = 'src/server/Services/ProfilePersistenceService.luau'
    ProfileMigrator = 'src/server/Services/ProfileMigrator.luau'
    ReceiptService = 'src/server/Services/ReceiptService.luau'
    CodesService = 'src/server/Services/CodesService.luau'
    AnalyticsHelper = 'src/server/Services/AnalyticsHelper.luau'
}
$runner = [Text.StringBuilder]::new()
[void]$runner.AppendLine('local sources = {}')
foreach ($name in ($modulePaths.Keys | Sort-Object)) {
    $source = [IO.File]::ReadAllText((Join-Path $root $modulePaths[$name]))
    if ($source.Contains(']====]')) { throw 'Unsupported long-string delimiter in source' }
    [void]$runner.AppendLine(('sources["{0}"] = [====[{1}]====]' -f $name, $source))
}
[void]$runner.AppendLine('require("../tests/dev_products_and_codes")(sources)')
$path = Join-Path $root 'build/test_dev_products_and_codes.luau'
[IO.File]::WriteAllText($path, $runner.ToString(), [Text.UTF8Encoding]::new($false))
& $LuauExe $path
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# 2. tools/check_launch_readiness.ps1: bao dong khi con ID = 0, va READY khi da dien du (ban sao tam).
$check = Join-Path $PSScriptRoot 'check_launch_readiness.ps1'
$failures = 0
function Expect([bool]$Condition, [string]$Label) {
    if ($Condition) { Write-Output "PASS readiness $Label" } else { Write-Output "FAIL readiness $Label"; $script:failures++ }
}
$output = (& $check -SourceRoot $root | Out-String)
$code = $LASTEXITCODE
Expect ($code -eq 2) "current repo (IDs still 0) exits 2, got $code"
Expect ($output -match "DevProduct 'GemsPouch' id = 0") 'report lists unfilled dev product'
Expect ($output -match "Gamepass 'AutoFish' id = 0") 'report lists unfilled gamepass'
Expect ($output -match 'ROBLOX_GROUP_ID = 0') 'report lists unfilled group id'

$temp = Join-Path $root 'build/readiness_fixture'
if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
$configDir = Join-Path $temp 'src/shared/Config'
[IO.Directory]::CreateDirectory($configDir) | Out-Null
$seed = 100
foreach ($file in @('GamepassesConfig.luau', 'DevProductsConfig.luau', 'GameConfig.luau', 'CodesConfig.luau')) {
    $text = [IO.File]::ReadAllText((Join-Path $root "src/shared/Config/$file"))
    $text = [regex]::Replace($text, '\bid\s*=\s*0\b', { param($m) $script:seed++; "id = $script:seed" })
    $text = $text.Replace('GameConfig.ROBLOX_GROUP_ID = 0', 'GameConfig.ROBLOX_GROUP_ID = 4242')
    [IO.File]::WriteAllText((Join-Path $configDir $file), $text, [Text.UTF8Encoding]::new($false))
}
$filled = (& $check -SourceRoot $temp | Out-String)
$code = $LASTEXITCODE
Expect ($code -eq 0) "all IDs filled exits 0, got $code"
Expect ($filled -match 'LAUNCH READINESS: READY') 'filled report says READY'

$partial = [IO.File]::ReadAllText((Join-Path $configDir 'DevProductsConfig.luau'))
$partial = [regex]::Replace($partial, '(key = "GemsVault", id = )\d+', '${1}0')
[IO.File]::WriteAllText((Join-Path $configDir 'DevProductsConfig.luau'), $partial, [Text.UTF8Encoding]::new($false))
$one = (& $check -SourceRoot $temp | Out-String)
$code = $LASTEXITCODE
Expect ($code -eq 2) "one missing dev product exits 2, got $code"
Expect ($one -match "DevProduct 'GemsVault' id = 0") 'single missing id named'
Remove-Item -LiteralPath $temp -Recurse -Force

Write-Output "READINESS_SUITE failed=$failures"
if ($failures -gt 0) { exit 1 }
exit 0
