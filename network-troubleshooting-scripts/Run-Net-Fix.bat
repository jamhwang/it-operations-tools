@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Net-Fix.ps1"
endlocal
