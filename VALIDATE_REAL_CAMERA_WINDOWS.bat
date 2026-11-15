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
%GAME_PYTHON% -X utf8 "ai_service\validate_camera.py" %*
set "CAMERA_STATUS=%errorlevel%"
if errorlevel 1 echo Camera acceptance FAILED or incomplete. Read errors above.
pause
exit /b %CAMERA_STATUS%
