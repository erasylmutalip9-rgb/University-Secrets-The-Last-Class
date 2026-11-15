"""Manual acceptance test using REAL webcam frames, never synthetic gestures.
Run after setup: py -3 ai_service/validate_camera.py --camera 0
Each target gets 3 s preparation and 5 s measurement; report contains metrics, no photos.
"""
from pathlib import Path
import argparse
import json
import time
from datetime import datetime, timezone
from gesture_service import MODEL_PATH, open_camera, ensure_model


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--camera', type=int, default=0)
    args = parser.parse_args()
    output = Path(__file__).with_name('real_camera_acceptance.json')
    output.unlink(missing_ok=True)
    import cv2
    import mediapipe as mp
    from mediapipe.tasks import python
    from mediapipe.tasks.python import vision
    ensure_model(False)
    cap = open_camera(args.camera)
    if cap is None:
        raise RuntimeError('No real webcam frames; test NOT RUN. Check Windows camera access.')
    report = {'time': datetime.now(timezone.utc).isoformat(), 'source': 'real_webcam', 'mediapipe': mp.__version__, 'samples': []}
    options = vision.GestureRecognizerOptions(base_options=python.BaseOptions(model_asset_buffer=MODEL_PATH.read_bytes()), running_mode=vision.RunningMode.VIDEO, num_hands=1)
    start = time.monotonic()
    stamp = -1
    try:
        with vision.GestureRecognizer.create_from_options(options) as model:
            for target in ['Closed_Fist', 'Victory', 'Open_Palm', 'Thumb_Up', 'Pointing_Up', 'NO_HAND']:
                print(f'Prepare {target}; hold for 5 seconds after countdown.', flush=True)
                target_start = time.monotonic()
                total, correct = 0, 0
                while time.monotonic() - target_start < 8:
                    ok, frame = cap.read()
                    if not ok or frame is None:
                        raise RuntimeError('Real camera stream lost; test incomplete.')
                    stamp = max(stamp+1, int((time.monotonic()-start)*1000))
                    rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
                    result = model.recognize_for_video(mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb), stamp)
                    category = result.gestures[0][0] if result.gestures and result.gestures[0] else None
                    actual = category.category_name if category else 'NO_HAND'
                    confidence = float(category.score) if category else 1.0
                    elapsed = time.monotonic()-target_start
                    if elapsed >= 3:
                        total += 1
                        correct += int(actual == target and confidence >= 0.67)
                    cv2.putText(frame, f'{target}: {max(0,3-int(elapsed))} | {actual} {confidence:.2f}', (10,30),cv2.FONT_HERSHEY_SIMPLEX,0.6,(255,255,255),2)
                    cv2.imshow('Real gesture acceptance - Q cancels',frame)
                    if cv2.waitKey(1) & 0xFF == ord('q'):
                        raise RuntimeError('Cancelled: test incomplete, not PASS.')
                ratio = correct/total if total else 0
                report['samples'].append({'expected':target,'frames':total,'correct':correct,'accuracy':round(ratio,3),'pass':total>=10 and ratio>=0.8})
    finally:
        cap.release()
        cv2.destroyAllWindows()
    report['pass'] = all(x['pass'] for x in report['samples'])
    output.write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(report,ensure_ascii=False,indent=2))
    return 0 if report['pass'] else 1

if __name__ == '__main__':
    raise SystemExit(main())
