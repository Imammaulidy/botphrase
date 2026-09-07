@echo off
title BUNGKUS BOT EXTRACT PHRASE (VERSI KOSONGAN)
cd /d "%~dp0"

echo ============================================================
echo   BUNGKUS BOT EXTRACT PHRASE KE ZIP (VERSI KOSONGAN)
echo ============================================================
echo.
echo [*] Memproses dan membungkus file bersih...
echo [*] Mengecualikan: hasil.txt, .git, cache, dan riwayat backup
echo.

powershell -NoProfile -ExecutionPolicy Bypass -Command "$core = (Get-Location).Path; $root = Split-Path -Parent $core; $parent = Split-Path -Parent $root; $zipFolder = Join-Path $parent 'FILE ZIP BOT'; if (-not (Test-Path $zipFolder)) { $zipFolder = $parent }; $outZip = Join-Path $zipFolder 'BOT EXTRACT PHRASE (KOSONGAN).zip'; $tempDir = Join-Path $env:TEMP ('bot_pack_' + [guid]::NewGuid().ToString('N')); $packRoot = Join-Path $tempDir 'BOT EXTRACT PHRASE'; New-Item -ItemType Directory -Path $packRoot -Force | Out-Null; $packCore = Join-Path $packRoot 'core'; New-Item -ItemType Directory -Path $packCore -Force | Out-Null; @('run.bat','run.sh','README.md','.gitignore') | ForEach-Object { $f = Join-Path $root $_; if (Test-Path $f) { Copy-Item $f -Destination $packRoot -Force } }; Get-ChildItem -Path $core -File | Where-Object { $_.Name -notmatch '\.pyc$' } | ForEach-Object { Copy-Item $_.FullName -Destination $packCore -Force }; if (Test-Path $outZip) { Remove-Item $outZip -Force }; Compress-Archive -Path $packRoot -DestinationPath $outZip -Force; $copyParent = Join-Path $parent 'BOT EXTRACT PHRASE (KOSONGAN).zip'; Copy-Item $outZip -Destination $copyParent -Force; Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue; Write-Host ''; Write-Host '[+] SUKSES! File bot versi kosongan berhasil dibungkus.' -ForegroundColor Green; Write-Host ('[1] ' + $outZip) -ForegroundColor Yellow; Write-Host ('[2] ' + $copyParent) -ForegroundColor Yellow; Write-Host ('Ukuran file: ' + [math]::Round((Get-Item $outZip).Length / 1MB, 2) + ' MB') -ForegroundColor Cyan; Write-Host '';"

echo ============================================================
echo Selesai!
echo ============================================================
pause