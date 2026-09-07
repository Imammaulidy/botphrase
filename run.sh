#!/data/data/com.termux/files/usr/bin/bash
# ==============================================================================
#   BOT EXTRACT PHRASE - LAUNCHER UNTUK TERMUX (ANDROID)
#   Jalankan di Termux: bash run.sh
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

termux-wake-lock 2>/dev/null

echo "============================================================"
echo "    BOT EXTRACT PHRASE - TERMUX ANDROID"
echo "============================================================"
echo ""

# 1. Pastikan Python terinstall
if ! command -v python >/dev/null 2>&1; then
    echo "[*] Python belum terinstall, sedang menginstall..."
    pkg update -y && pkg install python -y
fi

# 2. Pastikan ADB (android-tools) terinstall
if ! command -v adb >/dev/null 2>&1; then
    echo "[*] ADB belum terinstall, sedang menginstall android-tools..."
    pkg install android-tools -y
fi

# 3. Cek dependensi modul jika ada di core/requirements.txt
if [ -f "core/requirements.txt" ]; then
    pip install -r "core/requirements.txt" --quiet 2>/dev/null
fi

echo ""
echo "[+] Semua modul siap! Menjalankan bot..."
echo ""

# 4. Loop ekstraksi
while true; do
    python core/phrase_extractor.py
    echo ""
    echo "============================================================"
    echo " [+] Buka wallet / foto berikutnya di HP Anda..."
    echo " [+] Tekan [ENTER] untuk LANGSUNG AMBIL phrase selanjutnya!"
    echo " (Atau tekan CTRL+C jika sudah selesai)"
    echo "============================================================"
    read -r
done
