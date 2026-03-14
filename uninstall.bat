@echo off
setlocal enableextensions

REM Codex Proxy Windows Service Uninstaller

echo === Codex Proxy Windows Service Uninstaller ===
echo.

REM Check if running as administrator
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Error: This script must be run as Administrator
    echo Right-click and select "Run as administrator"
    pause
    exit /b 1
)

REM Get script directory
set "SCRIPT_DIR=%~dp0"
set "NSSM_PATH=%SCRIPT_DIR%nssm.exe"
set "SERVICE_NAME=CodexProxy"

REM Check if NSSM exists
if not exist "%NSSM_PATH%" (
    echo NSSM not found at: %NSSM_PATH%
    echo Cannot uninstall service without NSSM.
    pause
    exit /b 1
)

REM Check if service exists
sc query "%SERVICE_NAME%" >nul 2>&1
if %errorLevel% neq 0 (
    echo Service "%SERVICE_NAME%" is not installed.
    pause
    exit /b 0
)

echo Stopping service...
"%NSSM_PATH%" stop "%SERVICE_NAME%"

echo Removing service...
"%NSSM_PATH%" remove "%SERVICE_NAME%" confirm

echo.
echo === Uninstallation Complete ===
echo Service has been removed successfully.
echo.
pause
