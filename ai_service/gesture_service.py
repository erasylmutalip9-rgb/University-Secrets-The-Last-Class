"""Local gesture service for the chronology puzzle.

Primary mode: MediaPipe webcam recognition.
Manual console input (1..5) is an explicit troubleshooting fallback only.
It is NOT artificial intelligence and must never be presented as recognition.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import argparse
import json
import logging
import platform
import sys
import threading
import time
from uuid import uuid4
from zipfile import BadZipFile, ZipFile
from urllib.request import urlretrieve

MODEL_URL = (
    "https://storage.googleapis.com/mediapipe-models/gesture_recognizer/"
    "gesture_recognizer/float16/latest/gesture_recognizer.task"
)
MODEL_PATH = Path(__file__).resolve().parent / "models" / "gesture_recognizer.task"
GESTURES = {"Closed_Fist", "Victory", "Open_Palm", "Thumb_Up", "Pointing_Up"}
MANUAL_MAP = {
    "1": "Closed_Fist",
    "2": "Victory",
    "3": "Open_Palm",
    "4": "Thumb_Up",
    "5": "Pointing_Up",
}


@dataclass
class EventGate:
    session_id: str = field(default_factory=lambda: uuid4().hex, init=False)
    required_frames: int = 6
    min_confidence: float = 0.67
    candidate: str = ""
    count: int = 0
    armed: bool = True
    event_id: int = 0
    latest_gesture: str = ""
    latest_confidence: float = 0.0
    last_event_time: float = 0.0
    last_fired_gesture: str = ""
    event_gesture: str = ""
    event_confidence: float = 0.0
    mode: str = "webcam"
    status: str = "starting"
    active: bool = False
    last_jpeg: bytes = b""
    lock: threading.Lock = field(default_factory=threading.Lock)

    def update(self, gesture: str, confidence: float) -> None:
        now = time.monotonic()
        with self.lock:
            valid = gesture in GESTURES and confidence >= self.min_confidence
            if not valid:
                self.candidate = ""
                self.count = 0
                self.armed = True
                self.latest_gesture = ""
                self.latest_confidence = 0.0
                return
            self.latest_gesture = gesture
            self.latest_confidence = float(confidence)
            if gesture == self.candidate:
                self.count += 1
            else:
                self.candidate = gesture
                self.count = 1
                # Allow changing from one stable gesture to another without
                # requiring the hand to leave the frame completely.
                if gesture != self.last_fired_gesture:
                    self.armed = True
            if self.armed and self.count >= self.required_frames and now - self.last_event_time >= 0.70:
                self.event_id += 1
                self.armed = False
                self.last_fired_gesture = gesture
                self.event_gesture = gesture
                self.event_confidence = float(confidence)
                self.last_event_time = now

    def trigger_manual(self, gesture: str, confidence: float = 1.0) -> None:
        now = time.monotonic()
        with self.lock:
            self.mode = "manual"
            self.latest_gesture = gesture
            self.latest_confidence = confidence
            if now - self.last_event_time >= 0.25:
                self.event_id += 1
                self.event_gesture = gesture
                self.event_confidence = float(confidence)
                self.last_event_time = now

    def store_preview(self, frame_jpeg: bytes) -> None:
        with self.lock:
            self.last_jpeg = frame_jpeg

    def preview(self) -> bytes:
        with self.lock:
            return self.last_jpeg

    def snapshot(self) -> dict[str, object]:
        with self.lock:
            return {
                "gesture": self.event_gesture,
                "confidence": round(self.event_confidence, 3),
                "observed_gesture": self.latest_gesture,
                "observed_confidence": round(self.latest_confidence, 3),
                "event_id": self.event_id,
                "session_id": self.session_id,
                "active": self.active,
                "mode": self.mode,
                "status": self.status,
            }


class StatusHandler(BaseHTTPRequestHandler):
    gate: EventGate

    def do_GET(self) -> None:
        if self.path == "/frame":
            payload = self.gate.preview()
            if not payload:
                self.send_error(503, "No webcam frame available yet")
                return
            self.send_response(200)
            self.send_header("Content-Type", "image/jpeg")
            self.send_header("Cache-Control", "no-store")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)
            return
        if self.path not in ("/gesture", "/status"):
            self.send_error(404, "Unknown endpoint")
            return
        response = self.gate.snapshot()
        data = json.dumps(response, ensure_ascii=False).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, fmt: str, *args: object) -> None:
        logging.debug(fmt, *args)


def model_archive_valid(path: Path) -> bool:
    try:
        with ZipFile(path) as archive:
            return len(archive.namelist()) >= 2 and archive.testzip() is None
    except (OSError, BadZipFile):
        return False


def ensure_model(download: bool) -> None:
    if model_archive_valid(MODEL_PATH):
        return
    if not download:
        raise FileNotFoundError(
            f"Модель не найдена: {MODEL_PATH}. Запусти с --download-model (нужен интернет один раз)."
        )
    MODEL_PATH.parent.mkdir(parents=True, exist_ok=True)
    print("Загрузка официальной модели MediaPipe (один раз, интернет необходим)...")
    tmp = MODEL_PATH.with_suffix(".download")
    try:
        urlretrieve(MODEL_URL, tmp)
        if not model_archive_valid(tmp):
            raise RuntimeError("Архив модели MediaPipe повреждён")
        tmp.replace(MODEL_PATH)
    finally:
        tmp.unlink(missing_ok=True)


def check_model() -> None:
    """Run actual MediaPipe inference on a blank image without opening a camera."""
    import mediapipe as mp
    import numpy as np
    from mediapipe.tasks import python
    from mediapipe.tasks.python import vision

    ensure_model(False)
    options = vision.GestureRecognizerOptions(
        base_options=python.BaseOptions(model_asset_buffer=MODEL_PATH.read_bytes())
    )
    image = mp.Image(image_format=mp.ImageFormat.SRGB, data=np.zeros((240, 320, 3), dtype=np.uint8))
    with vision.GestureRecognizer.create_from_options(options) as recognizer:
        recognizer.recognize(image)


def start_server(gate: EventGate, port: int) -> ThreadingHTTPServer:
    StatusHandler.gate = gate
    server = ThreadingHTTPServer(("127.0.0.1", port), StatusHandler)
    server.daemon_threads = True
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return server


def manual_loop(gate: EventGate) -> int:
    print("РЕЗЕРВНЫЙ РЕЖИМ УПРАВЛЕНИЯ ЖЕСТАМИ")
    print("Вводи 1/2/3/4/5 для имитации жестов (НЕ AI), q — выход.")
    print("1=кулак, 2=два пальца, 3=ладонь, 4=лайк, 5=указательный палец")
    while True:
        try:
            value = input("> ").strip().lower()
        except (EOFError, KeyboardInterrupt):
            print("\nОстановка резервного режима.")
            return 0
        if value in ("q", "quit", "exit"):
            return 0
        if value in MANUAL_MAP:
            gesture = MANUAL_MAP[value]
            gate.trigger_manual(gesture)
            print(f"Событие отправлено: {gesture}")
        else:
            print("Неизвестная команда. Используй 1/2/3/4/5 или q.")


def open_camera(camera_index: int):
    """Try the two common Windows camera backends, then automatic.

    A successful isOpened() is insufficient: we also require real frames.
    """
    import cv2

    choices = [("AUTO", cv2.CAP_ANY)]
    if platform.system() == "Windows":
        choices = [("DSHOW", cv2.CAP_DSHOW), ("MSMF", cv2.CAP_MSMF), ("AUTO", cv2.CAP_ANY)]
    for backend_name, backend in choices:
        cap = None
        try:
            print(f"Камера {camera_index}: проверяю {backend_name}...", flush=True)
            cap = cv2.VideoCapture(camera_index, backend)
            if not cap.isOpened():
                cap.release()
                continue
            cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
            cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
            ready = False
            for _ in range(8):
                success, frame = cap.read()
                if success and frame is not None:
                    ready = True
                    break
                time.sleep(0.12)
            if ready:
                print(f"Камера {camera_index}: {backend_name} возвращает кадры. WebCam OK.",flush=True)
                return cap
            cap.release()
        except Exception as exc:
            print(f"Не сработал backend {backend_name}: {exc}")
            if cap is not None:
                cap.release()
    return None


def mediapipe_loop(gate: EventGate, camera_index: int, preview: bool) -> int:
    try:
        import cv2
        import mediapipe as mp
        from mediapipe.tasks import python as mp_python
        from mediapipe.tasks.python import vision
        print(f"OpenCV {cv2.__version__} | MediaPipe {getattr(mp, '__version__', '?')}",flush=True)
    except Exception as exc:
        gate.status = f"Ошибка импорта: {exc}. Запусти SETUP_CAMERA_WINDOWS.bat"
        print(f"ML-распознавание не удалось импортировать: {exc}")
        print("Запусти CHECK_CAMERA_WINDOWS.bat и пришли ai_service/camera_diagnostics.txt")
        return 2

    cap = None
    selected_index = camera_index
    for candidate_index in dict.fromkeys([camera_index, 0, 1, 2]):
        cap = open_camera(candidate_index)
        if cap is not None:
            selected_index = candidate_index
            break
    if cap is None:
        gate.status = "Камера не возвращает кадры: проверь права Windows и занятость устройства"
        print("Не удалось получить кадры. Проверь доступ к камере Windows, закрой Zoom/OBS/Telegram.")
        print("Запусти CHECK_CAMERA_WINDOWS.bat для поиска индекса 0, 1 или 2.")
        return 3

    print("Режим ML: MediaPipe. Это реальное распознавание с веб-камеры.")
    print("Покажи кулак / два пальца / ладонь / лайк / указательный палец. Держи 0.5–1 сек.")
    options = vision.GestureRecognizerOptions(
        base_options=mp_python.BaseOptions(model_asset_buffer=MODEL_PATH.read_bytes()),
        running_mode=vision.RunningMode.VIDEO,
        num_hands=1,
        min_hand_detection_confidence=0.50,
        min_hand_presence_confidence=0.50,
        min_tracking_confidence=0.50,
    )
    start = time.monotonic()
    last_preview = 0.0
    last_timestamp = -1
    gate.mode = "webcam"
    try:
        with vision.GestureRecognizer.create_from_options(options) as recognizer:
            gate.status = "ready"
            gate.active = True
            missing_frames = 0
            while True:
                success, bgr = cap.read()
                if not success or bgr is None:
                    missing_frames += 1
                    gate.update("", 0.0)
                    if missing_frames >= 25:
                        gate.status = "Повторное подключение видеопотока…"
                        gate.active = False
                        gate.store_preview(b"")
                        cap.release()
                        cap = None
                        for idx in dict.fromkeys([selected_index, 0, 1, 2]):
                            cap = open_camera(idx)
                            if cap is not None:
                                selected_index = idx
                                break
                        if cap is None:
                            print("Поток камеры потерян: все индексы 0, 1, 2 недоступны.")
                            gate.status = "Поток камеры потерян: устройство не возвращает кадры"
                            return 4
                        gate.active = True
                        gate.status = "ready"
                        missing_frames = 0
                    time.sleep(0.06)
                    continue
                missing_frames = 0
                rgb = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB)
                mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb)
                timestamp = max(last_timestamp + 1, int((time.monotonic() - start) * 1000))
                last_timestamp = timestamp
                result = recognizer.recognize_for_video(mp_image, timestamp)
                category = result.gestures[0][0] if result.gestures and result.gestures[0] else None
                gesture = category.category_name if category else ""
                confidence = float(category.score) if category else 0.0
                gate.update(gesture, confidence)
                if time.monotonic() - last_preview > 0.45:
                    last_preview = time.monotonic()
                    thumb = cv2.resize(cv2.flip(bgr, 1), (320, 240))
                    ok_jpeg, buffer = cv2.imencode(".jpg", thumb, [int(cv2.IMWRITE_JPEG_QUALITY), 68])
                    if ok_jpeg:
                        gate.store_preview(buffer.tobytes())
                if preview:
                    frame = cv2.flip(bgr, 1)
                    cv2.putText(frame, f"MediaPipe: {gesture}  {confidence:.2f}", (16, 36),
                                cv2.FONT_HERSHEY_SIMPLEX, 0.8, (245, 245, 245), 2)
                    cv2.putText(frame, "Hold gesture ~1 sec; Q to exit", (16, 68),
                                cv2.FONT_HERSHEY_SIMPLEX, 0.6, (240, 240, 240), 1)
                    cv2.imshow("ECHO - REAL webcam gesture recognition", frame)
                    if cv2.waitKey(1) & 0xFF in (ord("q"), 27):
                        break
    except KeyboardInterrupt:
        pass
    except Exception as exc:
        gate.status = f"Ошибка модели: {type(exc).__name__}: {exc}"
        print(f"Ошибка модели MediaPipe: {type(exc).__name__}: {exc}")
        return 5
    finally:
        gate.active = False
        gate.store_preview(b"")
        if cap is not None:
            cap.release()
        if preview:
            cv2.destroyAllWindows()
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description="Локальное распознавание жестов ЭХО")
    ap.add_argument("--camera", type=int, default=0, help="Индекс веб-камеры (обычно 0)")
    ap.add_argument("--port", type=int, default=8765)
    ap.add_argument("--download-model", action="store_true")
    ap.add_argument("--preview", action="store_true", help="Показывать картинку камеры; q — выход")
    ap.add_argument("--manual", action="store_true", help="Сразу запустить резервный ручной режим")
    args = ap.parse_args()

    print(f"Python {platform.python_version()} | {platform.system()}")
    if sys.version_info >= (3, 13):
        print("Для Python 3.13 установи MediaPipe 1.2.2+ (см. requirements.txt).")

    gate = EventGate(mode="manual" if args.manual else "webcam")
    server = start_server(gate, args.port)
    print(f"Сервис жестов доступен: http://127.0.0.1:{args.port}/gesture")
    try:
        if args.manual:
            return manual_loop(gate)
        try:
            ensure_model(args.download_model)
        except Exception as exc:
            print(f"Модель MediaPipe не готова: {exc}")
            print("Распознавание жестов НЕ запущено. Это нельзя считать работающим AI.")
            gate.status = f"Модель не готова: {exc}. Запусти SETUP_CAMERA_WINDOWS.bat"
            time.sleep(30)  # Keep HTTP reason visible briefly; no install at game runtime.
            return 2
        status = mediapipe_loop(gate, args.camera, args.preview)
        gate.active = False
        if status != 0:
            time.sleep(30)
        return status
    finally:
        server.shutdown()
        server.server_close()


if __name__ == "__main__":
    raise SystemExit(main())
