# BOT EXTRACT PHRASE

Bot terminal untuk mengekstrak 12/24 kata **BIP-39 Seed Phrase** dari layar HP Android via ADB.

## Fitur
- **UI Automator** — Membaca teks langsung dari elemen UI aplikasi wallet
- **Windows OCR Vision** — Membaca screenshot/foto galeri via Windows Native OCR
- **Auto-Koreksi** — Kamus 2.048 kata BIP-39 + koreksi typo OCR (Levenshtein)
- **Multi-Layout** — Mendukung 1 kolom, 2 kolom, grid, dan format bernomor

## Persyaratan
- Windows 10/11 (untuk OCR Vision)
- Python 3.8+
- HP Android terhubung via USB/WiFi ADB (USB Debugging aktif)

## Cara Pakai (Windows)

1. Hubungkan HP Android via USB (aktifkan USB Debugging)
2. Buka halaman seed phrase / foto screenshot di layar HP
3. Klik dua kali `run.bat`
4. Hasil otomatis tersimpan ke `hasil.txt`
5. Tekan **ENTER** untuk ekstrak berikutnya, atau tutup jendela untuk berhenti

## Cara Pakai (Termux Android)

`ash
bash termux_run.sh
`

## Struktur Folder

`
BOT EXTRACT PHRASE/
├── run.bat              # Launcher Windows (klik 2x)
├── termux_run.sh        # Launcher Termux Android
├── hasil.txt            # Output hasil ekstraksi (auto-generated)
└── core/                # Engine & dependencies
    ├── phrase_extractor.py   # Smart engine utama (BIP-39 + OCR)
    ├── ocr_engine.ps1        # Windows Native OCR helper
    ├── parse_seed.ps1        # PowerShell fallback engine
    ├── AMBIL_SEED_PHRASE.py   # Python entry point
    ├── bip39_words.json      # Kamus 2.048 kata BIP-39
    ├── adb.exe               # Android Debug Bridge
    ├── AdbWinApi.dll          # ADB dependency
    └── AdbWinUsbApi.dll       # ADB dependency
`

## Peringatan

> **JANGAN** bagikan file `hasil.txt` ke siapapun. File ini berisi seed phrase wallet yang bersifat sangat rahasia.