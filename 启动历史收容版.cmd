@echo off
setlocal
cd /d "%~dp0"
if exist "%~dp0builds\InfiniteAnomaly-Full\InfiniteAnomaly.exe" (
  start "" /D "%~dp0builds\InfiniteAnomaly-Full" "%~dp0builds\InfiniteAnomaly-Full\InfiniteAnomaly.exe" --main-pack "%~dp0builds\InfiniteAnomaly-Full\InfiniteAnomaly.pck"
  exit /b 0
)
set "ANOMALY_GODOT=D:\Godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64.exe"
if not exist "%ANOMALY_GODOT%" (
  echo Godot was not found. Open scenes/containment/main.tscn with Godot 4.4 or later.
  pause
  exit /b 1
)
start "" "%ANOMALY_GODOT%" --path "%~dp0." res://scenes/containment/main.tscn
exit /b 0
