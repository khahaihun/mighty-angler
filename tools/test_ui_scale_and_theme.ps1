param([string]$LuauExe = (Join-Path $PSScriptRoot 'luau.exe'))
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
[IO.Directory]::CreateDirectory((Join-Path $root 'build')) | Out-Null
$clientRoot = Join-Path $root 'src/client'
$runner = [Text.StringBuilder]::new()
[void]$runner.AppendLine('local sources = {}')
foreach ($file in (Get-ChildItem -Path $clientRoot -Recurse -Filter '*.luau' | Sort-Object FullName)) {
    $name = $file.FullName.Substring($clientRoot.Length + 1).Replace('\', '/')
    $source = [IO.File]::ReadAllText($file.FullName)
    if ($source.Contains(']====]')) { throw 'Unsupported long-string delimiter in source' }
    [void]$runner.AppendLine(('sources["{0}"] = [====[{1}]====]' -f $name, $source))
}
[void]$runner.AppendLine('require("../tests/ui_scale_and_theme")(sources)')
$path = Join-Path $root 'build/test_ui_scale_and_theme.luau'
[IO.File]::WriteAllText($path, $runner.ToString(), [Text.UTF8Encoding]::new($false))
& $LuauExe $path
exit $LASTEXITCODE
