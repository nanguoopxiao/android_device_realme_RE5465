@echo off
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0flash.ps1" -Execute
set "RESULT=%ERRORLEVEL%"
echo.
if not "%RESULT%"=="0" echo Installation stopped. Read the error above before retrying.
pause
exit /b %RESULT%
