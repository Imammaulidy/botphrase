# -*- coding: utf-8 -*-
"""
Phrase Extractor Engine
=======================
Modul cerdas ekstraksi 12 / 24 kata BIP-39 Seed Phrase:
1. Mendukung ekstraksi langsung dari elemen UI aplikasi (UI Automator XML).
2. Mendukung ekstraksi gambar screenshot / foto di galeri via Windows Native OCR Vision.
3. Dilengkapi kamus resmi 2.048 kata BIP-39 dan auto-koreksi typo OCR.
4. Mendukung multi-kolom (1 kolom atau 2 kolom vertikal / horizontal).
"""

import os
import sys
import re
import json
import logging
import subprocess
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import List, Dict, Tuple, Optional, Any
from datetime import datetime

logger = logging.getLogger("PhraseExtractor")

CURRENT_DIR = Path(__file__).resolve().parent
ROOT_DIR = CURRENT_DIR.parent
BIP39_FILE = CURRENT_DIR / "bip39_words.json"
OCR_PS1_FILE = CURRENT_DIR / "ocr_engine.ps1"

# Load 2.048 kata BIP-39
BIP39_WORDLIST: List[str] = []
BIP39_SET: set = set()

if BIP39_FILE.exists():
    try:
        with open(BIP39_FILE, "r", encoding="utf-8") as f:
            BIP39_WORDLIST = json.load(f)
        BIP39_SET = set(BIP39_WORDLIST)
    except Exception as e:
        logger.error(f"Gagal memuat {BIP39_FILE}: {e}")

# Kata-kata UI aplikasi yang sering muncul dan harus diabaikan jika bukan bagian dari phrase
UI_IGNORE_WORDS = {
    "cadangkan", "tuliskan", "sembunyikan", "teruskan", "batal", "lanjut",
    "kembali", "opsi", "setelan", "tentang", "wallet", "phrase", "seed",
    "backup", "copy", "salin", "lanjutkan", "ok", "done", "next", "confirm",
    "konfirmasi", "view", "show", "hide", "verify", "recovery", "mnemonic",
    "security", "warning", "never", "share", "write", "down", "keep", "safe",
    "cancel", "close", "tutup", "simpan", "save", "lewati", "skip", "screenshot",
    "screen", "galeri", "gallery", "photos", "foto", "album", "detail"
}

def levenshtein(s1: str, s2: str) -> int:
    """Hitung jarak Levenshtein antara dua string."""
    if len(s1) < len(s2):
        return levenshtein(s2, s1)
    if len(s2) == 0:
        return len(s1)
    prev = list(range(len(s2) + 1))
    for i, c1 in enumerate(s1):
        curr = [i + 1]
        for j, c2 in enumerate(s2):
            curr.append(min(prev[j + 1] + 1, curr[j] + 1, prev[j] + (c1 != c2)))
        prev = curr
    return prev[-1]

def match_bip39(word_raw: str, max_dist: int = 1) -> Optional[str]:
    """
    Cari kecocokan kata dengan kamus BIP-39:
    1. Cocok langsung.
    2. Substitusi karakter OCR (1->l/i, 0->o, |->l, vv->w).
    3. Koreksi Levenshtein distance ringan.
    """
    if not word_raw:
        return None
    
    clean_alpha = re.sub(r'[^a-zA-Z]', '', word_raw).lower()
    if clean_alpha in UI_IGNORE_WORDS or len(clean_alpha) < 3:
        return None

    if clean_alpha in BIP39_SET:
        return clean_alpha

    # Substitusi karakter OCR
    raw_lower = word_raw.lower()
    subs = {clean_alpha}
    if '1' in raw_lower:
        subs.add(re.sub(r'[^a-zA-Z]', '', raw_lower.replace('1', 'l')))
        subs.add(re.sub(r'[^a-zA-Z]', '', raw_lower.replace('1', 'i')))
    if '0' in raw_lower:
        subs.add(re.sub(r'[^a-zA-Z]', '', raw_lower.replace('0', 'o')))
    if 'vv' in raw_lower:
        subs.add(re.sub(r'[^a-zA-Z]', '', raw_lower.replace('vv', 'w')))
    if '|' in raw_lower:
        subs.add(re.sub(r'[^a-zA-Z]', '', raw_lower.replace('|', 'l')))
        subs.add(re.sub(r'[^a-zA-Z]', '', raw_lower.replace('|', 'i')))

    for s in subs:
        if s in BIP39_SET and s not in UI_IGNORE_WORDS:
            return s

    # Jarak Levenshtein
    if max_dist > 0 and len(clean_alpha) >= 3:
        candidates = []
        for w in BIP39_WORDLIST:
            if abs(len(w) - len(clean_alpha)) > max_dist:
                continue
            d = levenshtein(clean_alpha, w)
            if d <= max_dist:
                candidates.append((d, w))

        if candidates:
            # Urutkan jarak terkecil, lalu utamakan awalan/akhiran sama
            candidates.sort(key=lambda item: (
                item[0],
                0 if item[1][0] == clean_alpha[0] else 1,
                0 if item[1][-1] == clean_alpha[-1] else 1
            ))
            return candidates[0][1]

    return None

def normalize_number(num_str: str) -> Optional[int]:
    """
    Normalisasi angka dari token OCR:
    Mendukung format '1', '01', '1.', '01.', '(1)', '1)', '1:'
    Mendukung deteksi OCR typo angka: 'l.' -> 1, 'I.' -> 1, '|.' -> 1, 'l0.' -> 10, dll.
    """
    s = num_str.strip().strip(".()[]:#- ")
    if s.isdigit():
        val = int(s)
        if 1 <= val <= 24:
            return val
    # OCR Typos
    replacements = {
        "l": "1", "i": "1", "o": "0", "|": "1", "b": "6", "s": "5"
    }
    s_low = s.lower()
    for k, v in replacements.items():
        s_low = s_low.replace(k, v)
    if s_low.isdigit():
        val = int(s_low)
        if 1 <= val <= 24:
            return val
    return None

# ─────────────────────────────────────────────────────────────
# TAHAP 1: Ekstraksi dari XML UI Hierarchy (Aplikasi Langsung)
# ─────────────────────────────────────────────────────────────
def extract_from_xml(xml_content: str) -> List[str]:
    """Ekstrak 12 / 24 kata dari dump XML uiautomator."""
    if not xml_content or "<hierarchy" not in xml_content:
        return []
    try:
        root = ET.fromstring(xml_content)
    except Exception:
        return []

    raw_nodes: List[str] = []
    for node in root.iter('node'):
        t = (node.get('text') or '').strip()
        cd = (node.get('content-desc') or '').strip()
        if t:
            raw_nodes.append(t)
        elif cd:
            raw_nodes.append(cd)

    numbered_words: Dict[int, str] = {}

    for item in raw_nodes:
        lines = [x.strip() for x in item.splitlines() if x.strip()]
        # Format 1: "01\napple" atau "1\napple"
        if len(lines) == 2:
            num = normalize_number(lines[0])
            word = match_bip39(lines[1], max_dist=0)
            if num and word:
                numbered_words[num] = word
        elif len(lines) == 1:
            # Format 2: "01. apple" atau "1 apple" atau "1.apple"
            m = re.match(r'^([0-9lIo|]{1,3})[.:\s\)\-]+([a-zA-Z]+)$', lines[0])
            if m:
                num = normalize_number(m.group(1))
                word = match_bip39(m.group(2), max_dist=0)
                if num and word:
                    numbered_words[num] = word

    max_target = 24 if any(k > 12 for k in numbered_words.keys()) else 12
    if all(i in numbered_words for i in range(1, max_target + 1)):
        return [numbered_words[i] for i in range(1, max_target + 1)]

    # Format 3: Node-node kata murni berurutan
    pure_candidates = []
    for item in raw_nodes:
        clean = item.strip().lower()
        word = match_bip39(clean, max_dist=0)
        if word and word not in UI_IGNORE_WORDS:
            pure_candidates.append(word)

    if len(pure_candidates) in (12, 24):
        return pure_candidates

    return []

# ─────────────────────────────────────────────────────────────
# TAHAP 2: Ekstraksi dari OCR Vision (Screenshot Galeri)
# ─────────────────────────────────────────────────────────────
def extract_from_ocr_tokens(tokens: List[Dict[str, Any]]) -> List[str]:
    """
    Ekstrak 12 / 24 kata dari token hasil Windows Native OCR.
    Setiap token berisi: {"text": str, "x": int, "y": int, "w": int, "h": int}
    """
    if not tokens:
        return []

    num_nodes: List[Dict[str, Any]] = []
    word_nodes: List[Dict[str, Any]] = []

    for t in tokens:
        raw_text = t.get("text", "").strip()
        if not raw_text:
            continue
        
        x = t.get("x", 0)
        y = t.get("y", 0)
        w = t.get("w", 0)
        h = t.get("h", 0)
        cx = x + w / 2
        cy = y + h / 2

        # Cek apakah token berupa gabungan angka + kata: e.g. "1.apple" atau "1 apple"
        m_comb = re.match(r'^([0-9lIo|]{1,3})[.:\s\)\-]+([a-zA-Z]{3,})$', raw_text)
        if m_comb:
            n_val = normalize_number(m_comb.group(1))
            w_cand = match_bip39(m_comb.group(2), max_dist=1)
            if n_val and w_cand:
                num_nodes.append({"num": n_val, "x": x, "y": y, "w": w, "h": h, "cx": cx, "cy": cy, "bound_word": w_cand})
                continue

        # Cek apakah token adalah angka saja: e.g. "1", "01", "1.", "10."
        num_val = normalize_number(raw_text)
        if num_val and len(raw_text) <= 4:
            num_nodes.append({"num": num_val, "x": x, "y": y, "w": w, "h": h, "cx": cx, "cy": cy, "bound_word": None})
            continue

        # Cek apakah token adalah kata BIP-39
        w_bip = match_bip39(raw_text, max_dist=1)
        if w_bip:
            word_nodes.append({
                "word": w_bip,
                "raw": raw_text,
                "x": x, "y": y, "w": w, "h": h, "cx": cx, "cy": cy,
                "used": False
            })

    # Tentukan apakah target 12 atau 24 kata
    target_count = 24 if any(n["num"] > 12 for n in num_nodes) else 12
    matched_results: Dict[int, str] = {}

    # 1. Pasangkan nomor yang sudah punya bound_word
    for nn in num_nodes:
        if nn.get("bound_word") and (1 <= nn["num"] <= target_count):
            matched_results[nn["num"]] = nn["bound_word"]

    # 2. Pasangkan node nomor dengan kata terdekat di sebelah kanan (atau di bawahnya)
    for nn in num_nodes:
        n = nn["num"]
        if n in matched_results or n > target_count:
            continue

        best_cand = None
        best_dist = float("inf")

        for wn in word_nodes:
            if wn["used"]:
                continue
            dy = abs(wn["cy"] - nn["cy"])
            dx = wn["cx"] - nn["cx"]
            max_dy = max(nn["h"], wn["h"], 30) * 2.5

            # Kasus A: Kata di sebelah kanan (paling umum)
            if dx > 0 and dy <= max_dy:
                dist = (dy * 3.0) + dx
                if dist < best_dist:
                    best_dist = dist
                    best_cand = wn
            # Kasus B: Kata tepat di bawah nomor (vertical stack)
            elif dy > 0 and abs(dx) <= max(nn["w"], 40):
                dist = (dy * 2.0) + (abs(dx) * 2.0) + 200
                if dist < best_dist:
                    best_dist = dist
                    best_cand = wn

        if best_cand:
            matched_results[n] = best_cand["word"]
            best_cand["used"] = True

    # Jika semua 12 atau 24 kata sudah lengkap
    if len(matched_results) == target_count and all(i in matched_results for i in range(1, target_count + 1)):
        return [matched_results[i] for i in range(1, target_count + 1)]

    # 3. Jika hampir lengkap (misal 10 atau 11 dari 12 kata), isi celah yang hilang dari kata yang tersisa
    if len(matched_results) >= (target_count - 2):
        missing_slots = [i for i in range(1, target_count + 1) if i not in matched_results]
        unused_words = [wn for wn in word_nodes if not wn["used"]]
        if len(unused_words) >= len(missing_slots):
            unused_words.sort(key=lambda w: (w["cy"], w["cx"]))
            for slot in missing_slots:
                matched_results[slot] = unused_words.pop(0)["word"]
            if all(i in matched_results for i in range(1, target_count + 1)):
                return [matched_results[i] for i in range(1, target_count + 1)]

    # 4. Fallback jika nomor tidak terdeteksi (format chip/grid murni)
    unique_words = []
    seen = set()
    for w_obj in word_nodes:
        if w_obj["word"] not in seen:
            seen.add(w_obj["word"])
            unique_words.append(w_obj)

    if len(unique_words) in (12, 24):
        xs = [w["cx"] for w in unique_words]
        min_x, max_x = min(xs), max(xs)
        mid_x = (min_x + max_x) / 2

        col_left = [w for w in unique_words if w["cx"] < mid_x]
        col_right = [w for w in unique_words if w["cx"] >= mid_x]

        if len(col_left) == len(col_right) and len(col_left) in (6, 12):
            col_left.sort(key=lambda w: w["cy"])
            col_right.sort(key=lambda w: w["cy"])
            return [w["word"] for w in col_left] + [w["word"] for w in col_right]
        else:
            unique_words.sort(key=lambda w: (round(w["cy"] / 40) * 40, w["cx"]))
            return [w["word"] for w in unique_words]

    return []

# ─────────────────────────────────────────────────────────────
# MASTER EXTRACTION WORKFLOW
# ─────────────────────────────────────────────────────────────
def run_screen_ocr(adb_bin: str, tmp_img: Optional[Path] = None) -> List[Dict[str, Any]]:
    """Ambil screenshot layar HP dan jalankan Windows Native OCR."""
    if tmp_img is None:
        tmp_img = Path(os.environ.get("TEMP", r"C:\Windows\Temp")) / "phone_screen_ocr.png"

    try:
        subprocess.run([adb_bin, "shell", "screencap", "-p", "/sdcard/screen.png"], capture_output=True, timeout=8)
        subprocess.run([adb_bin, "pull", "/sdcard/screen.png", str(tmp_img)], capture_output=True, timeout=8)
    except Exception as e:
        logger.error(f"Gagal mengambil screenshot ADB: {e}")
        return []

    if not tmp_img.exists() or tmp_img.stat().st_size == 0:
        return []

    if sys.platform == "win32" and OCR_PS1_FILE.exists():
        try:
            cmd = [
                "powershell", "-NoProfile", "-ExecutionPolicy", "Bypass",
                "-File", str(OCR_PS1_FILE),
                "-ImagePath", str(tmp_img)
            ]
            res = subprocess.run(cmd, capture_output=True, text=True, timeout=12)
            out = (res.stdout or "").strip()
            if out.startswith("[") and out.endswith("]"):
                return json.loads(out)
        except Exception as e:
            logger.error(f"OCR PowerShell Error: {e}")

    return []

def extract_seed_phrase_smart(adb_bin: str, run_cmd_func, conn_info: Dict[str, Any]) -> Dict[str, Any]:
    """
    Kombinasi cerdas Tahap 1 (UI Automator) dan Tahap 2 (OCR Vision).
    """
    mode = conn_info.get("mode", "PC_USB")
    dump_cmd = "uiautomator dump /sdcard/dump.xml"

    # --- TAHAP 1: Coba baca elemen UI langsung ---
    logger.info("[*] Tahap 1: Membaca teks UI aplikasi langsung (uiautomator)...")
    if mode == "ROOT":
        run_cmd_func(["su", "-c", dump_cmd], timeout=8)
        res_xml = run_cmd_func(["su", "-c", "cat /sdcard/dump.xml"], timeout=8)
    elif mode == "SHIZUKU":
        rish = ["sh", "/data/data/com.termux/files/usr/bin/rish"]
        env = os.environ.copy()
        env["RISH_APPLICATION_ID"] = "com.termux"
        run_cmd_func(rish + ["-c", dump_cmd], timeout=10, env=env)
        res_xml = run_cmd_func(rish + ["-c", "cat /sdcard/dump.xml"], timeout=10, env=env)
    else:
        run_cmd_func([adb_bin, "shell", "uiautomator", "dump", "/sdcard/dump.xml"], timeout=8)
        res_xml = run_cmd_func([adb_bin, "shell", "cat", "/sdcard/dump.xml"], timeout=8)

    xml_words = extract_from_xml(res_xml.stdout or "")
    if len(xml_words) in (12, 24):
        logger.info(f"[+] Tahap 1 Berhasil: Terdeteksi {len(xml_words)} kata via UI Automator.")
        return {
            "success": True,
            "words": xml_words,
            "phrase": " ".join(xml_words),
            "count": len(xml_words),
            "method": "UI Automator (Aplikasi Langsung)",
            "source_type": "UI_ELEMENTS"
        }

    # --- TAHAP 2: Jika Tahap 1 tidak menemukan 12/24 kata, aktifkan OCR Vision (Screenshot Galeri) ---
    logger.info("[*] Tahap 1 tidak menemukan phrase. Tahap 2: Menjalankan OCR Vision (Screenshot Layar)...")
    ocr_tokens = run_screen_ocr(adb_bin)
    ocr_words = extract_from_ocr_tokens(ocr_tokens)

    if len(ocr_words) in (12, 24):
        logger.info(f"[+] Tahap 2 Berhasil: Terdeteksi {len(ocr_words)} kata via Windows OCR Vision.")
        return {
            "success": True,
            "words": ocr_words,
            "phrase": " ".join(ocr_words),
            "count": len(ocr_words),
            "method": "Windows OCR Vision (Screenshot / Galeri)",
            "source_type": "OCR_SCREENSHOT"
        }

    # Jika kedua tahap belum menemukan 12/24 kata
    detected_preview = xml_words if xml_words else [t.get("text") for t in ocr_tokens[:10]]
    return {
        "success": False,
        "error": f"Tidak dapat mendeteksi 12 atau 24 kata BIP-39 di layar (UI: {len(xml_words)} kata, OCR: {len(ocr_words)} kata). Pastikan halaman 12/24 kata Seed Phrase atau foto screenshotnya terbuka penuh di layar HP!",
        "detected_words": detected_preview
    }

def main():
    if sys.platform == "win32":
        try:
            sys.stdout.reconfigure(encoding='utf-8')
        except Exception:
            pass

    print("=" * 60)
    print("[*] MEMBACA SEED PHRASE (AUTO DETEKSI UI & FOTO OCR)...")
    print("=" * 60)

    candidates = [
        str(CURRENT_DIR / "adb.exe"),
        "adb"
    ]
    adb_bin = "adb"
    for c in candidates:
        if os.path.exists(c):
            adb_bin = c
            break

    res_dev = subprocess.run([adb_bin, "devices"], capture_output=True, text=True)
    lines_dev = [l for l in res_dev.stdout.splitlines() if "\tdevice" in l]
    if not lines_dev:
        print("[!] Tidak ada HP yang terhubung via ADB.")
        print("--> Pastikan USB debugging aktif dan HP terhubung via USB/WiFi ADB!")
        sys.exit(1)

    device_id = lines_dev[0].split()[0]
    conn_info = {"connected": True, "mode": "PC_USB", "device": device_id}

    def run_cmd(cmd_list, timeout=12, env=None):
        try:
            return subprocess.run(cmd_list, capture_output=True, text=True, timeout=timeout, env=env)
        except Exception as e:
            return subprocess.CompletedProcess(args=cmd_list, returncode=1, stdout="", stderr=str(e))

    res = extract_seed_phrase_smart(adb_bin, run_cmd, conn_info)
    if not res.get("success"):
        print(f"\n[!] Gagal: {res.get('error')}")
        sys.exit(1)

    phrase_str = res["phrase"]
    method = res.get("method", "Unknown")
    ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    print(f"\n[+] BERHASIL MENGAMBIL {res['count']} KATA SEED PHRASE:")
    print(f"[*] Jalur Deteksi: {method}")
    print("-" * 60)
    print(phrase_str)
    print("-" * 60)

    backup_file = ROOT_DIR / "hasil.txt"
    with open(backup_file, "a", encoding="utf-8") as f:
        f.write(f"========================================\n")
        f.write(f"WAKTU BACKUP: {ts} ({method})\n")
        f.write(f"========================================\n")
        f.write(f"{phrase_str}\n\n")

    print(f"\n[+] Teks otomatis tersimpan ke:")
    print(f"--> {backup_file}\n")
    sys.exit(0)

if __name__ == "__main__":
    main()

