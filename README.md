# BOT EXTRACT PHRASE

Ekstrak 12/24 kata BIP-39 Seed Phrase dari layar HP Android via ADB.

---

## Windows

1. Install [Python 3](https://www.python.org/downloads/) (centang **Add to PATH**)
2. Hubungkan HP via USB (aktifkan **USB Debugging**)
3. Buka halaman seed phrase di layar HP
4. Jalankan:

`at
run.bat
`

---

## Termux (Android)

`ash
pkg install git -y
git clone https://github.com/Imammaulidy/botphrase.git
cd botphrase
bash run.sh
`

---

Hasil tersimpan otomatis di `hasil.txt`
