"""No-camera unit checks for debouncing and gesture-to-event flow."""
import unittest
from gesture_service import EventGate


class GateTests(unittest.TestCase):
    def test_one_event_per_hold(self):
        gate = EventGate(required_frames=3)
        for _ in range(12):
            gate.update("Thumb_Up", 0.99)
        self.assertEqual(gate.snapshot()["event_id"], 1)

    def test_confidence_gate(self):
        gate = EventGate(required_frames=2)
        for _ in range(10):
            gate.update("Victory", 0.31)
        self.assertEqual(gate.snapshot()["event_id"], 0)

    def test_event_keeps_committed_gesture_when_live_frame_changes(self):
        gate = EventGate(required_frames=2)
        gate.update("Thumb_Up", 0.99)
        gate.update("Thumb_Up", 0.99)
        gate.update("Victory", 0.90)  # Not stable; HTTP must not mislabel previous event.
        self.assertEqual(gate.snapshot()["gesture"], "Thumb_Up")
        self.assertEqual(gate.snapshot()["observed_gesture"], "Victory")
        gate.update("", 0)
        self.assertEqual(gate.snapshot()["gesture"], "Thumb_Up")
        self.assertEqual(gate.snapshot()["event_id"], 1)

    def test_fifth_gesture_is_real_event(self):
        gate = EventGate(required_frames=2)
        gate.update("Pointing_Up",0.99)
        gate.update("Pointing_Up",0.99)
        self.assertEqual(gate.snapshot()["gesture"],"Pointing_Up")
        self.assertEqual(gate.snapshot()["event_id"],1)

    def test_unrecognized(self):
        gate = EventGate(required_frames=2)
        for _ in range(5):
            gate.update("ILoveYou", 0.99)
        self.assertEqual(gate.snapshot()["event_id"], 0)


if __name__ == "__main__":
    unittest.main()
