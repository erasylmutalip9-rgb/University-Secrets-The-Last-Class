"""Locate and open the bundled Russian Vosk model."""
from contextlib import chdir
import os
from pathlib import Path

MODEL_NAME = "vosk-model-small-ru-0.22"
MODEL_DIR = Path(__file__).resolve().parent / "models" / MODEL_NAME
REQUIRED_FILES = (
    "am/final.mdl", "conf/model.conf", "conf/mfcc.conf",
    "graph/HCLr.fst", "graph/Gr.fst", "graph/disambig_tid.int",
    "graph/phones/word_boundary.int",
    "ivector/final.ie", "ivector/final.mat", "ivector/final.dubm",
    "ivector/global_cmvn.stats", "ivector/online_cmvn.conf", "ivector/splice.conf",
)


def model_complete(path: Path) -> bool:
    return all((file := path / name).is_file() and file.stat().st_size > 0
               for name in REQUIRED_FILES)


def load_model(path: Path):
    from vosk import Model

    path = path.resolve()
    if not model_complete(path):
        raise RuntimeError(f"Missing or empty Vosk model files in {path}")
    if os.name == "nt":
        # Python changes directory with Unicode support. Vosk's native file
        # calls receive paths relative to it, avoiding Unicode in the prefix.
        # Both callers load the model before starting any audio threads.
        with chdir(path):
            return Model(".")
    return Model(str(path))
