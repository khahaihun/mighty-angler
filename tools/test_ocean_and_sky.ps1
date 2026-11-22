param([string]$LuauExe = (Join-Path $PSScriptRoot 'luau.exe'))
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
[IO.Directory]::CreateDirectory((Join-Path $root 'build')) | Out-Null
$modulePaths = @{
    ManualIslandAdapter = 'src/server/World/ManualIslandAdapter.luau'
    OceanBuilder = 'src/server/World/OceanBuilder.luau'
    OceanLayout = 'src/server/World/OceanLayout.luau'
    PartFactory = 'src/server/World/PartFactory.luau'
    SkyBuilder = 'src/server/World/SkyBuilder.luau'
    TerrainWaterBuilder = 'src/server/World/TerrainWaterBuilder.luau'
}
$runner = [Text.StringBuilder]::new()
[void]$runner.AppendLine('local sources = {}')
foreach ($name in ($modulePaths.Keys | Sort-Object)) {
    $source = [IO.File]::ReadAllText((Join-Path $root $modulePaths[$name]))
    if ($source.Contains(']====]')) { throw 'Unsupported long-string delimiter in source' }
    [void]$runner.AppendLine(('sources["{0}"] = [====[{1}]====]' -f $name, $source))
}
[void]$runner.AppendLine('require("../tests/ocean_and_sky")(sources)')
$path = Join-Path $root 'build/test_ocean_and_sky.luau'
[IO.File]::WriteAllText($path, $runner.ToString(), [Text.UTF8Encoding]::new($false))
& $LuauExe $path
exit $LASTEXITCODE
