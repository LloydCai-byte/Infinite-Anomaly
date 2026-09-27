@echo off
setlocal
cd /d "%~dp0"
if exist "%~dp0builds\InfiniteAnomaly-Reboot\InfiniteAnomaly.exe" (
  start "" /D "%~dp0builds\InfiniteAnomaly-Reboot" "%~dp0builds\InfiniteAnomaly-Reboot\InfiniteAnomaly.exe" --main-pack "%~dp0builds\InfiniteAnomaly-Reboot\InfiniteAnomaly.pck"
  exit /b 0
)
if not exist ".local" mkdir ".local"
set "ANOMALY_GODOT=D:\Godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64.exe"
if not exist "%ANOMALY_GODOT%" (
  echo Godot was not found. Open project.godot with Godot 4.4 or later.
  pause
  exit /b 1
)
start "" "%ANOMALY_GODOT%" --path "%~dp0." --log-file "%~dp0.local\reboot-game.log"
exit /b 0

