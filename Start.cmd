@echo off
setlocal
cd /d "%~dp0"
set "DoctorPowerShell=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if exist "%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe" set "DoctorPowerShell=%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe"
"%DoctorPowerShell%" -NoLogo -NoProfile -ExecutionPolicy RemoteSigned -File "%~dp0Start-Doctor.ps1"
if errorlevel 1 (
  echo.
  echo Startup failed. See README.md for downloaded-file or policy restrictions.
  pause
)
