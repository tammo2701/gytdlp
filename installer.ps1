param([Parameter(Mandatory=$true)][string]$Source)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$InstallDir = Join-Path $env:ProgramFiles 'gytdlp'

function Write-Step([string]$Message) {
    if ($script:statusLabel) {
        $script:statusLabel.Text = $Message
        [Windows.Forms.Application]::DoEvents()
    }
}
function Fail([string]$Message) {
    if ($script:form) {
        $script:progress.Style = 'Blocks'
        $script:progress.Value = 0
        $script:statusLabel.Text = 'Installation fehlgeschlagen'
        [Windows.Forms.MessageBox]::Show($script:form, $Message, 'gytdlp Installation', 'OK', 'Error') | Out-Null
        $script:form.Close()
    } else {
        [Windows.Forms.MessageBox]::Show($Message, 'gytdlp Installation', 'OK', 'Error') | Out-Null
    }
    exit 1
}

try {
    $Source = (Resolve-Path -LiteralPath $Source).Path
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        [Windows.Forms.MessageBox]::Show('Windows fragt jetzt nach Administratorrechten, damit gytdlp in Programme installiert werden kann.', 'gytdlp Installation', 'OK', 'Information') | Out-Null
        $scriptPath = $PSCommandPath.Replace("'", "''")
        $sourcePath = $Source.Replace("'", "''")
        $command = "& '$scriptPath' -Source '$sourcePath'"
        $encodedCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
        Start-Process -FilePath 'powershell.exe' -Verb RunAs -WindowStyle Hidden -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -EncodedCommand $encodedCommand"
        exit 0
    }

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    [Windows.Forms.Application]::EnableVisualStyles()
    $script:form = New-Object Windows.Forms.Form
    $script:form.Text = 'gytdlp installieren'
    $script:form.ClientSize = New-Object Drawing.Size(480, 150)
    $script:form.StartPosition = 'CenterScreen'
    $script:form.FormBorderStyle = 'FixedDialog'
    $script:form.MaximizeBox = $false
    $script:form.MinimizeBox = $false
    $script:form.BackColor = [Drawing.Color]::FromArgb(248, 250, 252)
    $script:statusLabel = New-Object Windows.Forms.Label
    $script:statusLabel.Location = New-Object Drawing.Point(24, 24)
    $script:statusLabel.Size = New-Object Drawing.Size(432, 28)
    $script:statusLabel.Font = New-Object Drawing.Font('Segoe UI', 10)
    $script:statusLabel.Text = 'Installation wird vorbereitet…'
    $script:form.Controls.Add($script:statusLabel)
    $script:progress = New-Object Windows.Forms.ProgressBar
    $script:progress.Location = New-Object Drawing.Point(24, 66)
    $script:progress.Size = New-Object Drawing.Size(432, 18)
    $script:progress.Style = 'Marquee'
    $script:progress.MarqueeAnimationSpeed = 25
    $script:form.Controls.Add($script:progress)
    $script:form.Show()
    [Windows.Forms.Application]::DoEvents()
    $py = Get-Command py.exe -ErrorAction SilentlyContinue
    if (-not $py) {
        Write-Step 'Python von python.org laden und installieren'
        $html = (Invoke-WebRequest 'https://www.python.org/ftp/python/3.13/' -UseBasicParsing).Content
        $versions = [regex]::Matches($html, 'href="(3\.13\.\d+/)"') | ForEach-Object { $_.Groups[1].Value.TrimEnd('/') } | Sort-Object { [version]$_ } -Descending
        if (-not $versions) { throw 'Die Python-Versionen auf python.org konnten nicht ermittelt werden.' }
        $version = $versions[0]
        $pythonInstaller = Join-Path $env:TEMP 'gytdlp-python-installer.exe'
        $pythonUrl = "https://www.python.org/ftp/python/$version/python-$version-amd64.exe"
        Write-Step 'Python wird von python.org heruntergeladen…'
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

    Write-Step 'gytdlp wird zum Benutzer- und System-PATH hinzugefügt…'
    foreach ($scope in @('User', 'Machine')) {
        $savedPath = [Environment]::GetEnvironmentVariable('Path', $scope)
        $entries = @($savedPath -split ';' | Where-Object { $_ })
        if (-not ($entries | Where-Object { $_.TrimEnd('\') -ieq $InstallDir.TrimEnd('\') })) {
            [Environment]::SetEnvironmentVariable('Path', (($entries + $InstallDir) -join ';'), $scope)
        }
    }
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
    $launcherCmd = Join-Path $InstallDir 'gytdlp.cmd'
    Set-Content -LiteralPath $launcherCmd -Encoding ASCII -Value ('@echo off' + [Environment]::NewLine + 'start "" "' + $pythonw + '" "' + (Join-Path $InstallDir 'app.py') + '" %*')

    Write-Step 'gytdlp in der Windows-Suche registrieren'
    $startMenu = Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs'
    New-Item -ItemType Directory -Force -Path $startMenu | Out-Null
    $shortcutPath = Join-Path $startMenu 'gytdlp.lnk'
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $pythonw
    $shortcut.Arguments = '"' + (Join-Path $InstallDir 'app.py') + '"'
    $shortcut.WorkingDirectory = $InstallDir
    $shortcut.Description = 'gytdlp – YouTube-Downloads verwalten'
    $shortcut.Save()

    Write-Step 'yt-dlp von den offiziellen GitHub-Releases laden'
    $ytdlpDir = Join-Path $InstallDir 'ytdlp'
    New-Item -ItemType Directory -Force -Path $ytdlpDir | Out-Null
    $ytdlpFile = Join-Path $ytdlpDir 'yt-dlp.exe'
    Invoke-WebRequest 'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe' -OutFile $ytdlpFile -UseBasicParsing
    if ((Get-Item -LiteralPath $ytdlpFile).Length -lt 1000000) { throw 'Die heruntergeladene yt-dlp.exe ist unvollstaendig.' }
    Set-Content -LiteralPath (Join-Path $InstallDir '.gytdlp-commit') -Value 'installed' -Encoding ASCII

    Write-Step 'Installation abgeschlossen. gytdlp wird gestartet…'
    Start-Process -FilePath $pythonw -ArgumentList ('"' + (Join-Path $InstallDir 'app.py') + '"')
    $script:progress.Style = 'Blocks'
    $script:progress.Value = 100
    Start-Sleep -Milliseconds 900
    $script:form.Close()
} catch {
    Fail $_.Exception.Message
}
