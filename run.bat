@echo off
chcp 65001 >nul
cd /d "%~dp0"
title Mighty Angler v2 - Rojo Dev Sync

if not exist "logs" mkdir "logs"
if not exist "build" mkdir "build"

if not exist "tools\rojo.exe" (
    echo [Loi] Khong tim thay tools\rojo.exe trong thu muc du an.
    echo Hay mo Antigravity hoac Codex va nhan: "Khoi phuc tools\rojo.exe giup minh"
    pause
    exit /b 1
)

echo [1/2] Dang dong goi ban game moi nhat ra build\mighty-angler-dev.rbxlx ...
"tools\rojo.exe" build "default.project.json" -o "build\mighty-angler-dev.rbxlx" > "logs\app.log" 2>&1
if errorlevel 1 (
    echo.
    echo [Loi] Khong the dong goi du an Roblox. Chi tiet loi:
    type "logs\app.log"
    echo.
    echo Hay mo Antigravity hoac Codex va nhan: "Doc file logs/app.log va sua loi giup minh"
    pause
    exit /b 1
)

for /f "tokens=5" %%a in ('netstat -aon ^| findstr ":34872 " ^| findstr "LISTENING"') do (
    taskkill /f /pid %%a >nul 2>&1
)

echo [2/2] Dang bat Rojo Live Sync (cong 34872)...
echo   - Cach 1 (Dong bo song): Trong Roblox Studio chon Plugins -^> Rojo -^> Connect.
echo   - Cach 2 (Mo nhanh): Mo file build\mighty-angler-dev.rbxlx trong Studio roi bam Play (F5).
echo   - Nhan Ctrl+C hoac dong cua so nay khi khong dung nua.
echo.

"tools\rojo.exe" serve "default.project.json" 2>> "logs\app.log"
if errorlevel 1 (
    echo.
    echo [Canh bao] Rojo Live Sync vua dung vi gap loi.
    echo Hay mo Antigravity hoac Codex va nhan: "Doc file logs/app.log va sua loi giup minh"
    pause
)
