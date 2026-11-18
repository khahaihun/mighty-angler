param([string]$LuauExe = (Join-Path $PSScriptRoot 'luau.exe'),
 [ValidateSet('None','AppraiseFloor','StrengthTwice','TridentTrophy','RebirthCap')][string]$ProbeMutation = 'None')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot
$modulePaths = @{
 GameConfig='src/shared/Config/GameConfig.luau'; Util='src/shared/Util.luau'
 RodsConfig='src/shared/Config/RodsConfig.luau'; EnchantsConfig='src/shared/Config/EnchantsConfig.luau'
 BountiesConfig='src/shared/Config/BountiesConfig.luau'; RebirthConfig='src/shared/Config/RebirthConfig.luau'
 TrophyHelper='src/shared/TrophyHelper.luau'; CurrencyService='src/server/Services/CurrencyService.luau'
 EnchantAndBountyService='src/server/Services/EnchantAndBountyService.luau'
 FishingRoller='src/server/Services/FishingRoller.luau'; FishingService='src/server/Services/FishingService.luau'
 ProgressionService='src/server/Services/ProgressionService.luau'
}
$runner=[Text.StringBuilder]::new()
[void]$runner.AppendLine('local sources = {}')
foreach ($name in ($modulePaths.Keys | Sort-Object)) {
 $source=[IO.File]::ReadAllText((Join-Path $projectRoot $modulePaths[$name]))
 # Opt-in negative controls change only embedded strings, never production files.
 $probes = @{
  AppraiseFloor = @('EnchantAndBountyService', 'math.ceil(entry.weight * 0.85 * 10 - 1e-6)', 'math.floor(entry.weight * 0.85 * 10 - 1e-6)')
  StrengthTwice = @('FishingService', 'AddStrength(player, snapStrAmount, false, false)', 'AddStrength(player, snapStrAmount, true, false)')
  TridentTrophy = @('EnchantAndBountyService', 'if entry.soulbound or entry.locked then', 'if entry.locked then')
  RebirthCap = @('TrophyHelper', 'local cap = GameConfig.MAX_SOULBOUND_TROPHIES', 'local cap = 13')
 }
 if ($ProbeMutation -ne 'None' -and $name -eq $probes[$ProbeMutation][0]) {
  $probe = $probes[$ProbeMutation]
  if (-not $source.Contains($probe[1])) { throw "Probe target changed: $ProbeMutation" }
  $source = $source.Replace($probe[1], $probe[2])
 }
 if ($source.Contains(']====]')) { throw 'Unsupported long-string delimiter' }
 [void]$runner.AppendLine(('sources["{0}"] = [====[{1}]====]' -f $name,$source))
}
[void]$runner.AppendLine('require("../tests/v3_regression")(sources)')
if (-not (Test-Path build)) { New-Item -ItemType Directory build | Out-Null }
$runnerPath=Join-Path $projectRoot 'build/test_v3_regression.luau'
[IO.File]::WriteAllText($runnerPath,$runner.ToString(),[Text.UTF8Encoding]::new($false))
& $LuauExe $runnerPath
exit $LASTEXITCODE
