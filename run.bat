@echo off
title BOT EXTRACT PHRASE
cd /d "%~dp0"

:: 1. Cek Python
where python >nul 2>&1
if %errorlevel% neq 0 (
    echo ============================================================
    echo  [!] ERROR: Python tidak ditemukan di sistem!
    echo  [!] Download dan install dari: https://www.python.org/downloads/
    echo  [!] WAJIB CENTANG "Add Python to PATH" saat instalasi.
    echo ============================================================
    pause
    exit /b 1
)

:: 2. Cek & install requirements jika ada modul di core\requirements.txt
if exist "core\requirements.txt" (
    python -m pip install -r "core\requirements.txt" --quiet >nul 2>&1
)

:: 3. Jalankan loop ekstraksi
:loop
cls
powershell -NoProfile -ExecutionPolicy Bypass -File "core\parse_seed.ps1"
echo.
echo ============================================================
echo  [+] Buka wallet / foto berikutnya di HP Anda...
echo  [+] Tekan [ENTER] untuk LANGSUNG AMBIL phrase selanjutnya!
echo  (Atau tutup jendela ini jika sudah selesai)
echo ============================================================
pause >nul
goto loop
