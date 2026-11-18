$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)
$paths = @{
 FishingRoller='src/server/Services/FishingRoller.luau'
 GridWindow='src/client/UI/Components/GridWindow.luau'
 WorldPromptAccess='src/server/Services/WorldPromptAccess.luau'
 MinigameBar='src/client/UI/Panels/MinigameBar.luau'
}
$runner = [Text.StringBuilder]::new()
[void]$runner.AppendLine('local sources = {}')
foreach ($name in $paths.Keys) {
 $source = [IO.File]::ReadAllText((Join-Path (Get-Location) $paths[$name]))
 [void]$runner.AppendLine(('sources["{0}"] = [====[{1}]====]' -f $name, $source))
}
[void]$runner.AppendLine('require("../tests/fishing_wave")(sources)')
[void]$runner.AppendLine('require("../tests/fishing_prompt_grid")(sources)')
[IO.Directory]::CreateDirectory((Join-Path (Get-Location) 'build')) | Out-Null
[IO.File]::WriteAllText((Join-Path (Get-Location) 'build/test_fishing_wave.luau'), $runner.ToString(), [Text.UTF8Encoding]::new($false))
& tools/luau.exe build/test_fishing_wave.luau
exit $LASTEXITCODE
