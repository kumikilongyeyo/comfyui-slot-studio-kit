@echo off
rem Double-click to install. Options work too, e.g.:  install.bat -Only image -InstallDir D:\AI
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*
pause
