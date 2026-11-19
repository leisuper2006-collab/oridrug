@echo off
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start-OriDrug.ps1" -Stop %*
if errorlevel 1 (
  pause
  exit /b 1
)
