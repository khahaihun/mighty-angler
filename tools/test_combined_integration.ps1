param([string]$LuauExe = (Join-Path $PSScriptRoot 'luau.exe'))
$ErrorActionPreference = 'Stop'
$root=Split-Path -Parent $PSScriptRoot
Set-Location $root
$paths=@('src/client/Controllers/FishingController.luau','src/client/Controllers/CameraFocusController.luau','src/server/Services/FishingCastState.luau','src/server/Services/FishingRoller.luau','src/shared/OddsCalculator.luau','src/shared/Util.luau','src/shared/FishingRayFilter.luau')
$paths+=Get-ChildItem src/shared/Config -Filter '*.luau' | ForEach-Object { $_.FullName }
$runner="local sources = {}`n"
foreach ($path in $paths) {
 $name=[IO.Path]::GetFileNameWithoutExtension($path)
 $resolved=if ([IO.Path]::IsPathRooted($path)) { $path } else { Join-Path $root $path }
 $source=[IO.File]::ReadAllText($resolved)
 if ($source.Contains(']====]')) { throw 'Unsupported source delimiter' }
 $runner+=('sources["{0}"] = [====[{1}]====]' -f $name,$source)+"`n"
}
$runner+='require("../tests/combined_fishing_camera")(sources)'
[IO.Directory]::CreateDirectory((Join-Path $root 'build')) | Out-Null
$runnerPath=Join-Path $root 'build/test_combined_integration.luau'
[IO.File]::WriteAllText($runnerPath,$runner,[Text.UTF8Encoding]::new($false))
& $LuauExe $runnerPath
exit $LASTEXITCODE
