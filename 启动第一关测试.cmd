@echo off
chcp 65001 >nul
setlocal
cd /d "%~dp0"
call "%~dp0启动地球篇.cmd" %* -- --earth-stage01-preview
exit /b %errorlevel%
