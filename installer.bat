@echo off
setlocal EnableExtensions
title gytdlp Installer
echo ======================================
echo          gytdlp Installer
echo ======================================
set "SOURCE=%~dp0"
set "INSTALL_DIR=%ProgramFiles%\gytdlp"

net session >nul 2>nul
if errorlevel 1 (
  echo Fuer die Installation nach Programme werden Administratorrechte benoetigt.
  powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)

where py >nul 2>nul
if errorlevel 1 (
  echo Python wird von python.org geladen und installiert...
  powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $html=(Invoke-WebRequest 'https://www.python.org/ftp/python/3.13/' -UseBasicParsing).Content; $versions=[regex]::Matches($html,'href="(3\.13\.\d+/)"') | ForEach-Object { $_.Groups[1].Value.TrimEnd('/') } | Sort-Object {[version]$_} -Descending; if(-not $versions){throw 'Python-Version konnte nicht ermittelt werden'}; $v=$versions[0]; $url='https://www.python.org/ftp/python/'+$v+'/python-'+$v+'-amd64.exe'; $installer=Join-Path $env:TEMP 'gytdlp-python-installer.exe'; Invoke-WebRequest $url -OutFile $installer; Start-Process $installer -ArgumentList '/quiet InstallAllUsers=0 PrependPath=1 Include_launcher=1 Include_test=0' -Wait; Remove-Item $installer -Force"
  if errorlevel 1 (echo Python-Installation fehlgeschlagen.& pause& exit /b 1)
)

echo Installiere gytdlp nach "%INSTALL_DIR%"...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; New-Item -ItemType Directory -Force -Path $env:INSTALL_DIR | Out-Null; Copy-Item -Path (Join-Path $env:SOURCE '*') -Destination $env:INSTALL_DIR -Recurse -Force; $acl=Get-Acl $env:INSTALL_DIR; $rule=New-Object System.Security.AccessControl.FileSystemAccessRule([System.Security.Principal.WindowsIdentity]::GetCurrent().Name,'Modify','ContainerInherit,ObjectInherit','None','Allow'); $acl.SetAccessRule($rule); Set-Acl -Path $env:INSTALL_DIR -AclObject $acl; $p=[Environment]::GetEnvironmentVariable('Path','User'); $bin=$env:INSTALL_DIR; $entries=@($p -split ';' | Where-Object {$_}); if($entries -notcontains $bin){[Environment]::SetEnvironmentVariable('Path', (($entries + $bin) -join ';'),'User')}; $launcher=Join-Path $bin 'gytdlp.cmd'; Set-Content -LiteralPath $launcher -Value ('@echo off' + [Environment]::NewLine + 'py -3 "' + (Join-Path $bin 'app.py') + '" %*') -Encoding ASCII; Set-Content -LiteralPath (Join-Path $bin '.gytdlp-commit') -Value 'installed' -Encoding ASCII"
if errorlevel 1 (echo Installation fehlgeschlagen. Bitte BAT als normaler Benutzer starten.& pause& exit /b 1)

echo Lade yt-dlp aus den offiziellen GitHub-Releases...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $dir=Join-Path $env:INSTALL_DIR 'ytdlp'; New-Item -ItemType Directory -Force -Path $dir | Out-Null; Invoke-WebRequest 'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe' -OutFile (Join-Path $dir 'yt-dlp.exe') -UseBasicParsing"
if errorlevel 1 (echo yt-dlp konnte nicht geladen werden. In der GUI kann das Update erneut versucht werden.)
echo.
echo Fertig. Starte gytdlp...
start "" "%INSTALL_DIR%\gytdlp.cmd"
echo PATH-Aenderungen gelten in neu geoeffneten CMD- und PowerShell-Fenstern.
pause
endlocal
