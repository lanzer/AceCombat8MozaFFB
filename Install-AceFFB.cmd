@echo off
rem Double-click to run the AceFFB installer. It runs scripts\Install-AceFFB.ps1 with Windows PowerShell
rem (execution policy bypassed for this run only) and asks for administrator rights itself
rem when the game folder needs them. Extra arguments are passed through, e.g. -DryRun
title AceFFB installer
setlocal
cd /d "%~dp0"
if not exist "%~dp0scripts\Install-AceFFB.ps1" goto missing
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Install-AceFFB.ps1" -FromCmd %*
echo.
pause
exit /b 0
:missing
echo scripts\Install-AceFFB.ps1 was not found next to this file.
echo Extract the WHOLE AceFFB zip to a folder first, then double-click Install-AceFFB.cmd there.
pause
exit /b 1
