@echo off
setlocal
title gytdlp Installer
echo Starte den gytdlp Installer...
for %%I in ("%~dp0.") do set "SCRIPT_DIR=%%~fI"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%\installer.ps1" -Source "%SCRIPT_DIR%"
if errorlevel 1 (
  echo.
  echo Die Installation ist fehlgeschlagen. Die genaue Fehlermeldung steht oben.
  pause
  exit /b 1
)
endlocal
