@echo off
title NaVie Launcher
cd /d "%~dp0"

echo ============================================================
echo   NaVie - Vietnam Multimodal Route Planner & Driver App
echo ============================================================

REM Check if standalone exe exists
if exist "dist\NaVie\NaVie.exe" (
    echo Launching standalone NaVie executable...
    start "" "dist\NaVie\NaVie.exe"
    exit /b 0
)

REM Check if python is available
where python >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Python was not found in your system PATH!
    echo Please install Python 3.11 or run the standalone package in dist\NaVie.
    pause
    exit /b 1
)

echo Starting NaVie via Python...
python run_app.py
pause
