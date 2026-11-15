"""Source-level and local protocol checks; not a Godot rendering test."""
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "ai_service"))
from gesture_service import EventGate


class GameRegressionTests(unittest.TestCase):
    def test_camera_third_person_limits(self):
        src = (ROOT / "scripts/player.gd").read_text(encoding="utf-8")
        self.assertIn('func reset_camera()', src)
        self.assertIn('lower_limit: float = -0.95 if first_person else -0.40', src)
        self.assertIn('arm.add_excluded_object(get_rid())', src)

    def test_bookshelves_have_actual_book_spines(self):
        src = (ROOT / "scripts/world_builder.gd").read_text(encoding="utf-8")
        self.assertIn('Individual visible book spines', src)
        self.assertIn('func bookshelf(pos: Vector3)', src)
        self.assertNotIn('make_box(pos + Vector3(0,1.4,0),Vector3(0.70,2.8,1.75)', src)

    def test_input_mapping(self):
        src = (ROOT / "scripts/game.gd").read_text(encoding="utf-8")
        self.assertIn('"camera_reset"', src)
        self.assertIn('"ВЕБ-КАМЕРА / MEDIAPIPE"', src)
        self.assertIn('"РУЧНОЙ РЕЗЕРВ — НЕ AI"', src)

    def test_camera_diagnostics_available(self):
        self.assertTrue((ROOT / 'CHECK_CAMERA_WINDOWS.bat').is_file())
        self.assertTrue((ROOT / 'ai_service/camera_diagnostics.py').is_file())

    def test_real_gesture_event_gate(self):
        gate = EventGate(required_frames=3)
        for _ in range(5):
            gate.update('Thumb_Up', 0.97)
        self.assertEqual(gate.snapshot()['event_id'], 1)
        gate.last_event_time -= 1.0
        for _ in range(5):
            gate.update('Victory', 0.94)
        self.assertEqual(gate.snapshot()['event_id'], 2)

    def test_false_confidence_rejected(self):
        gate = EventGate(required_frames=3)
        for _ in range(8):
            gate.update('Open_Palm', 0.2)
        self.assertEqual(gate.snapshot()['event_id'], 0)


if __name__ == '__main__':
    unittest.main()
