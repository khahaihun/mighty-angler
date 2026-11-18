param([string]$LuauExe = (Join-Path $PSScriptRoot 'luau.exe'))
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
[IO.Directory]::CreateDirectory((Join-Path $root 'build')) | Out-Null
$source = [IO.File]::ReadAllText((Join-Path $root 'src/client/Controllers/AnimationController.luau'))
$runner = 'local source = [====[' + $source + "]====]`n" + [IO.File]::ReadAllText((Join-Path $root 'tests/animation_pose.luau'))
$path = Join-Path $root 'build/test_animation_pose.luau'
[IO.File]::WriteAllText($path, $runner, [Text.UTF8Encoding]::new($false))
& $LuauExe $path
exit $LASTEXITCODE
