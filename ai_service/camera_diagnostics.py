"""Windows-friendly webcam/MediaPipe diagnostics with no silent fallback.

Run: py -3 ai_service/camera_diagnostics.py
Creates camera_diagnostics.txt next to this source file.
"""
from __future__ import annotations

import argparse
from datetime import datetime
from pathlib import Path
import platform
import sys
import traceback
from contextlib import redirect_stdout
from io import StringIO
from gesture_service import check_model, open_camera

ROOT = Path(__file__).resolve().parent
REPORT = ROOT / "camera_diagnostics.txt"


def diagnose(camera_index: int | None = None, preview: bool = False) -> bool:
    messages: list[str] = []

    def say(message: str) -> None:
        print(message, flush=True)
        messages.append(message)

    say("=== ЭХО / Диагностика камеры и распознавания жестов ===")
    say(f"Время: {datetime.now().isoformat(timespec='seconds')}")
    say(f"ОС: {platform.platform()}")
    say(f"Python: {sys.version.replace(chr(10), ' ')}")
    say(f"Python exe: {sys.executable}")
    say("Пробуем открыть реальные кадры, а не только проверить 'камера подключена'.")
    ok = False
    try:
        import cv2
        say(f"OpenCV: {cv2.__version__}")
        for idx in ([camera_index] if camera_index is not None else [0, 1, 2]):
            attempts = StringIO()
            with redirect_stdout(attempts):
                cap = open_camera(idx)
            say(attempts.getvalue().rstrip())
            if cap is None:
                continue
            ok = True
            try:
                if preview:
                    window = "ECHO webcam diagnostics (Q = exit)"
                    while True:
                        ready, frame = cap.read()
                        if not ready or frame is None:
                            say("Камера перестала возвращать кадры")
                            ok = False
                            break
                        cv2.imshow(window, frame)
                        if cv2.waitKey(15) & 0xFF in (ord('q'), 27) or cv2.getWindowProperty(window, cv2.WND_PROP_VISIBLE) < 1:
                            break
            finally:
                cap.release()
                if preview:
                    cv2.destroyAllWindows()
            if ok:
                break
    except Exception:
        say("ОШИБКА при загрузке/запуске OpenCV:")
        say(traceback.format_exc())

    model_ok = False
    try:
        import mediapipe as mp
        say(f"MediaPipe: {getattr(mp, '__version__', 'unknown')}")
        check_model()
        model_ok = True
        say("Модель MediaPipe загружается и обрабатывает изображение.")
    except Exception:
        say("ОШИБКА при проверке MediaPipe. Запусти SETUP_CAMERA_WINDOWS.bat.")
        say(traceback.format_exc())

    model_path = ROOT / "models" / "gesture_recognizer.task"
    if model_path.is_file():
        say(f"ML модель: {model_path}, размер {model_path.stat().st_size} байт")
    else:
        say("ML модель: ОТСУТСТВУЕТ (нужна разовая загрузка)")

    if ok:
        say("ИТОГ: Python получает кадры камеры. Следующий этап — запуск модели жестов.")
    else:
        say("ИТОГ: Python не получает кадры камеры. Проверь разрешения Windows, другой индекс камеры, закрой Zoom/Telegram/OBS.")
        say("Windows: Параметры > Конфиденциальность и безопасность > Камера > Разрешить классическим приложениям доступ к камере.")

    try:
        REPORT.write_text("\n".join(messages) + "\n", encoding="utf-8")
        say(f"Отчёт: {REPORT}")
    except Exception as exc:
        print("Не удалось записать отчёт:", exc)
    return ok and model_ok


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--camera", type=int, default=None)
    parser.add_argument("--preview", action="store_true")
    parser.add_argument("--model-only", action="store_true")
    args = parser.parse_args()
    if args.model_only:
        try:
            check_model()
        except Exception as exc:
            print(f"ERROR: MediaPipe check failed: {exc}")
            raise SystemExit(1)
        print("OK: MediaPipe processed a test image without opening the webcam.")
        raise SystemExit(0)
    raise SystemExit(0 if diagnose(args.camera, args.preview) else 2)
