@echo off
chcp 65001 >nul
cd /d "%~dp0"
set "GODOT_CMD=godot"
if defined GODOT_EXE set "GODOT_CMD=%GODOT_EXE%"
where "%GODOT_CMD%" >nul 2>nul
if exist "%GODOT_CMD%" ver >nul
if errorlevel 1 (
  if exist "%~dp0Godot_v4.7.2-stable_win64.exe" (
    set "GODOT_CMD=%~dp0Godot_v4.7.2-stable_win64.exe"
  ) else (
    echo ERROR: Godot executable not found in PATH.
    echo Open Godot Editor: Project - Export - Windows Desktop - Export Project.
    pause
    exit /b 1
  )
)
if not exist dist mkdir dist
"%GODOT_CMD%" --headless --path "." --export-release "Windows Desktop" "dist\Tayny_Universiteta.exe"
if errorlevel 1 (
  echo ERROR: Export failed. Install Windows Export Templates from Godot Editor.
  pause
  exit /b 1
)
if not exist "dist\ai_service" mkdir "dist\ai_service"
xcopy "ai_service" "dist\ai_service" /E /I /Y >nul
if errorlevel 1 (
  echo ERROR: Could not copy AI service files.
  pause
  exit /b 1
)
copy /Y "START_GESTURES_AUTO_WINDOWS.bat" "dist\" >nul
copy /Y "SETUP_VOICE_WINDOWS.bat" "dist\" >nul
copy /Y "CHECK_VOICE_WINDOWS.bat" "dist\" >nul
copy /Y "SETUP_CAMERA_WINDOWS.bat" "dist\" >nul
copy /Y "VALIDATE_REAL_CAMERA_WINDOWS.bat" "dist\" >nul
copy /Y "CHECK_CAMERA_WINDOWS.bat" "dist\" >nul
copy /Y "GESTURES_SETUP.md" "dist\" >nul
copy /Y "README.md" "dist\" >nul
echo.
echo ===============================================
echo Export and AI helper files copied to dist folder.
echo Verify Tayny_Universiteta.exe + .pck + ai_service on another Windows computer.
echo Camera tries automatic setup on first puzzle E; stable Internet may be needed once.
echo For offline voice recognition run SETUP_VOICE_WINDOWS.bat once.
echo ===============================================
pause
exit /b 0
