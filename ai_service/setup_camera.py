"""Explicit one-time setup; the game launcher never installs dependencies."""
from pathlib import Path
import subprocess
import sys

def main():
    root = Path(__file__).resolve().parent
    subprocess.run([sys.executable, '-m', 'pip', 'install', '-r', str(root/'requirements.txt')], check=True)
    from gesture_service import check_model, ensure_model
    ensure_model(True)
    check_model()
    print('Prepared. Run CHECK_CAMERA_WINDOWS.bat to verify real frames.')
    print('Run VALIDATE_REAL_CAMERA_WINDOWS.bat to test all five gestures.')

if __name__ == '__main__':
    main()
