@echo off
REM Codex Proxy Windows Build Script
REM This script builds the project for Windows

echo === Codex Proxy Windows Build Script ===
echo.

REM Check if Node.js is installed
where node >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo Error: Node.js is not installed
    echo Please install Node.js first: https://nodejs.org/
    exit /b 1
)

echo Step 1: Building frontend...
echo.
cd web
call npm run build
if %ERRORLEVEL% NEQ 0 (
    echo Error: Frontend build failed
    exit /b 1
)
cd ..

echo.
echo Step 2: Building backend...
echo.
call npx tsc
if %ERRORLEVEL% NEQ 0 (
    echo Error: Backend build failed
    exit /b 1
)

echo.
echo Step 3: Setting up curl-impersonate...
echo.

REM Use the setup script to download curl-impersonate
call npm run setup
if %ERRORLEVEL% NEQ 0 (
    echo Warning: curl-impersonate setup failed, but build can continue
    echo You may need to run 'npm run setup' manually later
)

:build_complete
echo.
echo === Build Complete ===
echo.
echo Build artifacts:
echo   - dist\           (Backend compiled files)
echo   - web\dist\       (Frontend compiled files)
echo   - bin\curl-impersonate.exe (Windows TLS tool)
echo.
echo To run the server:
echo   node dist\index.js
echo.
echo Or use the provided run.bat script
echo.
pause
