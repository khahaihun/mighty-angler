param([string]$LuauExe = (Join-Path $PSScriptRoot 'luau.exe'))
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$build = Join-Path $root 'build'
[IO.Directory]::CreateDirectory($build) | Out-Null
$modulePaths = @{
    Net = 'src/shared/Net.luau'
    GameConfig = 'src/shared/Config/GameConfig.luau'
}
foreach ($name in @(
    'RemoteRateLimiter', 'FishingService', 'FishingCastState', 'FishingSessionManager',
    'PetsService', 'CurrencyService', 'ShopAndItemsService', 'GymService',
    'EnchantAndBountyService', 'IslandService', 'ProgressionService'
)) {
    $modulePaths[$name] = "src/server/Services/$name.luau"
}
$runner = [Text.StringBuilder]::new()
[void]$runner.AppendLine('local sources = {}')
foreach ($name in ($modulePaths.Keys | Sort-Object)) {
    $source = [IO.File]::ReadAllText((Join-Path $root $modulePaths[$name]))
    if ($source.Contains(']====]')) { throw 'Unsupported long-string delimiter in source' }
    [void]$runner.AppendLine(('sources["{0}"] = [====[{1}]====]' -f $name, $source))
}
[void]$runner.AppendLine('require("../tests/rate_limit_and_memory_leaks")(sources)')
$path = Join-Path $build 'test_rate_limit_and_memory_leaks.luau'
[IO.File]::WriteAllText($path, $runner.ToString(), [Text.UTF8Encoding]::new($false))
& $LuauExe $path
exit $LASTEXITCODE
