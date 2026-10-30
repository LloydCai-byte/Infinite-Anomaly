@echo off
chcp 65001 >nul
setlocal
cd /d "%~dp0"
set "HOME_RELEASE=%~dp0builds\InfiniteAnomaly-Pixel-Home-0.40.0"
set "APPDATA=%~dp0.local\pixel-hyakki-runtime"
if not exist "%APPDATA%" mkdir "%APPDATA%"
if not exist "%HOME_RELEASE%\InfiniteAnomaly.exe" goto missing
if not exist "%HOME_RELEASE%\InfiniteAnomaly.pck" goto missing
start "" /D "%HOME_RELEASE%" "%HOME_RELEASE%\InfiniteAnomaly.exe" --main-pack "%HOME_RELEASE%\InfiniteAnomaly.pck" --log-file "%~dp0.local\pixel-home-game.log" %*
exit /b
:missing
echo 主神空间运行包缺失，请运行 tools\build_ground_shadows.ps1 重新构建。
pause
exit /b 1
