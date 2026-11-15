"""Prepare and validate offline Russian voice recognition."""
import shutil
import subprocess
import sys
from pathlib import Path
from tempfile import TemporaryDirectory
from urllib.request import urlopen
from zipfile import ZipFile

from voice_model import MODEL_DIR, MODEL_NAME, load_model, model_complete

URL = f"https://alphacephei.com/vosk/models/{MODEL_NAME}.zip"


def validate_model(path: Path) -> None:
    from vosk import KaldiRecognizer, SetLogLevel

    SetLogLevel(-1)
    KaldiRecognizer(load_model(path), 16000)


def ensure_dependencies() -> None:
    try:
        import sounddevice
        import vosk
    except ImportError:
        subprocess.run(
            [sys.executable, "-m", "pip", "install", "vosk>=0.3.45", "sounddevice>=0.4.6"],
            check=True,
        )


def install_model() -> None:
    for candidate in (MODEL_DIR, MODEL_DIR / MODEL_NAME):
        if not model_complete(candidate):
            continue
        try:
            validate_model(candidate)
        except Exception as exc:
            print(f"Existing model could not be opened: {exc}", flush=True)
        else:
            if candidate != MODEL_DIR:
                with TemporaryDirectory(dir=MODEL_DIR.parent) as tmp:
                    staged = Path(tmp) / MODEL_NAME
                    shutil.copytree(candidate, staged)
                    replace_model(staged)
            return

    MODEL_DIR.parent.mkdir(parents=True, exist_ok=True)
    with TemporaryDirectory(dir=MODEL_DIR.parent, prefix="voice-download-") as tmp:
        work = Path(tmp)
        print("Downloading the Russian model (about 45 MB)...", flush=True)
        with urlopen(URL, timeout=60) as response, (work / "model.zip").open("wb") as output:
            shutil.copyfileobj(response, output)
        with ZipFile(work / "model.zip") as archive:
            for entry in archive.infolist():
                dest = (work / entry.filename).resolve()
                if not dest.is_relative_to(work.resolve()) or dest == work.resolve():
                    raise RuntimeError("Unsafe filename in model archive")
            archive.extractall(work)
        staged = work / MODEL_NAME
        validate_model(staged)
        replace_model(staged)


def replace_model(staged: Path) -> None:
    # Keep the old installation until the replacement has been opened by Vosk.
    backup = staged.with_name("previous-model")
    if MODEL_DIR.exists():
        MODEL_DIR.rename(backup)
    try:
        staged.rename(MODEL_DIR)
    except OSError:
        if backup.exists() and not MODEL_DIR.exists():
            backup.rename(MODEL_DIR)
        raise


def main() -> int:
    try:
        ensure_dependencies()
        install_model()
        print(f"SUCCESS: Vosk opened the Russian model at {MODEL_DIR}")
    except Exception as exc:
        print(f"ERROR: Voice setup failed: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
