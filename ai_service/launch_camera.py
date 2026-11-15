"""Launch REAL MediaPipe recognition automatically from the Godot chronology puzzle.

Writes a diagnostic log even if Python packages, the model, or the webcam fail.
No keyboard simulation is silently substituted for actual AI recognition.
"""
from __future__ import annotations

from datetime import datetime
from pathlib import Path
import contextlib
import importlib.util
import os
import platform
import subprocess
import sys
import traceback

ROOT = Path(__file__).resolve().parent
REPORT = ROOT / "camera_diagnostics.txt"

def log(out, msg: str) -> None:
    out.write(msg + "\n")
    out.flush()
    # Important: progress must be visible in the console too.
    # Previously all stdout went to the log so users saw an empty black cmd window.
    if sys.__stdout__ is not None:
        print(msg, file=sys.__stdout__, flush=True)


class Tee:
    def __init__(self, *streams):
        self.streams = streams

    def write(self, message: str) -> int:
        for stream in self.streams:
            if stream is not None:
                stream.write(message)
                stream.flush()
        return len(message)

    def flush(self) -> None:
        for stream in self.streams:
            if stream is not None: stream.flush()

def main() -> int:
    ROOT.mkdir(parents=True, exist_ok=True)
    with REPORT.open('w',encoding='utf-8',buffering=1) as out:
        log(out, "=== UNIVERSITY MYSTERY / CAMERA AUTOSTART ===")
        log(out, f"Started: {datetime.now():%Y-%m-%d %H:%M:%S}")
        log(out, f"OS: {platform.platform()}")
        log(out, f"Python: {sys.version}")
        log(out, f"Executable: {sys.executable}")
        log(out, "Mode: REAL MediaPipe webcam recognition only; manual input is NOT AI.")
        log(out, 'Starting offline recognition; dependencies and model must already be prepared.')
        try:
            # Do not duplicate the webcam service if a previous game started it.
            from urllib.request import urlopen
            import json
            try:
                with urlopen("http://127.0.0.1:8765/status",timeout=0.8) as response:
                    existing = json.load(response)
                if existing.get("mode") == "webcam":
                    log(out, "A webcam service already owns port 8765; reusing it.")
                    return 0
                log(out, "Port 8765 is occupied. Close the other gesture service and retry.")
                return 15
            except Exception:
                pass
            if not all(importlib.util.find_spec(x) for x in ("cv2","mediapipe")):
                log(out,"AI libraries absent. Attempting ONE-TIME installation in background (internet required).")
                with (ROOT / "camera_install.log").open("w",encoding="utf-8") as install_log:
                    subprocess.run([sys.executable,"-m","pip","install","-r",str(ROOT/"requirements.txt")],
                                   cwd=ROOT, stdout=install_log,stderr=subprocess.STDOUT,check=True,timeout=240)
            import gesture_service
            log(out, "Checking MediaPipe model…")
            gesture_service.ensure_model(True)
            log(out, "Model prepared; connecting to physical webcam.")
            old_argv = sys.argv
            sys.argv = [str(ROOT/'gesture_service.py')]
            try:
                with contextlib.redirect_stdout(Tee(out, sys.__stdout__)), contextlib.redirect_stderr(Tee(out, sys.__stderr__)):
                    status = gesture_service.main()
            finally:
                sys.argv = old_argv
            log(out, f'MediaPipe stopped with exit code {status}')
            return status
        except Exception:
            log(out, 'CRASH: '+traceback.format_exc())
            return 14

if __name__=='__main__':
    raise SystemExit(main())
