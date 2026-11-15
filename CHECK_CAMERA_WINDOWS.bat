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
echo =========================================
echo   CAMERA DIAGNOSTICS - ECHO / UNIVERSITY
echo =========================================
if /i "%~1"=="--model-only" (
  %GAME_PYTHON% -X utf8 ai_service\camera_diagnostics.py --model-only
) else (
  %GAME_PYTHON% -X utf8 ai_service\camera_diagnostics.py --preview
)
set "CAMERA_STATUS=%errorlevel%"
pause
exit /b %CAMERA_STATUS%
