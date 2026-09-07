#!/data/data/com.termux/files/usr/bin/bash
cd "$(dirname "$0")"

# Cek & install Python
if ! command -v python >/dev/null 2>&1; then
    echo "[*] Menginstall Python..."
    pkg update -y && pkg install python -y
fi

termux-wake-lock 2>/dev/null

while true; do
    clear
    echo "============================================================"
    echo "   BOT EXTRACT PHRASE"
    echo "============================================================"
    echo ""
    python core/phrase_extractor.py
    echo ""
    echo "============================================================"
    echo " [+] Tekan [ENTER] untuk ekstrak selanjutnya"
    echo " [+] Atau tekan CTRL+C untuk berhenti"
    echo "============================================================"
    read -r
done