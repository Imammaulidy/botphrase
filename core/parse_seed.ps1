# Pure PowerShell Seed Phrase Extractor with Built-in Windows OCR Vision
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Add-Type -AssemblyName System.Runtime.WindowsRuntime
$asTaskGeneric = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' }

function Await($WinRtTask, $ResultType) {
    $asTask = $asTaskGeneric.MakeGenericMethod($ResultType)
    $netTask = $asTask.Invoke($null, @($WinRtTask))
    $netTask.Wait(-1) | Out-Null
    $netTask.Result
}

[Windows.Media.Ocr.OcrEngine, Windows.Foundation.UniversalApiContract, ContentType = WindowsRuntime] | Out-Null
[Windows.Graphics.Imaging.BitmapDecoder, Windows.Foundation.UniversalApiContract, ContentType = WindowsRuntime] | Out-Null
[Windows.Storage.StorageFile, Windows.Foundation.UniversalApiContract, ContentType = WindowsRuntime] | Out-Null

$BinDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Split-Path -Parent $BinDir

# Utamakan Smart Engine dengan BIP-39 Dictionary & OCR Vision
$pyExe = (Get-Command python -ErrorAction SilentlyContinue).Source
if ($pyExe -and (Test-Path "$BinDir\phrase_extractor.py")) {
    & $pyExe "$BinDir\phrase_extractor.py"
    exit $LASTEXITCODE
}

$Adb = "$BinDir\adb.exe"
if (-not (Test-Path $Adb)) { $Adb = "adb" }

$BackupFile = "$RootDir\hasil.txt"

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "[*] MEMBACA SEED PHRASE (AUTO DETEKSI UI & FOTO OCR)..." -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Cyan

# Cek device
$devs = & $Adb devices
$hasDev = $false
foreach ($line in $devs) {
    if ($line -match "\s+device$") { $hasDev = $true; break }
}

if (-not $hasDev) {
    Write-Host "[!] Tidak ada HP yang terhubung via ADB." -ForegroundColor Red
    Write-Host "--> Pastikan kabel USB terpasang dan Debugging USB aktif!" -ForegroundColor Yellow
    exit 1
}

$words = New-Object System.Collections.Generic.List[string]

# --- TAHAP 1: Coba baca via Accessibility Tree (Cepat & Langsung) ---
& $Adb shell uiautomator dump /sdcard/dump.xml | Out-Null
$xmlRaw = & $Adb shell cat /sdcard/dump.xml

if ($xmlRaw -and ($xmlRaw.Contains("<hierarchy"))) {
    try {
        [xml]$xml = $xmlRaw
        $nodes = $xml.SelectNodes("//node")
        
        foreach ($node in $nodes) {
            $t = $node.GetAttribute("text")
            if (-not $t) { $t = $node.GetAttribute("content-desc") }
            if (-not $t) { continue }
            
            $t = $t.Trim()
            $lines = $t -split "`r?`n"
            
            # Format "01\nfaint"
            if ($lines.Count -eq 2 -and ($lines[0] -match '^\d+$') -and ($lines[1] -match '^[a-zA-Z]+$')) {
                $words.Add($lines[1].ToLower())
            }
            # Format "01. faint"
            elseif ($lines.Count -eq 1) {
                $parts = $lines[0] -split "\s+"
                if ($parts.Count -eq 2 -and ($parts[0].Replace('.', '') -match '^\d+$') -and ($parts[1] -match '^[a-zA-Z]+$')) {
                    $words.Add($parts[1].ToLower())
                }
            }
        }
        
        if ($words.Count -ne 12 -and $words.Count -ne 24) {
            $cand = New-Object System.Collections.Generic.List[string]
            $ignore = @("cadangkan", "tuliskan", "sembunyikan", "teruskan", "batal", "lanjut", "kembali", "opsi", "setelan", "tentang", "wallet", "phrase", "seed")
            foreach ($node in $nodes) {
                $t = $node.GetAttribute("text")
                if (-not $t) { $t = $node.GetAttribute("content-desc") }
                if (-not $t) { continue }
                $clean = $t.Trim().ToLower()
                if (($clean -match '^[a-zA-Z]+$') -and $clean.Length -ge 2 -and $clean.Length -le 12) {
                    if (-not ($ignore -contains $clean)) {
                        $cand.Add($clean)
                    }
                }
            }
            if ($cand.Count -eq 12 -or $cand.Count -eq 24) {
                $words = $cand
            }
        }
    } catch {}
}

# --- TAHAP 2: Jika Tahap 1 gagal (Layar adalah Foto/Galeri/Screenshot), Gunakan Windows Native OCR Vision ---
if ($words.Count -ne 12 -and $words.Count -ne 24) {
    Write-Host "[*] Mendeteksi gambar/screenshot di layar, menjalankan OCR Vision..." -ForegroundColor Gray
    
    $tmpImg = "$env:TEMP\phone_screen_ocr.png"
    & $Adb shell screencap -p /sdcard/screen.png
    & $Adb pull /sdcard/screen.png $tmpImg | Out-Null
    
    if (Test-Path $tmpImg) {
        try {
            $engine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromUserProfileLanguages()
            if ($engine) {
                $fileTask = [Windows.Storage.StorageFile]::GetFileFromPathAsync($tmpImg)
                $file = Await $fileTask ([Windows.Storage.StorageFile])
                
                $streamTask = $file.OpenAsync([Windows.Storage.FileAccessMode]::Read)
                $stream = Await $streamTask ([Windows.Storage.Streams.IRandomAccessStream])
                
                $decoderTask = [Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($stream)
                $decoder = Await $decoderTask ([Windows.Graphics.Imaging.BitmapDecoder])
                
                $bitmapTask = $decoder.GetSoftwareBitmapAsync()
                $bitmap = Await $bitmapTask ([Windows.Graphics.Imaging.SoftwareBitmap])
                
                $ocrTask = $engine.RecognizeAsync($bitmap)
                $ocrResult = Await $ocrTask ([Windows.Media.Ocr.OcrResult])
                
                # Kumpulkan semua kata OCR beserta posisi koordinatnya
                $allOcrWords = New-Object System.Collections.Generic.List[PSObject]
                foreach ($line in $ocrResult.Lines) {
                    foreach ($w in $line.Words) {
                        $allOcrWords.Add([PSCustomObject]@{
                            Text = $w.Text.Trim()
                            X = $w.BoundingRect.X
                            Y = $w.BoundingRect.Y
                        })
                    }
                }
                
                # Cari nomor 1 sampai 12 (atau 24) dan pasangkan dengan kata di sebelah kanannya
                $matchedWords = @{}
                $maxNum = 12
                
                # Cek apakah 12 atau 24
                $has24 = $false
                foreach ($ow in $allOcrWords) {
                    if ($ow.Text -eq "24" -or $ow.Text -eq "24.") { $has24 = $true; break }
                }
                if ($has24) { $maxNum = 24 }
                
                for ($i = 1; $i -le $maxNum; $i++) {
                    $s1 = "$i"
                    $s2 = "$($i.ToString('00'))"
                    $s3 = "$i."
                    $s4 = "$($i.ToString('00'))."
                    
                    # Cari node nomor
                    $numNode = $allOcrWords | Where-Object { ($_.Text -eq $s1 -or $_.Text -eq $s2 -or $_.Text -eq $s3 -or $_.Text -eq $s4) } | Select-Object -First 1
                    
                    if ($numNode) {
                        # Cari kata alfabet murni terdekat di sebelah kanannya (X >= numNode.X dan selisih Y < 60)
                        $candidate = $allOcrWords | Where-Object {
                            ($_.Text -match '^[a-zA-Z]+$') -and 
                            ($_.X -gt $numNode.X) -and 
                            ([Math]::Abs($_.Y - $numNode.Y) -le 60) -and
                            ($_.Text.Length -ge 2)
                        } | Sort-Object { [Math]::Abs($_.Y - $numNode.Y) * 2 + ($_.X - $numNode.X) } | Select-Object -First 1
                        
                        if ($candidate) {
                            $matchedWords[$i] = $candidate.Text.ToLower()
                        }
                    }
                }
                
                if ($matchedWords.Keys.Count -eq $maxNum) {
                    $words.Clear()
                    for ($i = 1; $i -le $maxNum; $i++) {
                        $words.Add($matchedWords[$i])
                    }
                }
            }
        } catch {
            Write-Host "[!] OCR Error: $_" -ForegroundColor Red
        }
    }
}

if ($words.Count -ne 12 -and $words.Count -ne 24) {
    Write-Host "[!] Peringatan: Ditemukan $($words.Count) kata (bukan 12/24 kata seed phrase standar)." -ForegroundColor Red
    if ($words.Count -gt 0) {
        Write-Host "Kata terdeteksi: $($words -join ' ')" -ForegroundColor Gray
    } else {
        Write-Host "[!] Pastikan layar sedang menampilkan halaman 12 kata Seed Phrase atau foto screenshotnya!" -ForegroundColor Yellow
    }
    exit 1
}

$phraseLine = $words -join " "
$timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")

Write-Host ""
Write-Host "[+] BERHASIL MENGAMBIL SEED PHRASE (SINGLE LINE):" -ForegroundColor Green
Write-Host "------------------------------------------------------------" -ForegroundColor Cyan
Write-Host $phraseLine -ForegroundColor White
Write-Host "------------------------------------------------------------" -ForegroundColor Cyan

$outputContent = "========================================`nWAKTU BACKUP: $timestamp`n========================================`n$phraseLine`n`n"
[System.IO.File]::AppendAllText($BackupFile, $outputContent, [System.Text.Encoding]::UTF8)

Write-Host ""
Write-Host "[+] Teks otomatis tersimpan ke:" -ForegroundColor Green
Write-Host "--> $BackupFile`n" -ForegroundColor Yellow
