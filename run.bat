@echo off
setlocal enableextensions

echo Building project...

rem Build frontend
cd /d "%~dp0web"
call npm run build
if errorlevel 1 (
    echo Frontend build failed!
    exit /b 1
)

rem Build backend
cd /d "%~dp0"
call npx tsc
if errorlevel 1 (
    echo Backend build failed!
    exit /b 1
)

echo Starting server...
call npm start

endlocal
