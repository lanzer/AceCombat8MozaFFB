@echo off
rem Starts AceBridge. Works from the release zip (AceBridge\AceBridge.exe next to this file)
rem and from the repo after running scripts\build.ps1 (release\AceFFB-*\AceBridge\AceBridge.exe).
rem Extra arguments are passed through, e.g.:  Start-AceBridge.cmd --vib 0.8 --stall-kmh 180
title AceBridge (AC8 -^> MOZA Cockpit)
setlocal
set "EXE=%~dp0AceBridge\AceBridge.exe"
if not exist "%EXE%" for /d %%D in ("%~dp0..\release\AceFFB-*") do if exist "%%D\AceBridge\AceBridge.exe" set "EXE=%%D\AceBridge\AceBridge.exe"
if not exist "%EXE%" (
  echo AceBridge.exe not found. Build it first:  powershell -ExecutionPolicy Bypass -File scripts\build.ps1
  pause
  exit /b 1
)
"%EXE%" %*
pause
