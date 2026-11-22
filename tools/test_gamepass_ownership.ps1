param([string]$LuauExe = (Join-Path $PSScriptRoot 'luau.exe'))
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
[IO.Directory]::CreateDirectory((Join-Path $root 'build')) | Out-Null
$modulePaths = @{
    PerkService = 'src/server/Services/PerkService.luau'
    GamepassOwnership = 'src/server/Services/GamepassOwnership.luau'
}
$runner = [Text.StringBuilder]::new()
[void]$runner.AppendLine('local sources = {}')
foreach ($name in ($modulePaths.Keys | Sort-Object)) {
    $source = [IO.File]::ReadAllText((Join-Path $root $modulePaths[$name]))
    if ($source.Contains(']====]')) { throw 'Unsupported long-string delimiter in source' }
    [void]$runner.AppendLine(('sources["{0}"] = [====[{1}]====]' -f $name, $source))
}
[void]$runner.AppendLine('require("../tests/gamepass_ownership")(sources)')
$path = Join-Path $root 'build/test_gamepass_ownership.luau'
[IO.File]::WriteAllText($path, $runner.ToString(), [Text.UTF8Encoding]::new($false))
& $LuauExe $path
exit $LASTEXITCODE
