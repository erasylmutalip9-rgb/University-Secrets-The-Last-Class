@echo off
chcp 65001 >nul
cd /d "%~dp0"
setlocal
set "GAME_PYTHON=python"
python -c "import sys; sys.exit(sys.version_info < (3, 11))" >nul 2>&1
if errorlevel 1 (
  set "GAME_PYTHON=py -3"
  py -3 -c "import sys; sys.exit(sys.version_info < (3, 11))" >nul 2>&1
  if errorlevel 1 (
    echo ERROR: Install Python 3.11 or newer and add it to PATH.
    pause
    exit /b 1
  )
)
echo ===========================================
echo    ECHO / REAL HAND GESTURE RECOGNITION
echo ===========================================
echo Camera must be allowed in Windows privacy settings.
echo Close Zoom / OBS / Telegram / other webcam apps.
echo.
%GAME_PYTHON% -m pip install -r ai_service\requirements.txt
if errorlevel 1 (
 echo.
 echo [ERROR] MediaPipe / OpenCV installation failed.
 echo Run CHECK_CAMERA_WINDOWS.bat and send the output.
 pause
 exit /b 1
)
echo.
echo Running MediaPipe on camera index 0...
echo If your camera is index 1, start manually:
echo %GAME_PYTHON% ai_service\gesture_service.py --camera 1 --download-model --preview
echo.
%GAME_PYTHON% ai_service\gesture_service.py --camera 0 --download-model --preview
if errorlevel 1 (
 echo.
 echo [ERROR] Real camera recognition did not start.
 echo Run CHECK_CAMERA_WINDOWS.bat and attach camera_diagnostics.txt.
)
pause
