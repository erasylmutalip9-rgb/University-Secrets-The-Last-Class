"""Static/data integration checks; NOT a substitute for Godot or real devices."""
from pathlib import Path
import ast
import json
import re
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'ai_service'))
from gesture_service import EventGate


class V11Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.casework = json.loads((ROOT / 'data/casework.json').read_text(encoding='utf-8'))
        cls.campaign = json.loads((ROOT / 'data/campaign.json').read_text(encoding='utf-8'))
        cls.controller = (ROOT / 'scripts/campaign/controller.gd').read_text(encoding='utf-8')
        cls.game = (ROOT / 'scripts/game.gd').read_text(encoding='utf-8')
        cls.map = (ROOT / 'scripts/campaign/map.gd').read_text(encoding='utf-8')
        cls.state = (ROOT / 'scripts/campaign/state.gd').read_text(encoding='utf-8')

    def test_number_and_distinctness(self):
        self.assertEqual(len(self.campaign['levels']), 20)
        self.assertEqual(set(self.casework), {str(n) for n in range(2,21)})
        self.assertEqual(len({v['title'] for v in self.casework.values()}), 19)
        self.assertGreaterEqual(len({v['kind'] for v in self.casework.values()}), 3)

    def test_each_solution_is_well_formed(self):
        for id, task in self.casework.items():
            with self.subTest(level=id):
                self.assertTrue(task['intro'] and task['wrong'] and task['outcome'])
                self.assertTrue(task['title'])
                if task['kind'] == 'sequence':
                    self.assertTrue(task['correct'])
                    self.assertEqual(len(task['correct']),len(set(task['correct'])))
                    self.assertTrue(all(0<=x<len(task['options']) for x in task['correct']))
                    self.assertTrue(len(task['correct'])>=3)
                elif task['kind'] == 'pairs':
                    self.assertTrue(0<=task['correct']<len(task['options']))
                elif task['kind'] == 'code':
                    self.assertTrue(task['correct'].isdigit())
                else:
                    self.fail('Unknown kind: ' + task['kind'])

    def test_fifth_camera_gesture_persisted(self):
        gate=EventGate(required_frames=2)
        gate.update('Pointing_Up',0.99)
        gate.update('Pointing_Up',0.99)
        self.assertEqual(gate.snapshot()['gesture'],'Pointing_Up')
        self.assertIn('"Pointing_Up":4',self.controller)
        self.assertIn('if state.current != 19: return',self.controller)

    def test_no_secret_fifth_mouse_only_option(self):
        self.assertNotIn('Пятая строка сначала доступна мышью',self.controller)
        self.assertIn('Пять жестов',self.controller)

    def test_existing_menu_buttons_removed(self):
        menu=self.controller.split('func _show_menu() -> void:',1)[1].split('func _choose_difficulty()',1)[0]
        self.assertNotIn('ИМПОРТИРОВАТЬ УЛИКИ',menu)
        self.assertNotIn('КЛАССИЧЕСКИЙ РЕЖИМ',menu)
        self.assertIn('МАГАЗИН СКИНОВ',menu)
        self.assertIn('menu_art.png',self.controller)
        self.assertTrue((ROOT/'assets/ui/menu_art.png').is_file())

    def test_price_display_not_real_payments(self):
        self.assertIn('399 ₸',self.controller)
        self.assertIn('690 ₸',self.controller)
        self.assertIn('1090 ₸',self.controller)
        self.assertIn('ДЕМОНСТРАЦИЯ ЦЕН',self.controller)

    def test_campaign_saves_expert_results(self):
        self.assertIn('casework_%d',self.state)
        self.assertIn('casework_%d',self.controller)
        self.assertIn('casework_errors_%d',self.controller)
        self.assertIn('state.stats.mistakes',self.controller)
        self.assertIn('11 and str(evidence_id) == "usb": continue',self.controller)

    def test_physical_workspace_and_dedicated_scene(self):
        self.assertIn('register_item("casework"',self.map)
        self.assertIn('_solid(case_position',self.map)
        self.assertEqual(len(list((ROOT/'scenes/levels').glob('Level*.tscn'))),20)

    def test_all_voice_files_present_and_compilable(self):
        for f in ('ai_service/voice_service.py','ai_service/setup_voice.py','ai_service/voice_windows.ps1','SETUP_VOICE_WINDOWS.bat'):
            self.assertTrue((ROOT/f).exists(), f)
        for f in (ROOT/'ai_service').glob('*.py'):
            ast.parse(f.read_text('utf-8'))
        self.assertIn('🎤 ЗАДАТЬ ВОПРОС ГОЛОСОМ',(ROOT/'scripts/investigation/controller.gd').read_text('utf-8'))
        self.assertIn('🎤 СКАЗАТЬ ВОПРОС',self.game)

    def test_camera_does_not_use_cmd_for_automatic_start(self):
        source=self.game.split('func _start_gestures_if_needed() -> void:',1)[1].split('func _show_timeline()',1)[0]
        self.assertIn('OS.create_process("pythonw.exe"',source)
        self.assertNotIn('cmd.exe',source)
        service=(ROOT/'ai_service/gesture_service.py').read_text('utf-8')
        self.assertIn('self.path == "/frame"',service)
        self.assertIn('open_camera(idx)',service)

    def test_level_1_investigation_preserved(self):
        source=(ROOT/'scripts/investigation/controller.gd').read_text('utf-8')
        for needle in ['rules.deduce','rules.restore_message','_show_inspector','_show_board','_show_terminal','_show_packets']:
            self.assertIn(needle,source)

if __name__ == '__main__':
    unittest.main()
