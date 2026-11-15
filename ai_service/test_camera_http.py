"""No-camera integration test for local gesture status endpoint."""
from __future__ import annotations
import json
import threading
import time
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest.mock import patch
from urllib.request import urlopen
from zipfile import ZipFile
import gesture_service
from gesture_service import EventGate, start_server

class CameraHttpTests(unittest.TestCase):
    def test_corrupt_model_is_replaced_only_with_valid_archive(self):
        with TemporaryDirectory() as tmp:
            model = Path(tmp) / 'gesture_recognizer.task'
            model.write_bytes(b'x' * 1_100_000)
            with patch.object(gesture_service, 'MODEL_PATH', model):
                with self.assertRaises(FileNotFoundError):
                    gesture_service.ensure_model(False)

                def download(_url, target):
                    with ZipFile(target, 'w') as archive:
                        archive.writestr('first.tflite', b'fixture')
                        archive.writestr('second.tflite', b'fixture')

                with patch.object(gesture_service, 'urlretrieve', side_effect=download):
                    gesture_service.ensure_model(True)
                gesture_service.ensure_model(False)

    def test_restarted_service_has_distinct_session(self):
        self.assertNotEqual(EventGate().snapshot()['session_id'], EventGate().snapshot()['session_id'])

    def test_frame_endpoint_is_empty_until_real_frames_arrive(self):
        from urllib.error import HTTPError
        gate=EventGate()
        server=start_server(gate,0)
        try:
            url=f"http://127.0.0.1:{server.server_address[1]}/frame"
            with self.assertRaises(HTTPError) as exc:
                urlopen(url,timeout=3)
            self.assertEqual(exc.exception.code,503)
            test_image=b"fake-jpeg-test-only"
            gate.store_preview(test_image)
            with urlopen(url,timeout=3) as reply:
                self.assertEqual(reply.headers.get('Content-Type'),'image/jpeg')
                self.assertEqual(reply.read(),test_image)
        finally:
            server.shutdown();server.server_close()

    def test_starts_not_ready_until_webcam_is_initialized(self):
        gate=EventGate()
        server=start_server(gate,0)
        try:
            port=server.server_address[1]
            with urlopen(f'http://127.0.0.1:{port}/status',timeout=3) as reply:
                data=json.load(reply)
            self.assertEqual(data['mode'],'webcam')
            self.assertFalse(data['active'])
            self.assertEqual(data['status'],'starting')
            gate.active=True
            gate.status='ready'
            for _ in range(6): gate.update('Thumb_Up',0.99)
            with urlopen(f'http://127.0.0.1:{port}/gesture',timeout=3) as reply:
                data=json.load(reply)
            self.assertTrue(data['active'])
            self.assertEqual(data['event_id'],1)
            self.assertEqual(data['gesture'],'Thumb_Up')
        finally:
            server.shutdown();server.server_close()

if __name__=='__main__':unittest.main()
