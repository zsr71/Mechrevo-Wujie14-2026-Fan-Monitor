@echo off
"C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0fan_rpm_monitor.ps1"
if errorlevel 1 (
    echo.
    echo RPM monitor failed to start. See:
    echo %~dp0fan_rpm_monitor.log
    pause
)
