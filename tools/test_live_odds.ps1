param([string]$LuauExe = (Join-Path $PSScriptRoot 'luau.exe'))
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
[IO.Directory]::CreateDirectory((Join-Path $root 'build')) | Out-Null
$paths = @('src/shared/FishingRayFilter.luau', 'src/shared/Types.luau', 'src/shared/Util.luau', 'src/shared/OddsCalculator.luau', 'src/shared/PurchaseOddsSummary.luau', 'src/shared/CatchControl.luau',
    'src/client/Controllers/PurchaseOddsController.luau', 'src/server/Services/FishingRoller.luau', 'src/server/Services/BuffAggregator.luau', 'src/server/Services/PetsService.luau', 'src/server/Services/PetBuffs.luau', 'src/server/Services/PotionAndBaitHelper.luau',
    'src/server/Services/RemoteRateLimiter.luau')

$paths += Get-ChildItem src/shared/Config -Filter '*.luau' | ForEach-Object { $_.FullName }
$paths += Get-ChildItem src/shared/Config/Islands -Filter '*.luau' | ForEach-Object { $_.FullName }
$runner = "local sources = {}`n"
foreach ($path in $paths) {
    $name = [IO.Path]::GetFileNameWithoutExtension($path)
    if ($name -eq 'init') { $name = 'Islands' }
    $resolved = if ([IO.Path]::IsPathRooted($path)) { $path } else { Join-Path $root $path }
    $source = [IO.File]::ReadAllText($resolved)
    $runner += ('sources["{0}"] = [====[{1}]====]' -f $name, $source) + "`n"
}
$runner += [IO.File]::ReadAllText((Join-Path $root 'tests/live_odds.luau'))
$path = Join-Path $root 'build/test_live_odds.luau'
[IO.File]::WriteAllText($path, $runner, [Text.UTF8Encoding]::new($false))
& $LuauExe $path
exit $LASTEXITCODE
