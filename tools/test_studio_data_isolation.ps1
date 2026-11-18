param([string]$LuauExe = (Join-Path $PSScriptRoot 'luau.exe'))

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot
if (-not (Test-Path -LiteralPath $LuauExe)) {
    throw 'Can tools/luau.exe (Luau CLI). Xem tests/README.md; khong can bat Roblox API.'
}
if (-not (Test-Path -LiteralPath 'build')) {
    New-Item -ItemType Directory -Path 'build' | Out-Null
}

# Embed unchanged production source: Luau CLI has no Roblox Instance loader or file IO.
$modulePaths = @{
    Types = 'src/shared/Types.luau'
    Util = 'src/shared/Util.luau'
    GameConfig = 'src/shared/Config/GameConfig.luau'
    DataStoreLockHelper = 'src/server/Services/DataStoreLockHelper.luau'
    LiveOpsService = 'src/server/Services/LiveOpsService.luau'
}
$runner = [Text.StringBuilder]::new()
[void]$runner.AppendLine('local sources = {}')
foreach ($name in ($modulePaths.Keys | Sort-Object)) {
    $source = [IO.File]::ReadAllText((Join-Path $projectRoot $modulePaths[$name]))
    if ($source.Contains(']====]')) { throw 'Unsupported long-string delimiter in source' }
    [void]$runner.AppendLine(('sources["{0}"] = [====[{1}]====]' -f $name, $source))
}
[void]$runner.AppendLine('require("../tests/studio_data_isolation")(sources)')
$runnerPath = Join-Path $projectRoot 'build/test_studio_data_isolation.luau'
[IO.File]::WriteAllText($runnerPath, $runner.ToString(), [Text.UTF8Encoding]::new($false))
& $LuauExe $runnerPath
exit $LASTEXITCODE
