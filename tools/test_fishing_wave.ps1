$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)
$paths = @{
 CatchControl='src/shared/CatchControl.luau'
 FishingService='src/server/Services/FishingService.luau'
 FishingController='src/client/Controllers/FishingController.luau'
 FishingCastState='src/server/Services/FishingCastState.luau'
 FishingSessionManager='src/server/Services/FishingSessionManager.luau'
 FishingRayFilter='src/shared/FishingRayFilter.luau'
 FishingRoller='src/server/Services/FishingRoller.luau'
 GridWindow='src/client/UI/Components/GridWindow.luau'
 HotbarAndCastController='src/client/Controllers/HotbarAndCastController.luau'
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
[void]$runner.AppendLine('require("../tests/fishing_cast_lifecycle")(sources)')
[void]$runner.AppendLine('require("../tests/fishing_client_schedule")(sources)')
[void]$runner.AppendLine('require("../tests/manual_cast_hold")(sources)')
[IO.Directory]::CreateDirectory((Join-Path (Get-Location) 'build')) | Out-Null
[IO.File]::WriteAllText((Join-Path (Get-Location) 'build/test_fishing_wave.luau'), $runner.ToString(), [Text.UTF8Encoding]::new($false))
& tools/luau.exe build/test_fishing_wave.luau
exit $LASTEXITCODE
