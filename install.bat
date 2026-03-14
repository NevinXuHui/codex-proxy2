@echo off
setlocal enableextensions

REM Codex Proxy Windows Service Installer
REM This script installs the Codex Proxy as a Windows service using NSSM

set "PORT=9100"

echo === Codex Proxy Windows Service Installer ===
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
cd /d "%SCRIPT_DIR%"

REM Check if Node.js is installed
where node >nul 2>&1
if %errorLevel% neq 0 (
    echo Error: Node.js is not installed
    echo Please install Node.js first: https://nodejs.org/
    pause
    exit /b 1
)

echo Installation directory: %SCRIPT_DIR%
echo Port: %PORT%
echo.

REM Kill processes using the port
echo Checking for processes using port %PORT%...
for /f "tokens=5" %%a in ('netstat -aon ^| findstr ":%PORT% " ^| findstr "LISTENING"') do (
    echo Found process using port %PORT%: PID %%a
    echo Killing process...
    taskkill /F /PID %%a >nul 2>&1
)
timeout /t 1 /nobreak >nul
echo.

REM Build the project
echo Building project...

REM Build frontend
echo Building frontend...
cd /d "%SCRIPT_DIR%web"
call npm run build
if %errorLevel% neq 0 (
    echo Error: Frontend build failed
    pause
    exit /b 1
)

REM Build backend
echo Building backend...
cd /d "%SCRIPT_DIR%"
call npx tsc
if %errorLevel% neq 0 (
    echo Error: Backend build failed
    pause
    exit /b 1
)

echo Build completed.
echo.

REM Check if NSSM is available
set "NSSM_PATH=%SCRIPT_DIR%nssm.exe"
if not exist "%NSSM_PATH%" (
    echo NSSM not found. Downloading...
    echo.
    echo Please download NSSM from: https://nssm.cc/download
    echo Extract nssm.exe to: %SCRIPT_DIR%
    echo Then run this script again.
    pause
    exit /b 1
)

REM Service configuration
set "SERVICE_NAME=CodexProxy"
set "NODE_PATH="
for /f "delims=" %%i in ('where node') do set "NODE_PATH=%%i"
set "APP_PATH=%SCRIPT_DIR%dist\cli.js"

echo Installing Windows service...
echo Service name: %SERVICE_NAME%
echo Node.js path: %NODE_PATH%
echo App path: %APP_PATH%
echo.

REM Remove existing service if present
"%NSSM_PATH%" stop "%SERVICE_NAME%" >nul 2>&1
"%NSSM_PATH%" remove "%SERVICE_NAME%" confirm >nul 2>&1

REM Install service
"%NSSM_PATH%" install "%SERVICE_NAME%" "%NODE_PATH%" "%APP_PATH%"
if %errorLevel% neq 0 (
    echo Error: Failed to install service
    pause
    exit /b 1
)

REM Configure service
"%NSSM_PATH%" set "%SERVICE_NAME%" AppDirectory "%SCRIPT_DIR%"
"%NSSM_PATH%" set "%SERVICE_NAME%" DisplayName "Codex Proxy Server"
"%NSSM_PATH%" set "%SERVICE_NAME%" Description "Claude Codex Proxy Server for API access"
"%NSSM_PATH%" set "%SERVICE_NAME%" Start SERVICE_AUTO_START
"%NSSM_PATH%" set "%SERVICE_NAME%" AppStdout "%SCRIPT_DIR%logs\service-stdout.log"
"%NSSM_PATH%" set "%SERVICE_NAME%" AppStderr "%SCRIPT_DIR%logs\service-stderr.log"
"%NSSM_PATH%" set "%SERVICE_NAME%" AppRotateFiles 1
"%NSSM_PATH%" set "%SERVICE_NAME%" AppRotateBytes 10485760

REM Create logs directory
if not exist "%SCRIPT_DIR%logs" mkdir "%SCRIPT_DIR%logs"

echo.
echo === Installation Complete ===
echo.
echo Service commands:
echo   Start:   net start %SERVICE_NAME%
echo   Stop:    net stop %SERVICE_NAME%
echo   Restart: net stop %SERVICE_NAME% ^&^& net start %SERVICE_NAME%
echo   Status:  sc query %SERVICE_NAME%
echo   Remove:  %NSSM_PATH% remove %SERVICE_NAME% confirm
echo.
echo Service management:
echo   - Open Services: services.msc
echo   - Find "%SERVICE_NAME%" in the list
echo.
echo Logs location: %SCRIPT_DIR%logs\
echo.
echo The service is configured to start automatically on boot.
echo To start it now, run: net start %SERVICE_NAME%
echo.
pause
