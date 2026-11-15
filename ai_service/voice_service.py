"""One-shot offline Russian speech-to-text for NPC interrogation.

With a prepared Vosk model, voice input works offline. Windows Speech ru-RU
is an optional fallback. The game receives a small JSON result file; raw audio
is processed only in memory. Dependencies are NOT installed during gameplay.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import queue
import subprocess
import sys
import time
from voice_model import MODEL_DIR, load_model, model_complete

ROOT = Path(__file__).resolve().parent
DIAGNOSTICS = ROOT / 'voice_diagnostics.txt'


def recognize_vosk(limit: float = 11.0) -> str:
    """Capture a single utterance at the microphone's supported sample rate."""
    from vosk import KaldiRecognizer, SetLogLevel
    import sounddevice as sd

    SetLogLevel(-1)
    device = sd.query_devices(kind='input')
    if not device or int(device.get('max_input_channels', 0)) < 1:
        raise RuntimeError('Микрофон не найден или недоступен в Windows.')
    sample_rate = int(round(float(device.get('default_samplerate', 16000))))
    if sample_rate <= 0:
        raise RuntimeError('Микрофон не сообщает допустимую частоту записи.')
    model = load_model(MODEL_DIR)
    recognizer = KaldiRecognizer(model, sample_rate)
    fragments: queue.Queue[bytes] = queue.Queue()

    def callback(indata, _frames, _time_info, status):
        if status:
            # PortAudio may report a dropped block. Continue with the next one.
            pass
        fragments.put(bytes(indata))

    start = time.monotonic()
    with sd.RawInputStream(
        samplerate=sample_rate,
        blocksize=max(1000, sample_rate // 4),
        dtype='int16',
        channels=1,
        callback=callback,
    ):
        while time.monotonic() - start < limit:
            try:
                data = fragments.get(timeout=0.6)
            except queue.Empty:
                continue
            if recognizer.AcceptWaveform(data):
                message = str(json.loads(recognizer.Result()).get('text', '')).strip()
                if message:
                    return message
        return str(json.loads(recognizer.FinalResult()).get('text', '')).strip()


def recognize_windows(output_path: Path) -> str:
    """Use native Windows Speech ONLY when a Russian recognizer is installed."""
    script = ROOT / 'voice_windows.ps1'
    temp = output_path.with_name(output_path.stem + '.windows.json')
    if temp.exists():
        temp.unlink()
    command = [
        'powershell.exe', '-NoProfile', '-NonInteractive',
        '-ExecutionPolicy', 'Bypass', '-File', str(script),
        '-OutputPath', str(temp),
    ]
    try:
        result = subprocess.run(command, capture_output=True, text=True,
                                errors='replace', timeout=20)
        if not temp.is_file():
            raise RuntimeError('Не удалось запустить Windows Speech. ' +
                               (result.stderr or result.stdout or '')[-180:])
        try:
            obj = json.loads(temp.read_text(encoding='utf-8-sig'))
        except (ValueError, UnicodeError) as exc:
            raise RuntimeError('Windows Speech вернул некорректный результат.') from exc
        if not obj.get('ok'):
            details = str(obj.get('error', '')).strip()
            if 'not installed' in details.lower():
                raise RuntimeError('Русский речевой движок Windows не установлен.')
            if details == 'No speech detected or recognized.':
                raise RuntimeError('Речь не распознана. Повтори вопрос более отчётливо.')
            raise RuntimeError(details[:180] or 'Windows Speech не смог распознать вопрос.')
        return str(obj.get('text', '')).strip()
    finally:
        try:
            temp.unlink(missing_ok=True)
        except OSError:
            pass


def is_windows() -> bool:
    return os.name == 'nt'


def run_recognition(output_path: Path) -> tuple[str, str]:
    """Return recognized speech and backend name, or a short actionable error."""
    errors = []
    model_ready = model_complete(MODEL_DIR)
    if model_ready:
        try:
            text = recognize_vosk()
            if not text:
                raise RuntimeError('Речь не распознана. Повтори вопрос ближе к микрофону.')
            return text, 'offline_vosk'
        except Exception as exc:
            errors.append('Vosk: ' + str(exc)[:160])
    else:
        errors.append('Офлайн-модель Vosk не установлена.')

    if is_windows():
        try:
            text = recognize_windows(output_path)
            if not text:
                raise RuntimeError('Речь не распознана.')
            return text, 'windows_sapi'
        except Exception as exc:
            errors.append('Windows Speech: ' + str(exc)[:160])

    raise RuntimeError(
        'Голосовой ввод недоступен. ' + ' '.join(errors) +
        ' Один раз запусти SETUP_VOICE_WINDOWS.bat в папке игры.'
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path)
    parser.add_argument('--model-only', action='store_true')
    parser.add_argument('--print-result', action='store_true')
    args = parser.parse_args()
    if args.model_only:
        try:
            from setup_voice import validate_model

            validate_model(MODEL_DIR)
        except Exception as exc:
            print(f'ERROR: {exc}. Run SETUP_VOICE_WINDOWS.bat.', file=sys.stderr)
            return 1
        print(f'OK: Vosk opened the Russian model at {MODEL_DIR}')
        return 0
    if args.output is None:
        parser.error('--output is required for microphone recognition')
    dest = args.output
    dest.parent.mkdir(parents=True, exist_ok=True)
    payload: dict[str, object] = {'ok': False, 'text': '', 'error': '', 'source': ''}
    try:
        text, source = run_recognition(dest)
        payload.update({'ok': True, 'text': text, 'source': source})
        diagnostics = 'OK: ' + source + ' recognized spoken question.\n'
    except Exception as exc:
        # Never show a Python/PowerShell traceback inside an NPC conversation.
        message = str(exc).replace('\r', ' ').replace('\n', ' ')[:500]
        payload['error'] = message
        diagnostics = 'ERROR: ' + message + '\n'
    try:
        DIAGNOSTICS.write_text(diagnostics, encoding='utf-8')
    except OSError:
        pass
    try:
        temp = dest.with_suffix('.tmp')
        temp.write_text(json.dumps(payload, ensure_ascii=False), encoding='utf-8')
        temp.replace(dest)
    except OSError as exc:
        print('Cannot write voice result:', exc, file=sys.stderr)
        return 1
    if args.print_result:
        print(json.dumps(payload, ensure_ascii=False, indent=2))
        print(f'Diagnostics: {DIAGNOSTICS}')
    return 0 if payload['ok'] else 2


if __name__ == '__main__':
    raise SystemExit(main())
