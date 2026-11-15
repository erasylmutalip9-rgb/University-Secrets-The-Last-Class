@echo off
chcp 65001 >nul
cd /d "%~dp0"
where godot >nul 2>nul
if %errorlevel%==0 (
  godot --editor --path "."
  exit /b
)
if exist "%~dp0Godot_v4.7.2-stable_win64.exe" (
  "%~dp0Godot_v4.7.2-stable_win64.exe" --editor --path "."
  exit /b
)
echo.
echo [!] Godot не найден в PATH или рядом с проектом.
echo Откройте редактор Godot 4.7.2, нажмите Import и выберите project.godot.
echo https://godotengine.org/download/archive/4.7.2-stable/
echo.
pause
