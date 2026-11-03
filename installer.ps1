param([Parameter(Mandatory=$true)][string]$Source)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$InstallDir = Join-Path $env:ProgramFiles 'gytdlp'

function Write-Step([string]$Message) { Write-Host "`n==> $Message" -ForegroundColor Cyan }
function Fail([string]$Message) { Write-Host "FEHLER: $Message" -ForegroundColor Red; Read-Host 'Enter zum Schliessen'; exit 1 }

try {
    $Source = (Resolve-Path -LiteralPath $Source).Path
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Host 'Windows fragt jetzt nach Administratorrechten fuer die Installation in Programme.' -ForegroundColor Yellow
        $args = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Source `"$Source`""
        Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $args
        exit 0
    }

    Write-Host 'gytdlp wird installiert. Dieses Fenster bleibt offen und zeigt den Fortschritt.' -ForegroundColor Green
    $py = Get-Command py.exe -ErrorAction SilentlyContinue
    if (-not $py) {
        Write-Step 'Python von python.org laden und installieren'
        $html = (Invoke-WebRequest 'https://www.python.org/ftp/python/3.13/' -UseBasicParsing).Content
        $versions = [regex]::Matches($html, 'href="(3\.13\.\d+/)"') | ForEach-Object { $_.Groups[1].Value.TrimEnd('/') } | Sort-Object { [version]$_ } -Descending
        if (-not $versions) { throw 'Die Python-Versionen auf python.org konnten nicht ermittelt werden.' }
        $version = $versions[0]
        $pythonInstaller = Join-Path $env:TEMP 'gytdlp-python-installer.exe'
        $pythonUrl = "https://www.python.org/ftp/python/$version/python-$version-amd64.exe"
        Write-Host "Lade $pythonUrl"
        Invoke-WebRequest $pythonUrl -OutFile $pythonInstaller -UseBasicParsing
        $process = Start-Process -FilePath $pythonInstaller -ArgumentList '/quiet InstallAllUsers=0 PrependPath=1 Include_launcher=1 Include_test=0' -Wait -PassThru
        Remove-Item $pythonInstaller -Force -ErrorAction SilentlyContinue
        if ($process.ExitCode -ne 0) { throw "Der Python-Installer wurde mit Code $($process.ExitCode) beendet." }
        $launcher = Join-Path $env:LOCALAPPDATA 'Programs\Python\Launcher\py.exe'
        if (Test-Path $launcher) { $py = [pscustomobject]@{ Source = $launcher } }
        else { $py = Get-Command py.exe -ErrorAction SilentlyContinue }
        if (-not $py) { throw 'Python wurde installiert, aber der Python-Launcher py.exe wurde nicht gefunden.' }
    } else { $launcher = $py.Source }
    if (-not $launcher) { $launcher = Join-Path $env:LOCALAPPDATA 'Programs\Python\Launcher\py.exe' }
    $pythonExe = & $launcher -3 -c 'import sys; print(sys.executable)'
    if ($LASTEXITCODE -ne 0 -or -not $pythonExe) { throw 'Python konnte nach der Installation nicht gestartet werden.' }
    $pythonw = Join-Path (Split-Path $pythonExe.Trim()) 'pythonw.exe'
    if (-not (Test-Path -LiteralPath $pythonw)) { throw 'pythonw.exe fehlt; die GUI kann nicht ohne Konsolenfenster gestartet werden.' }

    Write-Step "Dateien nach $InstallDir kopieren"
    New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
    foreach ($name in @('app.py', 'README.md', 'installer.bat', 'installer.ps1')) {
        $file = Join-Path $Source $name
        if (-not (Test-Path -LiteralPath $file)) { throw "Datei fehlt im entpackten ZIP: $name" }
        Copy-Item -LiteralPath $file -Destination $InstallDir -Force
    }
    $acl = Get-Acl -LiteralPath $InstallDir
    $rule = [Security.AccessControl.FileSystemAccessRule]::new($identity.Name, 'Modify', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
    $acl.SetAccessRule($rule)
    Set-Acl -LiteralPath $InstallDir -AclObject $acl

    Write-Step 'gytdlp zum Benutzer-PATH hinzufuegen'
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $entries = @($userPath -split ';' | Where-Object { $_ })
    if ($entries -notcontains $InstallDir) {
        [Environment]::SetEnvironmentVariable('Path', (($entries + $InstallDir) -join ';'), 'User')
    }
    $launcherCmd = Join-Path $InstallDir 'gytdlp.cmd'
    Set-Content -LiteralPath $launcherCmd -Encoding ASCII -Value ('@echo off' + [Environment]::NewLine + 'start "" "' + $pythonw + '" "' + (Join-Path $InstallDir 'app.py') + '" %*')

    Write-Step 'yt-dlp von den offiziellen GitHub-Releases laden'
    $ytdlpDir = Join-Path $InstallDir 'ytdlp'
    New-Item -ItemType Directory -Force -Path $ytdlpDir | Out-Null
    $ytdlpFile = Join-Path $ytdlpDir 'yt-dlp.exe'
    Invoke-WebRequest 'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe' -OutFile $ytdlpFile -UseBasicParsing
    if ((Get-Item -LiteralPath $ytdlpFile).Length -lt 1000000) { throw 'Die heruntergeladene yt-dlp.exe ist unvollstaendig.' }
    Set-Content -LiteralPath (Join-Path $InstallDir '.gytdlp-commit') -Value 'installed' -Encoding ASCII

    Write-Host "`nInstallation abgeschlossen: $InstallDir" -ForegroundColor Green
    Write-Host 'Starte gytdlp...'
    Start-Process -FilePath $pythonw -ArgumentList ('"' + (Join-Path $InstallDir 'app.py') + '"')
    Write-Host 'PATH ist gesetzt. Oeffne neue CMD- oder PowerShell-Fenster, damit gytdlp dort verfuegbar ist.'
    Read-Host 'Enter zum Schliessen'
} catch {
    Fail $_.Exception.Message
}
