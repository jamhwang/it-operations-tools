@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Net-Reachability.ps1"
endlocal
