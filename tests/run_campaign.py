"""Isolated, repeatable test entry point. No game save or profile is touched."""
from pathlib import Path
import json
import locale
import os
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime, timezone

root = Path(__file__).resolve().parents[1]
godot = os.environ.get('GODOT_EXE') or shutil.which('godot')
if not godot:
    local_editor = root / 'Godot_v4.7.2-stable_win64.exe'
    if local_editor.is_file():
        godot = str(local_editor)
if not godot:
    raise SystemExit('Set GODOT_EXE to the full Godot executable path, or put godot in PATH.')


def decode(data: bytes) -> str:
    try:
        return data.decode('utf-8')
    except UnicodeDecodeError:
        return data.decode(locale.getencoding(), errors='replace')


results = []
with tempfile.TemporaryDirectory(prefix='echo-test-') as tmp:
    env = dict(os.environ, XDG_DATA_HOME=tmp, APPDATA=tmp)
    cases = [
        ('import', [godot,'--headless','--path',str(root),'--editor','--import','--quit']),
        *[(name,[godot,'--headless','--path',str(root),'--script',f'res://tests/{name}.gd']) for name in ['test_v09_save','test_level01','test_campaign','test_restart','test_campaign_physics','test_intent','test_collision','test_interactions']],
        ('gesture_gate',[sys.executable,str(root/'ai_service/test_gestures.py')]),
        ('gesture_http',[sys.executable,str(root/'ai_service/test_camera_http.py')]),
        ('v07_regressions',[sys.executable,str(root/'tests/test_v07_regressions.py')]),
        ('v11_extensions',[sys.executable,str(root/'tests/test_v11_extensions.py')]),
        ('voice_regressions',[sys.executable,str(root/'tests/test_voice_v0111.py')]),
    ]
    for name, command in cases:
        run = subprocess.run(command,env=env,capture_output=True,timeout=180)
        output = decode(run.stdout) + decode(run.stderr)
        # These headless cases do not use TLS. Retain this OS warning in the
        # report, while leaving other Godot errors fatal.
        errors = output.replace('ERROR: Failed to read the root certificate store.', '')
        success = run.returncode == 0 and 'FAIL:' not in errors and 'ERROR:' not in errors
        results.append({'test':name,'pass':success,'exit_code':run.returncode,'output':output})
        print(f'{name}: {"PASS" if success else "FAIL"}',flush=True)
        if not success: print(output)
report = {'date':datetime.now(timezone.utc).isoformat(),'engine':subprocess.check_output([godot,'--version'],text=True).strip(),'platform':sys.platform,'mode':'headless; no visual or physical webcam validation','results':results}
(root/'tests/LAST_RUN.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
raise SystemExit(0 if all(row['pass'] for row in results) else 1)
