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
echo Step 3: Downloading Windows curl-impersonate...
echo.

REM Create bin directory if not exists
if not exist "bin" mkdir bin

REM Check if curl-impersonate already exists
if exist "bin\curl-impersonate.exe" (
    echo curl-impersonate.exe already exists, skipping download
    goto :build_complete
)

echo Downloading curl-impersonate for Windows...
set CURL_VERSION=v0.7.2
set CURL_WIN_URL=https://github.com/lwthiker/curl-impersonate/releases/download/%CURL_VERSION%/curl-impersonate-%CURL_VERSION%.x86_64-pc-windows-msvc.zip
set CURL_WIN_ZIP=bin\curl-impersonate-windows.zip

REM Download using PowerShell
powershell -Command "Invoke-WebRequest -Uri '%CURL_WIN_URL%' -OutFile '%CURL_WIN_ZIP%'"
if %ERRORLEVEL% NEQ 0 (
    echo Error: Failed to download curl-impersonate
    exit /b 1
)

echo Extracting...
powershell -Command "Expand-Archive -Path '%CURL_WIN_ZIP%' -DestinationPath 'bin\' -Force"

REM Find and rename the curl executable
for /r bin %%f in (curl-impersonate-chrome*.exe) do (
    move "%%f" "bin\curl-impersonate.exe" >nul 2>nul
)

REM Clean up
del "%CURL_WIN_ZIP%" >nul 2>nul

echo curl-impersonate.exe installed successfully

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
