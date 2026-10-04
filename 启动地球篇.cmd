@echo off
chcp 65001 >nul
setlocal
cd /d "%~dp0"
if not exist "%~dp0.local" mkdir "%~dp0.local"
if exist "%~dp0builds\InfiniteAnomaly-Earth-0.11.0\InfiniteAnomaly.exe" (
  if not exist "%~dp0builds\InfiniteAnomaly-Earth-0.11.0\InfiniteAnomaly.pck" (
    echo Game data is missing: builds\InfiniteAnomaly-Earth-0.11.0\InfiniteAnomaly.pck
    pause
    exit /b 1
  )
  start "" /D "%~dp0builds\InfiniteAnomaly-Earth-0.11.0" "%~dp0builds\InfiniteAnomaly-Earth-0.11.0\InfiniteAnomaly.exe" --main-pack "%~dp0builds\InfiniteAnomaly-Earth-0.11.0\InfiniteAnomaly.pck" --log-file "%~dp0.local\earth-game.log" %*
  exit /b
)
set "EARTH_GODOT=D:\Godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64.exe"
if not exist "%EARTH_GODOT%" (
  echo Godot was not found. Open project.godot with Godot 4.4 or later.
  pause
  exit /b 1
)
start "" "%EARTH_GODOT%" --path "%~dp0." res://scenes/earth/main.tscn --log-file "%~dp0.local\earth-game.log" %*
exit /b
