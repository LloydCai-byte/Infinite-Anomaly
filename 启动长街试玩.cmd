@echo off
setlocal
cd /d "%~dp0"
if not exist ".local" mkdir ".local"
if exist "%~dp0builds\InfiniteAnomaly-Reboot-Full-0.5.3\InfiniteAnomaly.exe" (
  start "" /D "%~dp0builds\InfiniteAnomaly-Reboot-Full-0.5.3" "%~dp0builds\InfiniteAnomaly-Reboot-Full-0.5.3\InfiniteAnomaly.exe" --main-pack "%~dp0builds\InfiniteAnomaly-Reboot-Full-0.5.3\InfiniteAnomaly.pck" --log-file "%~dp0.local\street-play.log" -- --street-preview
  exit /b 0
)
set "ANOMALY_GODOT=D:\Godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64.exe"
if not exist "%ANOMALY_GODOT%" (
  echo Godot was not found. Open project.godot with Godot 4.4 or later.
  pause
  exit /b 1
)
start "" "%ANOMALY_GODOT%" --path "%~dp0." --log-file "%~dp0.local\street-play.log" -- --street-preview
exit /b 0
