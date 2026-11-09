@echo off
rem Opens Slot Studio (the simple image page). Starts ComfyUI first if it is not running.
cd /d "%~dp0"
set URL=http://127.0.0.1:8188/extensions/slot_studio_autoload/studio/index.html?v=%RANDOM%%RANDOM%
powershell -NoProfile -Command "if (Get-NetTCPConnection -LocalPort 8188 -State Listen -ErrorAction SilentlyContinue) { exit 0 } else { exit 1 }"
if %errorlevel%==0 (
    start "" %URL%
    exit /b
)
echo Starting ComfyUI first, Slot Studio opens when it is ready (about 20-40 s)...
start "ComfyUI" /min "%~dp0Start ComfyUI.bat"
powershell -NoProfile -Command "for ($i=0; $i -lt 120; $i++) { if (Get-NetTCPConnection -LocalPort 8188 -State Listen -ErrorAction SilentlyContinue) { exit 0 }; Start-Sleep 2 }; exit 1"
start "" %URL%
