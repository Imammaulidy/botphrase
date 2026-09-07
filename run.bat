@echo off
title BOT EXTRACT PHRASE
cd /d "%~dp0"

:: Cek Python
where python >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] Python tidak ditemukan.
    echo [!] Download dan install Python dari: https://www.python.org/downloads/
    echo [!] Centang "Add Python to PATH" saat install.
    pause
    exit /b 1
)

:: Cek versi Python >= 3
for /f "tokens=2 delims= " %%v in ('python --version 2^>^&1') do set PYVER=%%v
echo [+] Python %PYVER% terdeteksi.

:loop
cls
echo ============================================================
echo    BOT EXTRACT PHRASE
echo ============================================================
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "core\parse_seed.ps1"
echo.
echo ============================================================
echo  [+] Tekan [ENTER] untuk ekstrak selanjutnya
echo  [+] Atau tutup jendela ini untuk berhenti
echo ============================================================
pause >nul
goto loop
