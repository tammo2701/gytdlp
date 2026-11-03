@echo off
setlocal
title gytdlp Installer
echo Starte den gytdlp Installer...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0installer.ps1" -Source "%~dp0"
if errorlevel 1 (
  echo.
  echo Die Installation ist fehlgeschlagen. Die genaue Fehlermeldung steht oben.
  pause
  exit /b 1
)
endlocal
