@echo off
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0flash.ps1" -PackageOnly
set "RESULT=%ERRORLEVEL%"
pause
exit /b %RESULT%
