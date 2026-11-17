$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

if (-not (Test-Path "logs")) { New-Item -ItemType Directory -Path "logs" | Out-Null }
if (-not (Test-Path "build")) { New-Item -ItemType Directory -Path "build" | Out-Null }

$logFile = Join-Path $projectRoot "logs\app.log"
"=== [Verify Run: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] ===" | Out-File -FilePath $logFile -Encoding utf8

function Write-Step {
    param([string]$Message)
    Write-Host $Message
    $Message | Out-File -FilePath $logFile -Append -Encoding utf8
}

function Fail-Verify {
    param([string]$Reason)
    $msg = "[FAIL] $Reason"
    Write-Host $msg -ForegroundColor Red
    $msg | Out-File -FilePath $logFile -Append -Encoding utf8
    exit 1
}

# 0. Dam bao bo cong cu da duoc tai day du
$rojoExe = Join-Path $projectRoot "tools\rojo.exe"
$luauLspExe = Join-Path $projectRoot "tools\luau-lsp.exe"
$globalTypes = Join-Path $projectRoot "tools\globalTypes.d.luau"
$seleneExe = Join-Path $projectRoot "tools\selene.exe"

if (-not (Test-Path $rojoExe)) {
    Fail-Verify "Khong tim thay tools\rojo.exe!"
}

if ((-not (Test-Path $luauLspExe)) -or (-not (Test-Path $globalTypes)) -or (-not (Test-Path $seleneExe))) {
    Write-Step "[0/6] Phat hien thieu cong cu kiem tra, dang tu dong cai dat..."
    & powershell -ExecutionPolicy Bypass -File (Join-Path $projectRoot "tools\install_tools.ps1")
    if ($LASTEXITCODE -ne 0) {
        Fail-Verify "Khong the tai bo cong cu kiem tra Luau."
    }
}

$luauFiles = @(Get-ChildItem -Path "src" -Recurse -Filter "*.luau" -File -ErrorAction SilentlyContinue)

# 1. Kiem tra gioi han <= 350 dong / file .luau
Write-Step "[1/6] Kiem tra gioi han kich thuoc file (<= 350 dong / file .luau)..."
$oversized = @()
foreach ($file in $luauFiles) {
    $lineCount = @(Get-Content -Path $file.FullName).Count
    if ($lineCount -gt 350) {
        $rel = $file.FullName.Substring($projectRoot.Length + 1)
        $oversized += "$rel ($lineCount dong > 350)"
    }
}
if ($oversized.Count -gt 0) {
    Fail-Verify ("Phat hien file vuot qua 350 dong:`n  - " + ($oversized -join "`n  - "))
}

# 2. Quet 5 loi chet nguoi Roblox Engine (Anti-Crash Scanner)
Write-Step "[2/6] Quet chan loi API Roblox nguy hiem (Part Shape, Terrain Material, Module return)..."
$badClassRegex = 'Instance\.new\(\s*["''](Ball|Cylinder|Block|Wedge)["'']\s*\)'
$terrainMatRegex = 'Enum\.Material\.(Water|Basalt|Snow|Glacier|Ground|LeafyGrass|Rock|Sandstone|CrackedLava|Mud|Salt|Limestone|Pavement)\b'
$placeholderRegex = '(rest of code|existing code unchanged)'

$violations = @()
foreach ($file in $luauFiles) {
    $rel = $file.FullName.Substring($projectRoot.Length + 1)
    $lines = @(Get-Content -Path $file.FullName)
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        $trimmed = $line.Trim()
        if ($trimmed -match $placeholderRegex) {
            $violations += "${rel}:$($i+1) Chua comment cat xen code bi cam: $trimmed"
        }
        if ($trimmed.StartsWith("--")) { continue }
        $codePart = ($line -split "--")[0]

        if ($codePart -match $badClassRegex) {
            $violations += "${rel}:$($i+1) Goi Instance.new sai ten class ('$($Matches[1])'). Dung Instance.new('Part') + Shape hoac WedgePart!"
        }
        if (($codePart -match $terrainMatRegex) -and ($codePart -notmatch "Terrain")) {
            $violations += "${rel}:$($i+1) Gan vat lieu chi danh cho Terrain ('Enum.Material.$($Matches[1])') len BasePart se gay crash Studio!"
        }
        if ($codePart -match 'CFrame\.Angles\(([^)]*)\)') {
            $argsText = $Matches[1].Trim()
            if (($argsText -ne "") -and ($argsText -notmatch "unpack") -and (($argsText -split ",").Count -lt 3)) {
                $violations += "${rel}:$($i+1) CFrame.Angles(...) truyen thieu tham so (bat buoc du 3 goc rx, ry, rz)!"
            }
        }
    }

    # ModuleScript phai co return o cuoi
    if (($file.Name -notlike "*.server.luau") -and ($file.Name -notlike "*.client.luau")) {
        $nonEmpty = @($lines | Where-Object { $_.Trim() -ne "" -and (-not $_.Trim().StartsWith("--")) })
        if ($nonEmpty.Count -eq 0 -or ($nonEmpty[-1] -notmatch '^\s*return\b')) {
            $violations += "${rel}: ModuleScript bat buoc phai ket thuc bang cau lenh 'return ...'!"
        }
    }
}

if ($violations.Count -gt 0) {
    Fail-Verify ("Phat hien vi pham quy tac an toan Roblox:`n  - " + ($violations -join "`n  - "))
}

# 3. Sinh Rojo Sourcemap
Write-Step "[3/6] Sinh Rojo sourcemap (build\sourcemap.json)..."
$smOut = & $rojoExe sourcemap "default.project.json" -o "build\sourcemap.json" 2>&1
if ($LASTEXITCODE -ne 0) {
    $smOut | Out-File -FilePath $logFile -Append -Encoding utf8
    Fail-Verify "Rojo sourcemap that bai: $smOut"
}

if ($luauFiles.Count -gt 0) {
    # 4. Luau-LSP Analyze voi tu dien API chinh chu cua Roblox
    Write-Step "[4/6] Chay luau-lsp analyze (kiem tra kieu & API Roblox chinh chu)..."
    $lspOut = & $luauLspExe analyze "--definitions=$globalTypes" "--sourcemap=build\sourcemap.json" "src" 2>&1
    if ($LASTEXITCODE -ne 0) {
        $lspOut | Out-File -FilePath $logFile -Append -Encoding utf8
        Write-Host ($lspOut | Out-String) -ForegroundColor Red
        Fail-Verify "luau-lsp phat hien loi code/API Roblox!"
    }

    # 5. Selene Linter
    Write-Step "[5/6] Chay selene linter (kiem tra bien thua / bien chua khai bao)..."
    if (-not (Test-Path (Join-Path $projectRoot "roblox.yml"))) {
        & $seleneExe generate-roblox-std | Out-Null
    }
    $selOut = & $seleneExe "src" 2>&1
    if ($LASTEXITCODE -ne 0) {
        $selOut | Out-File -FilePath $logFile -Append -Encoding utf8
        Write-Host ($selOut | Out-String) -ForegroundColor Red
        Fail-Verify "selene phat hien loi linter trong src/!"
    }
} else {
    Write-Step "[4/6] Bo qua luau-lsp analyze (src/ chua co file .luau)."
    Write-Step "[5/6] Bo qua selene linter (src/ chua co file .luau)."
}

# 6. Rojo Build .rbxlx
Write-Step "[6/6] Dong goi file Roblox Studio (build\mighty-angler-dev.rbxlx)..."
$buildOut = & $rojoExe build "default.project.json" -o "build\mighty-angler-dev.rbxlx" 2>&1
if ($LASTEXITCODE -ne 0) {
    $buildOut | Out-File -FilePath $logFile -Append -Encoding utf8
    Fail-Verify "Rojo build that bai: $buildOut"
}

Write-Step "[PASS] Hoan tat 6/6 chot chan kiem dinh! File build\mighty-angler-dev.rbxlx san sang."
exit 0
