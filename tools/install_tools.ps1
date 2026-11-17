$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression

$projectRoot = Split-Path -Parent $PSScriptRoot
$toolsDir = Join-Path $projectRoot "tools"

if (-not (Test-Path $toolsDir)) {
    New-Item -ItemType Directory -Path $toolsDir | Out-Null
}

function Install-ZipEntryFromUrl {
    param(
        [string]$Url,
        [string]$EntryFilter,
        [string]$DestinationPath
    )
    Write-Host "[Tools] Dang tai $Url ..."
    $bytes = (Invoke-WebRequest -Uri $Url -UseBasicParsing).Content
    $stream = New-Object System.IO.MemoryStream(,$bytes)
    $zip = New-Object System.IO.Compression.ZipArchive($stream, [System.IO.Compression.ZipArchiveMode]::Read)
    try {
        $entry = $zip.Entries | Where-Object { $_.Name -like $EntryFilter } | Select-Object -First 1
        if (-not $entry) {
            throw "Khong tim thay file $EntryFilter trong goi tai ve tu $Url"
        }
        $entryStream = $entry.Open()
        $fileStream = [System.IO.File]::Create($DestinationPath)
        try {
            $entryStream.CopyTo($fileStream)
        } finally {
            $fileStream.Dispose()
            $entryStream.Dispose()
        }
    } finally {
        $zip.Dispose()
        $stream.Dispose()
    }
}

# 1. luau-lsp.exe
$luauLspPath = Join-Path $toolsDir "luau-lsp.exe"
if (-not (Test-Path $luauLspPath)) {
    $lspRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/JohnnyMorganz/luau-lsp/releases/latest"
    $lspAsset = $lspRelease.assets | Where-Object { $_.name -match "win64\.zip$" } | Select-Object -First 1
    Install-ZipEntryFromUrl -Url $lspAsset.browser_download_url -EntryFilter "luau-lsp.exe" -DestinationPath $luauLspPath
    Write-Host "[Tools] Da cai dat luau-lsp $($lspRelease.tag_name)"
} else {
    Write-Host "[Tools] luau-lsp.exe da san sang."
}

# 2. globalTypes.d.luau (Tu dien API chinh chu cua Roblox Engine)
$globalTypesPath = Join-Path $toolsDir "globalTypes.d.luau"
if (-not (Test-Path $globalTypesPath)) {
    $typesUrl = "https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau"
    Write-Host "[Tools] Dang tai tu dien API Roblox (globalTypes.d.luau) ..."
    Invoke-WebRequest -Uri $typesUrl -OutFile $globalTypesPath -UseBasicParsing
    Write-Host "[Tools] Da tai xong globalTypes.d.luau"
} else {
    Write-Host "[Tools] globalTypes.d.luau da san sang."
}

# 3. selene.exe
$selenePath = Join-Path $toolsDir "selene.exe"
if (-not (Test-Path $selenePath)) {
    $seleneRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/Kampfkarren/selene/releases/latest"
    $seleneAsset = $seleneRelease.assets | Where-Object { $_.name -match "windows\.zip$" } | Select-Object -First 1
    Install-ZipEntryFromUrl -Url $seleneAsset.browser_download_url -EntryFilter "selene.exe" -DestinationPath $selenePath
    Write-Host "[Tools] Da cai dat selene $($seleneRelease.tag_name)"
} else {
    Write-Host "[Tools] selene.exe da san sang."
}

Write-Host "[Tools] Hoan tat kiem tra bo cong cu Vibe Code Roblox!"
