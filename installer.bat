@echo off
setlocal
title gytdlp Installer
for %%I in ("%~dp0.") do set "SCRIPT_DIR=%%~fI"
powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%SCRIPT_DIR%\installer.ps1" -Source "%SCRIPT_DIR%"
endlocal
