"""Tests that do not need a microphone or Windows PowerShell."""
import importlib.util
import json
import sys
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'ai_service'))
from voice_model import REQUIRED_FILES
VOICE_FILE = ROOT / 'ai_service' / 'voice_service.py'
SPEC = importlib.util.spec_from_file_location('project_voice_service', VOICE_FILE)
voice = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(voice)


def run():
    ps = (ROOT / 'ai_service' / 'voice_windows.ps1').read_bytes()
    assert ps.isascii(), 'PowerShell 5.1 script must not contain ambiguous UTF-8 bytes'
    assert b'InstalledRecognizers()' in ps
    assert b'SpeechRecognitionEngine' in ps
    assert b'WriteAllText' in ps
    # No model and not Windows: report understandable instructions, no tracebacks.
    with TemporaryDirectory() as td:
        with patch.object(voice, 'MODEL_DIR', Path(td) / 'no_model'), patch.object(voice, 'is_windows', return_value=False):
            try:
                voice.run_recognition(Path(td) / 'res.json')
                assert False, 'Expected unavailable recognition to report an error'
            except RuntimeError as ex:
                assert 'SETUP_VOICE_WINDOWS.bat' in str(ex)
        # Voice recognition succeeds using the offline model when prepared.
        m = Path(td) / 'model'
        (m / 'am').mkdir(parents=True)
        assert not voice.model_complete(m)
        for name in REQUIRED_FILES:
            file = m / name
            file.parent.mkdir(parents=True, exist_ok=True)
            file.write_bytes(b'fixture')
        with patch.object(voice, 'MODEL_DIR', m), patch.object(voice, 'recognize_vosk', return_value='Почему выключили камеры?'):
            got, source = voice.run_recognition(Path(td) / 'res.json')
            assert got == 'Почему выключили камеры?' and source == 'offline_vosk'
        # On Windows, Windows Speech is used if the model is absent.
        with patch.object(voice, 'MODEL_DIR', Path(td) / 'no_model'), patch.object(voice, 'is_windows', return_value=True), patch.object(voice, 'recognize_windows', return_value='Где был Данияр?'):
            got, source = voice.run_recognition(Path(td) / 'res.json')
            assert (got, source) == ('Где был Данияр?', 'windows_sapi')
        # Vosk error can still fall back to native speech if available.
        with patch.object(voice, 'MODEL_DIR', m), patch.object(voice, 'is_windows', return_value=True), patch.object(voice, 'recognize_vosk', side_effect=RuntimeError('mic busy')), patch.object(voice, 'recognize_windows', return_value='Время входа?'):
            got, source = voice.run_recognition(Path(td) / 'res.json')
            assert (got, source) == ('Время входа?', 'windows_sapi')
        # No successful backend should not produce a fake recognized question.
        with patch.object(voice, 'MODEL_DIR', m), patch.object(voice, 'is_windows', return_value=True), patch.object(voice, 'recognize_vosk', side_effect=RuntimeError('mic busy')), patch.object(voice, 'recognize_windows', side_effect=RuntimeError('no ru engine')):
            try:
                voice.run_recognition(Path(td) / 'res.json')
                assert False, 'Expected failure'
            except RuntimeError as ex:
                message = str(ex)
                assert 'mic busy' in message and 'no ru engine' in message
                assert 'SETUP_VOICE_WINDOWS.bat' in message
        # Result writing is UTF-8 JSON and sanitized, even for failures.
        with patch.object(voice, 'run_recognition', side_effect=RuntimeError('Failed\nPowerShell StackTrace')), patch.object(voice, 'DIAGNOSTICS', Path(td) / 'voice_diagnostics.txt'), patch('sys.argv', ['voice_service.py', '--output', str(Path(td) / 'out.json')]):
            ret = voice.main()
            payload = json.loads((Path(td) / 'out.json').read_text('utf-8'))
            assert ret == 2 and payload['ok'] is False
            assert payload['text'] == '' and '\n' not in payload['error']
            assert (Path(td) / 'voice_diagnostics.txt').exists()
    print('6/6 focused voice-regression groups passed')


if __name__ == '__main__':
    run()
