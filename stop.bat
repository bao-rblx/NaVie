@echo off
title Stop NaVie
echo Stopping NaVie and releasing port 8000 / 8080...
taskkill /F /IM NaVie.exe >nul 2>&1
for /f "tokens=5" %%a in ('netstat -aon ^| findstr :8000') do (
    taskkill /F /PID %%a >nul 2>&1
)
for /f "tokens=5" %%a in ('netstat -aon ^| findstr :8080') do (
    taskkill /F /PID %%a >nul 2>&1
)
echo Done! All NaVie processes stopped.
timeout /t 2 >nul
