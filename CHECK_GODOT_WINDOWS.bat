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
    echo Godot CLI не найден.
    echo Откройте папку проекта через Import в Godot и проверьте Output / Debugger.
    pause
    exit /b 1
  )
)
echo Проверяем проект через Godot headless editor...
"%GODOT_CMD%" --headless --editor --path "." --quit > "%~dp0GODOT_CHECK_LOG.txt" 2>&1
set "RESULT=%errorlevel%"
type "%~dp0GODOT_CHECK_LOG.txt"
echo.
echo Код завершения: %RESULT%
echo Лог: GODOT_CHECK_LOG.txt
pause
exit /b %RESULT%
