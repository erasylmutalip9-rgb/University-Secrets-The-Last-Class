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
%GAME_PYTHON% "ai_service\setup_camera.py"
if errorlevel 1 (
 echo Setup failed. Read the error above.
 pause
 exit /b 1
)
echo Setup complete. Test the webcam before the presentation.
pause
