# gytdlp

Eine kleine Windows-GUI zur Verwaltung von [yt-dlp](https://github.com/yt-dlp/yt-dlp).

## Installation

Entpacke das ZIP und starte `installer.bat`. Das Skript installiert Python, falls `py` noch nicht verfügbar ist, kopiert gytdlp nach `%ProgramFiles%\gytdlp`, trägt diesen Ordner in den Benutzer-PATH ein und lädt `yt-dlp.exe` aus den offiziellen GitHub-Releases. Es benötigt Internetzugriff. Für `%ProgramFiles%` gelten die Schreibrechte des angemeldeten Benutzers; falls Windows den Zugriff verweigert, starte die BAT mit passenden Rechten.

Danach startet die GUI mit `gytdlp` in neu geöffneten CMD- oder PowerShell-Fenstern. Die GUI prüft beim Start auf eine neue Version dieses Repositorys; über **gytdlp aktualisieren** wird der aktuelle Stand des `main`-Branches installiert.

## Funktionen

- Video- und Playlist-URLs laden
- Zielordner auswählen
- bestes Video mit Audio, nur Video oder Audio als MP3
- yt-dlp und gytdlp manuell aktualisieren

Für MP3-Konvertierung muss FFmpeg installiert und im PATH verfügbar sein.
