@echo off
rem Stops ComfyUI (and closes its window) to free the GPU memory it was using.
powershell -NoProfile -Command ^
  "$p = Get-CimInstance Win32_Process -Filter \"Name='python.exe'\" | Where-Object { $_.CommandLine -match 'ComfyUI[\\/]main\.py' };" ^
  "if (-not $p) { Write-Host 'ComfyUI was not running.'; exit }" ^
  "foreach ($x in $p) { $parent = Get-CimInstance Win32_Process -Filter \"ProcessId=$($x.ParentProcessId)\";" ^
  "  if ($parent -and $parent.CommandLine -like '*Start ComfyUI.bat*') { taskkill /PID $parent.ProcessId /T /F | Out-Null } else { taskkill /PID $x.ProcessId /T /F | Out-Null } }" ^
  "Write-Host 'ComfyUI stopped.'"
timeout /t 2 >nul
