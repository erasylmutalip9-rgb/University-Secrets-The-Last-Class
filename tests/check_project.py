"""Project integrity checks. This is NOT a Godot GDScript compiler or runtime test."""
from pathlib import Path
from collections import Counter
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
errors=[]
count=0

def check(ok, message):
    global count
    count+=1
    if not ok:
        errors.append(message)

for filename in [
    'project.godot','scenes/Main.tscn',
    'scripts/player.gd','scripts/game.gd','scripts/world_builder.gd','scripts/character_visual.gd',
    'assets/ui/menu_art.png','assets/ui/vignette.png','assets/ui/glitch_face.png',
    'assets/portraits/alex_portrait.png','assets/portraits/mira_portrait.png',
    'assets/portraits/daniyar_portrait.png','assets/portraits/ruslan_portrait.png',
    'assets/audio/ambient.ogg','assets/audio/tension.ogg','assets/audio/sting.ogg',
    'assets/audio/pickup.ogg','assets/audio/step_a.ogg','assets/audio/step_b.ogg',
    'assets/audio/door_creak.ogg','assets/audio/memory_whisper.ogg',
    'README.md','PROJECT_STATE.md','GAME_DESIGN.md','ROADMAP.md',
    'ASSETS_AND_LICENSES.md'
]:
    check((ROOT/filename).is_file(), 'Missing '+filename)

sources={p.name:p.read_text('utf-8') for p in (ROOT/'scripts').glob('*.gd')}
joined='\n'.join(sources.values())
for ref in set(re.findall(r'res://[\w./-]+\.(?:png|ogg|tscn|gd|glb)',joined)):
    check((ROOT/ref.removeprefix('res://')).is_file(),'Missing resource '+ref)

for marker in ['class_name AlexPlayer','class_name NoirCampus','class_name CampusCharacterVisual',
               'func _start_cinematic()','func _finish_intro()','func _show_timeline()',
               'func _timeline_press(','func _trigger_horror()','func _save_game()',
               'func _load_game()','func _show_dialogue(','func _show_scanner()',
               'func _finish_case(','func toggle_camera()','func toggle_flashlight()']:
    check(marker in joined,'Missing API '+marker)
for action in ['move_forward','move_back','move_left','move_right','camera_toggle',
               'flashlight','interact','pause','journal','sprint']:
    check('"'+action+'"' in joined,'Missing control '+action)
for clue in ['note','register','message','pass','trace','usb','audit','security',
             'guard_report','old_photo','mira_backup','alex_file']:
    check('"'+clue+'"' in joined,'Missing evidence '+clue)
for event in ['timeline_solved','danyar_contradiction','library_completed',
              'lab_completed','scan_done','first_lab_visit','scare_done']:
    check('"'+event+'"' in joined,'Missing state '+event)

def lex_check(src):
    # Reject the fatal v0.2 error: unescaped newlines inside normal quoted strings.
    stack=[];line=1;start=0;quoted=False;escaping=False;comment=False
    close={')':'(',']':'[','}':'{'}
    for c in src:
        if c=='\n':
            if quoted:return f'Literal newline within string starting at line {start}'
            line+=1;comment=False
            continue
        if comment:continue
        if quoted:
            if escaping:escaping=False
            elif c=='\\':escaping=True
            elif c=='"':quoted=False
            continue
        if c=='#':comment=True;continue
        if c=='"':quoted=True;start=line;continue
        if c in '([{':stack.append((c,line))
        if c in ')]}':
            if not stack or stack.pop()[0]!=close[c]:return f'Mismatched bracket line {line}'
    if stack:return f'Unclosed bracket at line {stack[-1][1]}'
    if quoted:return f'Unclosed string from line {start}'
    return None

for name,src in sources.items():
    check(lex_check(src) is None, f'{name}: {lex_check(src)}')
    functions=re.findall(r'^func\s+([\w]+)\s*\(',src,re.M)
    dup=[k for k,v in Counter(functions).items() if v>1]
    check(not dup,f'Duplicate functions in {name}: {dup}')

try:
    from PIL import Image
    for f in (ROOT/'assets').rglob('*.png'):
        with Image.open(f) as im:
            im.verify()
        check(True,f'PNG ok {f.name}')
except Exception as exc:
    errors.append('PNG decode: '+str(exc))
try:
    import json, subprocess, shutil
    try:
        import soundfile as sf
    except ImportError:
        sf = None
    for f in (ROOT/'assets/audio').glob('*.ogg'):
        if sf is not None:
            samples, rate = sf.read(str(f))
            duration = len(samples) / rate
        else:
            if not shutil.which('ffprobe') or not shutil.which('ffmpeg'):
                raise RuntimeError('Install soundfile or FFmpeg to validate audio')
            info = json.loads(subprocess.check_output(['ffprobe','-v','error','-show_streams','-of','json',str(f)],text=True))['streams'][0]
            rate, duration = int(info['sample_rate']), float(info['duration'])
            subprocess.run(['ffmpeg','-v','error','-i',str(f),'-f','null','-'],check=True,capture_output=True)
        check(duration>=0.15 and rate==22050, 'OGG invalid '+str(f))
except Exception as exc:
    errors.append('OGG decode: '+str(exc))

# Structural scene references and quest relationships.
scene=(ROOT/'scenes/Main.tscn').read_text()
config=(ROOT/'project.godot').read_text()
check('game.gd' in scene,'Main scene missing script')
check('Campaign.tscn' in config and (ROOT/'scenes/Campaign.tscn').is_file(),'Campaign scene not registered')
check('correct_order: Array[String] = ["down","pass","delete","up"]' in joined,'Chronology contract missing')
check('world.open_door("lab")' in joined and 'world.open_door("archive")' in joined,'Chapter unlocks missing')
check('story_flags.has("timeline_solved")' in joined,'Ending does not check chronology')
check('actor_mode == "cinematic"' in joined,'Cinematic skip logic missing')

# Regression: Godot 4.x cannot infer a type from direct indexing of an Array literal.
world_src = sources.get('world_builder.gd', '')
check('var col: String = colors[' in world_src, 'Typed color lookup regression')
check('var colors: Array[String]' in world_src, 'Missing typed color array')
check('var col := [' not in world_src, 'Unsafe literal Array index type inference')

print(f'{count-len(errors)}/{count} static checks passed')
for e in errors:print('ERROR:',e)
print('WARNING: Static checks do not guarantee Windows runtime compatibility; run the Godot tests separately.')
sys.exit(bool(errors))
