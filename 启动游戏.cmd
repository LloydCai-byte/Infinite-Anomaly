@echo off
chcp 65001 >nul
setlocal
call "%~dp0启动主神空间.cmd" %*
exit /b %errorlevel%
