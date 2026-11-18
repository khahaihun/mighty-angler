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
$modulePaths = @{
    Types = 'src/shared/Types.luau'
    Util = 'src/shared/Util.luau'
    GameConfig = 'src/shared/Config/GameConfig.luau'
    ProfileMigrator = 'src/server/Services/ProfileMigrator.luau'
    DataStoreLockHelper = 'src/server/Services/DataStoreLockHelper.luau'
    DataService = 'src/server/Services/DataService.luau'
    ProfileWriteHelper = 'src/server/Services/ProfileWriteHelper.luau'
    ProfilePersistenceService = 'src/server/Services/ProfilePersistenceService.luau'
}
$runner = [Text.StringBuilder]::new()
[void]$runner.AppendLine('local sources = {}')
foreach ($name in ($modulePaths.Keys | Sort-Object)) {
    $source = [IO.File]::ReadAllText((Join-Path $projectRoot $modulePaths[$name]))
    if ($source.Contains(']====]')) { throw 'Unsupported long-string delimiter in source' }
    [void]$runner.AppendLine(('sources["{0}"] = [====[{1}]====]' -f $name, $source))
}
[void]$runner.AppendLine('require("../tests/session_acquisition")(sources)')
$runnerPath = Join-Path $projectRoot 'build/test_session_acquisition.luau'
[IO.File]::WriteAllText($runnerPath, $runner.ToString(), [Text.UTF8Encoding]::new($false))
& $LuauExe $runnerPath
exit $LASTEXITCODE
