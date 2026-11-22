# Quet truoc khi Publish: ID Gamepass/Developer Product/Group con = 0, co DEV dang bat, ma qua tang da het han.
# Exit 0 = san sang; exit 2 = CON MUC CHUA DIEN (bao dong, khong publish); exit 1 = loi doc cau hinh.
param([string]$SourceRoot = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = 'Stop'

function Read-Config([string]$Relative) {
    $path = Join-Path $SourceRoot $Relative
    if (-not (Test-Path -LiteralPath $path)) { throw "Missing config file: $Relative" }
    return [IO.File]::ReadAllText($path)
}

$blocking = [Collections.Generic.List[string]]::new()
$warnings = [Collections.Generic.List[string]]::new()
$okLines = [Collections.Generic.List[string]]::new()

function Scan-Ids([string]$Relative, [string]$Label) {
    $text = Read-Config $Relative
    $pattern = 'key\s*=\s*"(?<key>[A-Za-z0-9_]+)"(?:(?!key\s*=).)*?\bid\s*=\s*(?<id>-?\d+)'
    $found = [regex]::Matches($text, $pattern, [Text.RegularExpressions.RegexOptions]::Singleline)
    if ($found.Count -eq 0) { throw "No '$Label' entries could be parsed from $Relative" }
    foreach ($m in $found) {
        $key = $m.Groups['key'].Value
        $id = [long]$m.Groups['id'].Value
        if ($id -le 0) { $blocking.Add("$Label '$key' id = $id  ($Relative)") }
        else { $okLines.Add("$Label '$key' id = $id") }
    }
    return $found.Count
}

$passCount = Scan-Ids 'src/shared/Config/GamepassesConfig.luau' 'Gamepass'
$productCount = Scan-Ids 'src/shared/Config/DevProductsConfig.luau' 'DevProduct'

$game = Read-Config 'src/shared/Config/GameConfig.luau'
$group = [regex]::Match($game, 'GameConfig\.ROBLOX_GROUP_ID\s*=\s*(-?\d+)')
if (-not $group.Success) { throw 'GameConfig.ROBLOX_GROUP_ID not found' }
if ([long]$group.Groups[1].Value -le 0) { $blocking.Add("GameConfig.ROBLOX_GROUP_ID = $($group.Groups[1].Value)  (free Auto-Train group perk)") }
else { $okLines.Add("ROBLOX_GROUP_ID = $($group.Groups[1].Value)") }

foreach ($m in [regex]::Matches($game, '(?m)^\s*GameConfig\.(?<name>DEV_[A-Z0-9_]+)\s*=\s*true')) {
    $warnings.Add("GameConfig.$($m.Groups['name'].Value) = true (Studio-only; confirm it stays off in live servers)")
}

$codes = Read-Config 'src/shared/Config/CodesConfig.luau'
$now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
foreach ($m in [regex]::Matches($codes, 'code\s*=\s*"(?<code>[A-Z0-9]+)"[^\r\n]*?expiresAtUtc\s*=\s*(?<at>\d+)')) {
    if ([long]$m.Groups['at'].Value -le $now) { $warnings.Add("Code '$($m.Groups['code'].Value)' already expired (expiresAtUtc = $($m.Groups['at'].Value))") }
}

Write-Output "=== Mighty Angler launch readiness ($passCount gamepasses, $productCount dev products) ==="
foreach ($line in $okLines) { Write-Output "[OK]      $line" }
foreach ($line in $blocking) { Write-Output "[MISSING] $line" }
foreach ($line in $warnings) { Write-Output "[WARN]    $line" }
if ($blocking.Count -gt 0) {
    Write-Output "LAUNCH READINESS: NOT READY - $($blocking.Count) ID(s) still 0, $($warnings.Count) warning(s). Fill the real Roblox IDs before publishing."
    exit 2
}
Write-Output "LAUNCH READINESS: READY - all IDs filled, $($warnings.Count) warning(s) to review."
exit 0
