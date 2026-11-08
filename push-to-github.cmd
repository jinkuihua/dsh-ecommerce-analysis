@echo off
setlocal
title Push dsh-ecommerce-analysis to GitHub
chcp 65001 >nul
cd /d "%~dp0"
echo ============================================================
echo   Push dsh-ecommerce-analysis to your GitHub repository
echo   Folder: %~dp0
echo ============================================================
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0push-to-github.ps1" %*
set "RC=%ERRORLEVEL%"
echo.
if not "%RC%"=="0" echo [push] PowerShell exited with code %RC%. See messages above.
echo [push] Press any key to close this window...
pause >nul
exit /b %RC%