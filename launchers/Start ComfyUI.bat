@echo off
rem Starts ComfyUI and opens it in your browser. If it is already running, just opens the browser.
title ComfyUI (close this window or run "Stop ComfyUI" to quit)
cd /d "%~dp0"

powershell -NoProfile -Command "if (Get-NetTCPConnection -LocalPort 8188 -State Listen -ErrorAction SilentlyContinue) { exit 0 } else { exit 1 }"
if %errorlevel%==0 (
    start "" http://127.0.0.1:8188
    exit /b
)

echo Starting ComfyUI... the browser opens by itself when it is ready.
echo To quit: close this window, or double-click "Stop ComfyUI".
echo.

rem Smart App Control can block a DLL the first time it is loaded, then allow it on the next try.
set tries=0
:run
.\python_embeded\python.exe -s ComfyUI\main.py --windows-standalone-build
set /a tries+=1
if %tries% lss 3 (
    echo.
    echo ComfyUI stopped unexpectedly ^(Windows may have blocked a file on first load^). Retrying...
    timeout /t 5 >nul
    goto run
)
echo.
echo ComfyUI could not start. Read the messages above.
pause
