@echo off
setlocal EnableExtensions

set "REG_KEY=HKLM\SOFTWARE\Policies\Mozilla\Firefox"
set "VALUE_NAME=DisableAppUpdate"

if /I "%~1"=="disable" goto :disable
if /I "%~1"=="enable" goto :enable
if /I "%~1"=="status" goto :status
if /I "%~1"=="help" goto :usage
if /I "%~1"=="--help" goto :usage
if /I "%~1"=="-h" goto :usage
if "%~1"=="" goto :menu

echo Unknown option: %~1
echo.
goto :usage

:menu
echo Firefox Update Policy Toggle
echo ============================
echo Tip: Run open-firefox-update-gui.bat for a one-click GUI.
echo.
echo 1^) Disable Firefox updates
echo 2^) Enable Firefox updates
echo 3^) Show current status
echo 4^) Exit
echo.
set /p choice=Select an option [1-4]: 
if "%choice%"=="1" goto :disable
if "%choice%"=="2" goto :enable
if "%choice%"=="3" goto :status
if "%choice%"=="4" exit /b 0
echo Invalid selection.
echo.
goto :menu

:disable
call :require_admin
if errorlevel 1 exit /b 1

reg add "%REG_KEY%" /v "%VALUE_NAME%" /t REG_DWORD /d 1 /f >nul 2>&1
if errorlevel 1 (
    echo Failed to disable Firefox updates.
    exit /b 1
)
echo Firefox updates are now DISABLED by policy.
echo Restart Firefox, then check about:policies.
exit /b 0

:enable
call :require_admin
if errorlevel 1 exit /b 1

reg query "%REG_KEY%" /v "%VALUE_NAME%" >nul 2>&1
if errorlevel 1 (
    echo Firefox updates are already ENABLED.
    exit /b 0
)

reg delete "%REG_KEY%" /v "%VALUE_NAME%" /f >nul 2>&1
if errorlevel 1 (
    echo Failed to enable Firefox updates.
    exit /b 1
)
echo Firefox updates are now ENABLED.
echo Restart Firefox, then check about:policies.
exit /b 0

:status
reg query "%REG_KEY%" /v "%VALUE_NAME%" >nul 2>&1
if errorlevel 1 (
    echo Status: ENABLED ^(auto-update allowed^)
    exit /b 0
)

set "CURRENT_VALUE="
for /f "tokens=3" %%A in ('reg query "%REG_KEY%" /v "%VALUE_NAME%" ^| find /I "%VALUE_NAME%"') do set "CURRENT_VALUE=%%A"

if /I "%CURRENT_VALUE%"=="0x1" (
    echo Status: DISABLED ^(policy blocks updates^)
    exit /b 0
)

if /I "%CURRENT_VALUE%"=="0x0" (
    echo Status: ENABLED ^(policy value is 0^)
    exit /b 0
)

echo Status: Unknown ^(value=%CURRENT_VALUE%^)
exit /b 0

:require_admin
net session >nul 2>&1
if errorlevel 1 (
    echo This action requires Administrator privileges.
    echo Right-click this file and select "Run as administrator".
    exit /b 1
)
exit /b 0

:usage
echo Usage:
echo   %~nx0 disable
echo   %~nx0 enable
echo   %~nx0 status
echo.
echo GUI launcher:
echo   open-firefox-update-gui.bat
echo.
echo No argument starts interactive mode.
exit /b 1
