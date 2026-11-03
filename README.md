# gytdlp

Eine kleine Windows-GUI zur Verwaltung von [yt-dlp](https://github.com/yt-dlp/yt-dlp).

## Installation

Entpacke das ZIP und starte `installer.bat`. Windows fragt nach Administratorrechten, weil gytdlp nach `%ProgramFiles%\gytdlp` kopiert wird. Das Installerfenster zeigt jeden Schritt und wartet bei Erfolg oder Fehler auf Enter. Python wird bei Bedarf von python.org installiert, `yt-dlp.exe` kommt aus den offiziellen GitHub-Releases. Der Installer trägt den Ordner in Benutzer- und System-PATH ein und erstellt den Befehl `gytdlp` für neu geöffnete CMD- und PowerShell-Fenster.

Danach startet die GUI mit `gytdlp` in neu geöffneten CMD- oder PowerShell-Fenstern. Die GUI prüft beim Start auf eine neue Version dieses Repositorys; über **gytdlp aktualisieren** wird der aktuelle Stand des Standardbranches installiert.

## Funktionen

- Video- und Playlist-URLs laden
- Zielordner auswählen
- bestes Video mit Audio, nur Video oder Audio als MP3
- yt-dlp und gytdlp manuell aktualisieren

Für MP3-Konvertierung muss FFmpeg installiert und im PATH verfügbar sein.
