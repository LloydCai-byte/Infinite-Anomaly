@echo off
chcp 65001 >nul
setlocal
cd /d "%~dp0"
set "COVER_RELEASE=%~dp0builds\InfiniteAnomaly-Pixel-Home-0.40.0"
set "APPDATA=%~dp0.local\room-cover-preview-runtime"
if not exist "%APPDATA%" mkdir "%APPDATA%"
start "" /D "%COVER_RELEASE%" "%COVER_RELEASE%\InfiniteAnomaly.exe" --main-pack "%COVER_RELEASE%\InfiniteAnomaly.pck" --script res://tools/preview_room_covers.gd --log-file "%~dp0.local\room-cover-preview.log" %*
exit /b
