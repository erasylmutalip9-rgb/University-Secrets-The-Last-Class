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
    echo ОШИБКА: положите Godot_v4.7.2-stable_win64.exe рядом с проектом или добавьте Godot в PATH.
    pause
    exit /b 1
  )
)
echo [1/4] Импорт и проверка скриптов...
"%GODOT_CMD%" --headless --editor --path "." --quit > GODOT_RK2_CHECK.log 2>&1
if errorlevel 1 goto fail

echo [2/4] Проверка классификатора...
"%GODOT_CMD%" --headless --path "." --script res://tests/test_intent.gd >> GODOT_RK2_CHECK.log 2>&1
if errorlevel 1 goto fail

echo [3/4] Проверка физики переходов и комнат...
"%GODOT_CMD%" --headless --path "." --script res://tests/test_collision.gd >> GODOT_RK2_CHECK.log 2>&1
if errorlevel 1 goto fail

echo [4/4] Проверка предметов и открываемых шкафчиков...
"%GODOT_CMD%" --headless --path "." --script res://tests/test_interactions.gd >> GODOT_RK2_CHECK.log 2>&1
if errorlevel 1 goto fail

echo [OK] Пакет тестов завершился успешно. Лог: GODOT_RK2_CHECK.log
type GODOT_RK2_CHECK.log
pause
exit /b 0
:fail
echo [ОШИБКА] Тесты обнаружили проблему. Смотрите GODOT_RK2_CHECK.log
type GODOT_RK2_CHECK.log
pause
exit /b 1
