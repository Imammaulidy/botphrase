import os
import sys
from pathlib import Path

# Pastikan UTF-8 encoding
if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass

CURRENT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(CURRENT_DIR))

import phrase_extractor as pe

if __name__ == "__main__":
    pe.main()

