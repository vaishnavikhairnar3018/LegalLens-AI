import sqlite3
import json
import sys

if sys.platform == "win32" and hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

con = sqlite3.connect("lensescan.db")
rows = con.execute("SELECT id, image_filename, overall_compliant, compliant_fields, non_compliant_fields, declarations_json FROM inspections").fetchall()

for r in rows:
    filename = r[1]
    compliant = bool(r[2])
    pass_f = r[3]
    fail_f = r[4]
    decls = json.loads(r[5]) if r[5] else []
    print(f"\n=======================================================")
    print(f"File: {filename} | Compliant: {compliant} ({pass_f} Pass / {fail_f} Fail)")
    print(f"=======================================================")
    for d in decls:
        status = "PASS" if d["compliant"] else "FAIL"
        val = d.get("detected_value") or "NOT DETECTED"
        viols = d.get("violations", [])
        print(f"  [{status:<4}] {d['field_name']:<22} | Val: {val:<25} | Violations: {viols}")
