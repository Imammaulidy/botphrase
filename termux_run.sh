#!/data/data/com.termux/files/usr/bin/bash
# ==============================================================================
#   BOT EXTRACT PHRASE - LAUNCHER UNTUK TERMUX (ANDROID)
#   Jalankan di Termux: bash termux_run.sh
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

termux-wake-lock 2>/dev/null

echo "============================================================"
echo "    BOT EXTRACT PHRASE - TERMUX ANDROID LAUNCHER"
echo "============================================================"
echo ""

# Pastikan Python terinstall
if ! command -v python >/dev/null 2>&1; then
    echo "[*] Menginstall Python..."
    pkg update -y && pkg install python -y
fi

echo ""
echo "[+] Menjalankan Bot Extract Phrase..."
echo ""

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
