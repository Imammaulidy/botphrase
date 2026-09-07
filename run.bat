@echo off
title BOT EXTRACT PHRASE (AUTO LOOP)
cd /d "%~dp0"

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
