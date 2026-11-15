@echo off
setlocal
chcp 65001 >nul
pushd "%~dp0" || exit /b 1
set "VOICE_PYTHON=python"
python -c "import sys; sys.exit(sys.version_info < (3, 11))" >nul 2>&1
if errorlevel 1 (
  set "VOICE_PYTHON=py -3"
  py -3 -c "import sys; sys.exit(sys.version_info < (3, 11))" >nul 2>&1
  if errorlevel 1 (
    echo ERROR: Install Python 3.11 or newer and add it to PATH.
    popd
    pause
    exit /b 1
  )
)
echo === Russian offline speech setup ===
%VOICE_PYTHON% -X utf8 -u "ai_service\setup_voice.py"
set "VOICE_STATUS=%errorlevel%"
popd
pause
exit /b %VOICE_STATUS%
