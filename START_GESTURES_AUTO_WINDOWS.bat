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
if not exist "ai_service" (
  echo ERROR: ai_service folder missing.
  pause
  exit /b 1
)
%GAME_PYTHON% -u "ai_service\launch_camera.py"
if errorlevel 1 (
  echo.
  echo Gesture webcam failed. Please read ai_service\camera_diagnostics.txt
  echo Close Zoom/OBS/Telegram, check Windows privacy permissions.
  pause
)
