import sqlite3
import json
import sys

if sys.platform == "win32" and hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

con = sqlite3.connect("lensescan.db")
row = con.execute("SELECT image_filename, raw_ocr_json, declarations_json, summary FROM inspections WHERE image_filename LIKE '%18%'").fetchone()
if row:
    print(f"File: {row[0]}")
    ocr_items = json.loads(row[1])
    decls = json.loads(row[2])
    print(f"\n--- Extracted OCR text samples ({len(ocr_items)} total): ---")
    for item in ocr_items[:35]:
        print("  ", item["text"])
    print("\n--- Declarations: ---")
    for d in decls:
        print(f"  {d['field_name']}: compliant={d['compliant']}, detected={d.get('detected_value')}, violations={d.get('violations')}")
