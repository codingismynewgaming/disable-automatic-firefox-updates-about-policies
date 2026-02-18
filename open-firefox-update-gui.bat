@echo off
setlocal EnableExtensions

set "GUI_SCRIPT=%~dp0firefox-update-toggle-gui.ps1"

if not exist "%GUI_SCRIPT%" (
    powershell.exe -NoLogo -NoProfile -Command "Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.MessageBox]::Show('Missing file: %GUI_SCRIPT%','Firefox Update Toggle') | Out-Null"
    exit /b 1
)

start "" powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -STA -File "%GUI_SCRIPT%"
exit /b 0
