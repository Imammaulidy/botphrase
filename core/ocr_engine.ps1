param (
    [string]$ImagePath = "$env:TEMP\phone_screen_ocr.png"
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if (-not (Test-Path $ImagePath)) {
    Write-Output "[]"
    exit 0
}

Add-Type -AssemblyName System.Runtime.WindowsRuntime
$asTaskGeneric = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { 
    $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' 
}

function Await($WinRtTask, $ResultType) {
    $asTask = $asTaskGeneric.MakeGenericMethod($ResultType)
    $netTask = $asTask.Invoke($null, @($WinRtTask))
    $netTask.Wait(-1) | Out-Null
    $netTask.Result
}

[Windows.Media.Ocr.OcrEngine, Windows.Foundation.UniversalApiContract, ContentType = WindowsRuntime] | Out-Null
[Windows.Graphics.Imaging.BitmapDecoder, Windows.Foundation.UniversalApiContract, ContentType = WindowsRuntime] | Out-Null
[Windows.Storage.StorageFile, Windows.Foundation.UniversalApiContract, ContentType = WindowsRuntime] | Out-Null

try {
    $engine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromUserProfileLanguages()
    if (-not $engine) {
        $avail = [Windows.Media.Ocr.OcrEngine]::AvailableRecognizerLanguages
        if ($avail.Count -gt 0) {
            $engine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromLanguage($avail[0])
        }
    }

    if (-not $engine) {
        Write-Output "[]"
        exit 0
    }

    $fileTask = [Windows.Storage.StorageFile]::GetFileFromPathAsync($ImagePath)
    $file = Await $fileTask ([Windows.Storage.StorageFile])

    $streamTask = $file.OpenAsync([Windows.Storage.FileAccessMode]::Read)
    $stream = Await $streamTask ([Windows.Storage.Streams.IRandomAccessStream])

    $decoderTask = [Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($stream)
    $decoder = Await $decoderTask ([Windows.Graphics.Imaging.BitmapDecoder])

    $bitmapTask = $decoder.GetSoftwareBitmapAsync()
    $bitmap = Await $bitmapTask ([Windows.Graphics.Imaging.SoftwareBitmap])

    $ocrTask = $engine.RecognizeAsync($bitmap)
    $ocrResult = Await $ocrTask ([Windows.Media.Ocr.OcrResult])

    $items = New-Object System.Collections.Generic.List[PSObject]
    foreach ($line in $ocrResult.Lines) {
        foreach ($w in $line.Words) {
            $t = $w.Text.Trim()
            if ($t.Length -gt 0) {
                $items.Add([PSCustomObject]@{
                    text = $t
                    x = [int]$w.BoundingRect.X
                    y = [int]$w.BoundingRect.Y
                    w = [int]$w.BoundingRect.Width
                    h = [int]$w.BoundingRect.Height
                })
            }
        }
    }

    $items | ConvertTo-Json -Compress
} catch {
    Write-Output "[]"
}
