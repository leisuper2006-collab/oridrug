@echo off
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Check-OriDrug.ps1"
set "ORIDRUG_CHECK_EXIT=%errorlevel%"
echo.
pause
exit /b %ORIDRUG_CHECK_EXIT%
