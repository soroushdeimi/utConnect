@echo off
:: Auto-elevate to Administrator and run uninstall.ps1
net session >nul 2>&1
if %errorLevel% neq 0 (
    pushd "%~dp0"
    powershell -Command "Start-Process cmd -ArgumentList '/c powershell -NoProfile -ExecutionPolicy Bypass -File .\uninstall.ps1 & pause' -Verb RunAs"
    exit /b
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0uninstall.ps1"
pause