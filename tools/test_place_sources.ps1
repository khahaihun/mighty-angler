param([string]$Place = 'build/mighty-angler-dev.rbxlx', [string]$SourceMap = 'build/sourcemap.json')
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
$map = Get-Content -Raw -LiteralPath $SourceMap | ConvertFrom-Json
$document = [xml][IO.File]::ReadAllText((Join-Path $root $Place))
$expected = @{}
function Walk-Map($Node, [string]$Prefix) {
 $path = if ($Prefix) { "$Prefix/$($Node.name)" } else { $Node.name }
 if ($Node.className -in @('Script','LocalScript','ModuleScript')) {
  $files=@($Node.filePaths | Where-Object { $_ -match '\.luau$' })
  if ($files.Count -ne 1) { throw "Expected one Luau source for $path" }
  $expected[$path]=@{File=$files[0];Class=$Node.className}
 }
 foreach ($child in $Node.children) { Walk-Map $child $path }
}
foreach ($child in $map.children) { Walk-Map $child '' }
$seen=@{}
function Walk-Place($Item,[string]$Prefix) {
 $name=$Item.SelectSingleNode('Properties/string[@name="Name"]').InnerText
 $path=if ($Prefix) { "$Prefix/$name" } else { $name }
 if ($Item.class -in @('Script','LocalScript','ModuleScript')) {
  if (-not $expected.ContainsKey($path)) { throw "Unexpected script in place: $path" }
  if ($seen.ContainsKey($path)) { throw "Duplicate script in place: $path" }
  $entry=$expected[$path]
  if ($entry.Class -ne $Item.class) { throw "Class mismatch: $path" }
  $source=$Item.SelectSingleNode('Properties/*[@name="Source"]')
  if ($null -eq $source) { throw "Missing Source: $path" }
  $disk=[IO.File]::ReadAllText((Join-Path $root $entry.File)).Replace("`r`n","`n").Replace("`r","`n")
  if ($source.InnerText -cne $disk) { throw "Source mismatch: $path ($($entry.File))" }
  $seen[$path]=$true
 }
 foreach ($child in $Item.SelectNodes('Item')) { Walk-Place $child $path }
}
foreach ($item in $document.roblox.Item) { Walk-Place $item '' }
if ($seen.Count -ne $expected.Count) { throw "Missing scripts: expected $($expected.Count), got $($seen.Count)" }
$sourceFiles=@(Get-ChildItem src -Recurse -File -Filter '*.luau')
if ($sourceFiles.Count -ne $expected.Count) { throw 'Some source files are not represented in sourcemap' }
Write-Output "PASS place sources: $($seen.Count)/$($expected.Count) scripts match source/class/path (XML line endings normalized)"
Write-Output ('SHA256 '+(Get-FileHash -LiteralPath $Place -Algorithm SHA256).Hash)
