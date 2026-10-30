@echo off
chcp 65001 >nul
setlocal
cd /d "%~dp0"
set "DEMO_RELEASE=%~dp0builds/InfiniteAnomaly-Pixel-Home-0.40.0"
set "APPDATA=%~dp0.local/pixel-home-demo-runtime"
if not exist "%APPDATA%" mkdir "%APPDATA%"
if not exist "%DEMO_RELEASE%/InfiniteAnomaly.exe" goto missing
if not exist "%DEMO_RELEASE%/InfiniteAnomaly.pck" goto missing
start "" /D "%DEMO_RELEASE%" "%DEMO_RELEASE%/InfiniteAnomaly.exe" --main-pack "%DEMO_RELEASE%/InfiniteAnomaly.pck" --script res://tools/run_home_demo.gd --log-file "%~dp0.local/pixel-home-demo.log" %*
exit /b
:missing
echo 流程演示运行包缺失，请运行 tools/build_ground_shadows.ps1 重新构建。
pause
exit /b 1
