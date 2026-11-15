@echo off
chcp 65001 >nul
cd /d "%~dp0"
REM If Godot is not on PATH, set GODOT_EXE to its full executable path.
python -c "import sys; sys.exit(sys.version_info < (3, 11))" >nul 2>&1
if errorlevel 1 (
 py -3 "tests\run_campaign.py"
) else (
 python "tests\run_campaign.py"
)
set "TEST_STATUS=%errorlevel%"
if errorlevel 1 (
 echo TESTS FAILED. Read tests\LAST_RUN.json.
) else (
 echo TESTS PASSED. This does not replace visual or real-camera testing.
)
pause
exit /b %TEST_STATUS%
