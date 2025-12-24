@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Net-Collect.ps1"
endlocal
