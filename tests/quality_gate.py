"""Additional static regression checks for RK2 visual/camera changes.
These are not Godot runtime or real webcam tests.
"""
from pathlib import Path
import ast
import re
import sys
from PIL import Image

root=Path(__file__).resolve().parents[1]
errors=[]
checks=0

def need(ok, msg):
    global checks
    checks+=1
    if not ok: errors.append(msg)

world=(root/'scripts/world_builder.gd').read_text('utf-8')
player=(root/'scripts/player.gd').read_text('utf-8')
character=(root/'scripts/character_visual.gd').read_text('utf-8')
game=(root/'scripts/game.gd').read_text('utf-8')
for path in (root/'ai_service').glob('*.py'):
    try: ast.parse(path.read_text('utf-8'))
    except SyntaxError as exc: errors.append(str(exc))
    checks+=1

for name in ['floor_library','floor_stone','floor_lab','floor_archive','plaster_neutral','walnut_furniture']:
    albedo=root/'assets/textures'/f'{name}.png'
    normal=root/'assets/textures'/f'{name}_normal.png'
    need(albedo.is_file(), f'{name} albedo missing')
    need(normal.is_file(), f'{name} normal missing')
    if albedo.is_file():
        with Image.open(albedo) as im: need(im.size==(768,768),f'{name} incorrect dimensions')
for marker in ['func _tube_elliptic(','func _tapered_body(','_head_pivot','_left_arm','_right_arm','_left_leg','_right_leg']:
    need(marker in character,f'Character marker {marker}')
for marker in ['ACCELERATION','BRAKE','move_toward(velocity.x','third_camera.position.x']:
    need(marker in player,f'Movement marker {marker}')
for marker in ['e.ambient_light_energy = 0.42','func textured_material','_textured_material_cache','var m := StandardMaterial3D.new()','m.normal_enabled = true']:
    need(marker in world,f'World marker {marker}')
for marker in ['func _start_gestures_if_needed()','ai_service/launch_camera.py','OS.create_process','camera_diagnostics.txt']:
    need(marker in game,f'Camera/game marker {marker}')
for filename in ['ai_service/launch_camera.py','START_GESTURES_AUTO_WINDOWS.bat','SETUP_CAMERA_WINDOWS.bat','ai_service/camera_diagnostics.py']:
    need((root/filename).is_file(),f'File missing {filename}')
need('bool(payload.get("active",false))' in game,'Camera ready check missing')
need('gate.active = True' in (root/'ai_service/gesture_service.py').read_text('utf-8'), 'Actual webcam readiness not set')
need('camera_autostart' not in world,'Unwanted camera code in world')
print(f'Quality gate: {checks-len(errors)}/{checks} checks')
for x in errors: print('FAIL:',x)
print('Static validation only: does not prove 3D rendering or physical camera operation.')
sys.exit(bool(errors))
