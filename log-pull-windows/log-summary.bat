@echo off
setlocal EnableExtensions

rem Wrapper for log-summary.ps1
set SCRIPT=%~dp0log-summary.ps1

if not exist "%SCRIPT%" (
  echo Missing %SCRIPT%
  exit /b 1
)

for /f "usebackq delims=" %%P in (`powershell -NoProfile -Command "[Environment]::GetFolderPath('Desktop')"` ) do set DESKTOP=%%P
set OUTDIR=%DESKTOP%\log-pull-output

powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" -OutDir "%OUTDIR%"
echo Output: "%OUTDIR%"
endlocal
