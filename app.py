"""gytdlp - a small Windows GUI for managing yt-dlp."""
from __future__ import annotations

import json
import os
import queue
import shutil
import subprocess
import sys
import threading
import urllib.error
import urllib.request
import zipfile
from pathlib import Path
import tkinter as tk
from tkinter import filedialog, messagebox, ttk

APP = "gytdlp"
REPO = "tammo2701/gytdlp"
YTDLP_REPO = "yt-dlp/yt-dlp"
INSTALL_DIR = Path(os.environ.get("ProgramFiles", r"C:\Program Files")) / APP
APP_DIR = Path(__file__).resolve().parent
YTDLP_EXE = INSTALL_DIR / "ytdlp" / "yt-dlp.exe"
USER_AGENT = "gytdlp/1.0 (Windows desktop app)"


def http_json(url: str):
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT, "Accept": "application/vnd.github+json"})
    with urllib.request.urlopen(req, timeout=25) as response:
        return json.load(response)


class App(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("gytdlp – yt-dlp Verwaltung")
        self.geometry("760x550")
        self.minsize(650, 460)
        self.events: queue.Queue = queue.Queue()
        self.busy = False
        self.url = tk.StringVar()
        self.dest = tk.StringVar(value=str(Path.home() / "Downloads"))
        self.format = tk.StringVar(value="Bestes Video + Audio")
        self.status = tk.StringVar(value="Bereit")
        self._build()
        self.after(120, self._drain)
        self.after(700, self.check_updates)

    def _build(self):
        root = ttk.Frame(self, padding=18)
        root.pack(fill="both", expand=True)
        ttk.Label(root, text="gytdlp", font=("Segoe UI", 22, "bold")).pack(anchor="w")
        ttk.Label(root, text="YouTube-Downloads mit yt-dlp verwalten", foreground="#555").pack(anchor="w", pady=(0, 18))
        ttk.Label(root, text="Video- oder Playlist-URL").pack(anchor="w")
        ttk.Entry(root, textvariable=self.url).pack(fill="x", pady=(4, 12))
        ttk.Label(root, text="Speicherort").pack(anchor="w")
        row = ttk.Frame(root)
        row.pack(fill="x", pady=(4, 12))
        ttk.Entry(row, textvariable=self.dest).pack(side="left", fill="x", expand=True)
        ttk.Button(row, text="Auswählen…", command=self.choose_dir).pack(side="left", padx=(8, 0))
        ttk.Label(root, text="Format").pack(anchor="w")
        ttk.Combobox(root, textvariable=self.format, state="readonly", values=["Bestes Video + Audio", "Nur Video", "Nur Audio (MP3)" ]).pack(fill="x", pady=(4, 14))
        actions = ttk.Frame(root)
        actions.pack(fill="x")
        self.download_btn = ttk.Button(actions, text="Download starten", command=self.download)
        self.download_btn.pack(side="left")
        ttk.Button(actions, text="yt-dlp aktualisieren", command=self.update_ytdlp).pack(side="left", padx=8)
        ttk.Button(actions, text="gytdlp aktualisieren", command=self.update_app).pack(side="left")
        ttk.Separator(root).pack(fill="x", pady=14)
        ttk.Label(root, text="Ausgabe").pack(anchor="w")
        self.log = tk.Text(root, height=12, wrap="word", state="disabled", font=("Consolas", 9))
        self.log.pack(fill="both", expand=True, pady=(5, 8))
        ttk.Label(root, textvariable=self.status).pack(anchor="w")

    def choose_dir(self):
        chosen = filedialog.askdirectory(initialdir=self.dest.get())
        if chosen:
            self.dest.set(chosen)

    def write_log(self, text: str):
        self.log.configure(state="normal")
        self.log.insert("end", text.rstrip() + "\n")
        self.log.see("end")
        self.log.configure(state="disabled")

    def task(self, label, fn):
        if self.busy:
            return
        self.busy = True
        self.status.set(label)
        self.download_btn.configure(state="disabled")
        def run():
            try:
                fn()
                self.events.put(("done", label + " abgeschlossen"))
            except Exception as exc:
                self.events.put(("error", f"{label} fehlgeschlagen: {exc}"))
        threading.Thread(target=run, daemon=True).start()

    def _drain(self):
        try:
            while True:
                kind, value = self.events.get_nowait()
                if kind == "log":
                    self.write_log(value)
                elif kind == "done":
                    self.busy = False
                    self.download_btn.configure(state="normal")
                    self.status.set(value)
                    self.write_log(value)
                elif kind == "error":
                    self.busy = False
                    self.download_btn.configure(state="normal")
                    self.status.set("Fehler")
                    self.write_log(value)
                    messagebox.showerror("gytdlp", value)
        except queue.Empty:
            pass
        self.after(120, self._drain)

    def download(self):
        url = self.url.get().strip()
        if not url:
            messagebox.showinfo("gytdlp", "Bitte zuerst eine URL eingeben.")
            return
        if not YTDLP_EXE.exists():
            messagebox.showinfo("gytdlp", "yt-dlp fehlt. Bitte zuerst ‚yt-dlp aktualisieren‘ wählen.")
            return
        dest = Path(self.dest.get()).expanduser()
        mode = self.format.get()
        args = [str(YTDLP_EXE), "--newline", "--progress", "-P", str(dest), "-o", "%(title)s.%(ext)s"]
        if mode == "Nur Audio (MP3)":
            args += ["-x", "--audio-format", "mp3"]
        elif mode == "Nur Video":
            args += ["-f", "bestvideo"]
        else:
            args += ["-f", "bv*+ba/b"]
        args.append(url)
        def run():
            dest.mkdir(parents=True, exist_ok=True)
            self.events.put(("log", "Starte yt-dlp…"))
            proc = subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, encoding="utf-8", errors="replace", creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
            assert proc.stdout
            for line in proc.stdout:
                self.events.put(("log", line.rstrip()))
            if proc.wait() != 0:
                raise RuntimeError("yt-dlp hat einen Fehler gemeldet. Details stehen in der Ausgabe.")
        self.task("Download", run)

    def update_ytdlp(self):
        def run():
            release = http_json(f"https://api.github.com/repos/{YTDLP_REPO}/releases/latest")
            asset = next((a for a in release.get("assets", []) if a["name"] == "yt-dlp.exe"), None)
            if not asset:
                raise RuntimeError("Kein yt-dlp.exe in der neuesten GitHub-Version gefunden.")
            target = INSTALL_DIR / "ytdlp" / "yt-dlp.exe"
            target.parent.mkdir(parents=True, exist_ok=True)
            self.events.put(("log", f"Lade yt-dlp {release.get('tag_name', '')}…"))
            req = urllib.request.Request(asset["browser_download_url"], headers={"User-Agent": USER_AGENT})
            with urllib.request.urlopen(req, timeout=60) as response, target.with_suffix(".exe.tmp").open("wb") as out:
                shutil.copyfileobj(response, out)
            target.with_suffix(".exe.tmp").replace(target)
            self.events.put(("log", f"yt-dlp {release.get('tag_name', '')} installiert."))
        self.task("yt-dlp-Update", run)

    def check_updates(self):
        def check():
            try:
                repo = http_json(f"https://api.github.com/repos/{REPO}")
                data = http_json(f"https://api.github.com/repos/{REPO}/commits/{repo['default_branch']}")
                remote = data["sha"]
                marker = INSTALL_DIR / ".gytdlp-commit"
                local = marker.read_text(encoding="utf-8").strip() if marker.exists() else ""
                if local and local != remote:
                    self.events.put(("log", "Eine neue gytdlp-Version ist verfügbar. Über ‚gytdlp aktualisieren‘ installieren."))
            except Exception as exc:
                self.events.put(("log", f"Update-Prüfung nicht möglich: {exc}"))
        threading.Thread(target=check, daemon=True).start()

    def update_app(self):
        def run():
            repo = http_json(f"https://api.github.com/repos/{REPO}")
            info = http_json(f"https://api.github.com/repos/{REPO}/commits/{repo['default_branch']}")
            sha = info["sha"]
            marker = INSTALL_DIR / ".gytdlp-commit"
            if marker.exists() and marker.read_text(encoding="utf-8").strip() == sha:
                self.events.put(("log", "gytdlp ist bereits aktuell."))
                return
            INSTALL_DIR.mkdir(parents=True, exist_ok=True)
            archive = INSTALL_DIR / "gytdlp-update.zip"
            req = urllib.request.Request(f"https://github.com/{REPO}/archive/{sha}.zip", headers={"User-Agent": USER_AGENT})
            with urllib.request.urlopen(req, timeout=60) as response, archive.open("wb") as out:
                shutil.copyfileobj(response, out)
            stage = INSTALL_DIR / "update-staging"
            if stage.exists():
                shutil.rmtree(stage)
            stage.mkdir()
            with zipfile.ZipFile(archive) as zf:
                zf.extractall(stage)
            source_root = next(stage.iterdir())
            for name in ("app.py", "README.md", "installer.bat"):
                src = source_root / name
                if src.exists():
                    shutil.copy2(src, INSTALL_DIR / name)
            marker.write_text(sha, encoding="utf-8")
            archive.unlink(missing_ok=True)
            shutil.rmtree(stage, ignore_errors=True)
            self.events.put(("log", "Update geladen. Anwendung wird neu gestartet."))
            relaunch = INSTALL_DIR / "restart-gytdlp.bat"
            relaunch.write_text(f'@echo off\r\ntimeout /t 2 /nobreak >nul\r\nstart "" "{sys.executable}" "{INSTALL_DIR / "app.py"}"\r\ndel "%~f0"\r\n', encoding="utf-8")
            subprocess.Popen(["cmd.exe", "/c", str(relaunch)], creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
            self.after(300, self.destroy)
        self.task("gytdlp-Update", run)


if __name__ == "__main__":
    App().mainloop()
