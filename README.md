# BOT EXTRACT PHRASE

Bot terminal untuk membaca dan mengekstrak 12/24 kata **BIP-39 Seed Phrase** dari layar HP Android (tampilan langsung aplikasi maupun screenshot/foto galeri) via ADB.

---

## 📱 Instalasi & Penggunaan di Termux (Android)

Buka aplikasi Termux Anda, lalu jalankan perintah di bawah ini secara berurutan:

1. Update sistem dan install Git, Python & ADB:
```bash
pkg update -y && pkg upgrade -y
pkg install git python android-tools -y
```

2. Clone repositori ini:
```bash
git clone https://github.com/Imammaulidy/botphrase.git
cd botphrase
```

3. Jalankan Bot:
```bash
bash run.sh
```

Gunakan tombol `Ctrl + C` (atau tekan `Volume Bawah + C`) untuk menghentikan bot.

---

## 💻 Instalasi & Penggunaan di Windows (PC/Laptop)

1. Pastikan sudah menginstall [Python 3](https://www.python.org/downloads/) (wajib centang **Add Python to PATH** saat instalasi).
2. Hubungkan HP Android ke PC via kabel USB dan pastikan **USB Debugging** aktif.
3. Buka halaman wallet atau foto screenshot seed phrase di layar HP Anda.
4. Clone repositori ini:
```cmd
git clone https://github.com/Imammaulidy/botphrase.git
cd botphrase
```
5. Jalankan Bot:
```cmd
run.bat
```

Tekan **ENTER** di terminal untuk mengekstrak phrase berikutnya secara berulang, atau tutup jendela terminal jika sudah selesai.

---

## 📁 Hasil Ekstraksi

Setiap seed phrase yang berhasil diekstrak otomatis tersimpan rapi di:
```text
hasil.txt
```

> ⚠️ **Peringatan Keamanan:** File `hasil.txt` berisi data rahasia seed phrase wallet. Jaga file ini baik-baik dan jangan pernah membagikannya ke publik.
