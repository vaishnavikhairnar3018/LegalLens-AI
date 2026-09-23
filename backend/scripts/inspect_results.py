import sqlite3
import json
import sys

if sys.platform == "win32" and hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

con = sqlite3.connect("lensescan.db")
rows = con.execute("SELECT id, image_filename, overall_compliant, compliant_fields, non_compliant_fields, raw_ocr_json, summary FROM inspections").fetchall()
print(f"Total inspections in DB: {len(rows)}")
for r in rows:
    filename = r[1]
    compliant = bool(r[2])
    pass_f = r[3]
    fail_f = r[4]
    ocr_items = json.loads(r[5]) if r[5] else []
    texts = [x["text"] for x in ocr_items]
    print(f"\n--- {filename} ---")
    print(f"Status: {'PASS' if compliant else 'FAIL'} (Compliant: {pass_f}, Non-Compliant: {fail_f})")
    print(f"OCR Detections ({len(texts)}): {texts[:10]}")
    print(f"Summary: {r[6][:150]}...")
