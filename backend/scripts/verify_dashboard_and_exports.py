import sys
from pathlib import Path

BACKEND_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(BACKEND_DIR))

if sys.platform == "win32" and hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

import json
import urllib.request
import urllib.error
import urllib.parse

BASE_URL = "http://127.0.0.1:8000"

def run_tests():
    print("=" * 70)
    print("  LenseScan -- Post-Seeding Dashboard & Export Verification Suite")
    print("=" * 70)

    # 1. Login as Admin
    login_data = urllib.parse.urlencode({"username": "admin", "password": "Admin@123456"}).encode("utf-8")
    req = urllib.request.Request(f"{BASE_URL}/api/v1/auth/login", data=login_data, headers={"Content-Type": "application/x-www-form-urlencoded"})
    with urllib.request.urlopen(req) as resp:
        token = json.loads(resp.read())["access_token"]
    print("[1/5] Logged in as Admin successfully.")

    headers = {"Authorization": f"Bearer {token}"}

    # 2. Check Dashboard Summary KPIs
    req = urllib.request.Request(f"{BASE_URL}/api/v1/dashboard/summary?days=30", headers=headers)
    with urllib.request.urlopen(req) as resp:
        summary = json.loads(resp.read())

    # Violations breakdown endpoint
    req_v = urllib.request.Request(f"{BASE_URL}/api/v1/dashboard/violations-by-type?days=30", headers=headers)
    with urllib.request.urlopen(req_v) as resp:
        v_breakdown = json.loads(resp.read())

    print("\n[2/5] Verification of KPI Cards:")
    print(f"  • Total Inspections      : {summary.get('total_inspections')} (Expected: 29)")
    print(f"  • Compliant Inspections  : {summary.get('compliant_count')}")
    print(f"  • Non-Compliant          : {summary.get('non_compliant_count')}")
    print(f"  • Compliance Rate        : {summary.get('compliance_rate_pct')}%")
    print(f"  • Inspections This Week  : {summary.get('week_inspections')} (NON-ZERO check: {'PASS' if summary.get('week_inspections', 0) > 0 else 'FAIL'})")
    print(f"  • Total Violation Flags  : {summary.get('total_violation_flags')}")
    print(f"  • Breakdown Categories   : {v_breakdown.get('by_category')}")

    assert summary.get("total_inspections") == 29, f"Expected 29 inspections, got {summary.get('total_inspections')}"
    assert summary.get("week_inspections", 0) > 0, "Inspections this week is zero!"
    assert summary.get("compliant_count", 0) > 0, "Compliant count is zero!"

    # 3. Check Officer Activity Table
    req = urllib.request.Request(f"{BASE_URL}/api/v1/dashboard/officer-activity?days=30", headers=headers)
    with urllib.request.urlopen(req) as resp:
        officers_data = json.loads(resp.read())
        officers = officers_data.get("officers", [])

    print("\n[3/5] Verification of Officer Enforcement Activity Table:")
    for o in officers:
        print(f"  • {o.get('full_name', o.get('username')):<40} (@{o['username']:<15}): {o['total_inspections']} scans, {o.get('compliance_rate_pct')}% compliance")
    assert len(officers) >= 3, f"Expected at least 3 officers, got {len(officers)}"

    # 3b. Check Trends Endpoint
    req_t = urllib.request.Request(f"{BASE_URL}/api/v1/dashboard/trends?days=30", headers=headers)
    with urllib.request.urlopen(req_t) as resp:
        trends = json.loads(resp.read())
    print(f"  • 30-Day Trend Dates Count: {len(trends.get('dates', []))} days populated.")
    assert len(trends.get("dates", [])) == 30, "Expected 30 continuous trend days"

    # 4. Spot-check 3 individual inspection records in Audit Log
    req = urllib.request.Request(f"{BASE_URL}/api/v1/inspections?limit=50", headers=headers)
    with urllib.request.urlopen(req) as resp:
        items = json.loads(resp.read())

    print(f"\n[4/5] Spot-checking Individual Audit Log Records (Total retrieved: {len(items)}):")
    
    # Helper to fetch detail
    def get_detail(insp_id):
        d_req = urllib.request.Request(f"{BASE_URL}/api/v1/inspections/{insp_id}", headers=headers)
        with urllib.request.urlopen(d_req) as d_resp:
            return json.loads(d_resp.read())

    # Check 1: Missing Net Qty (Suruchi Soy Sauce)
    suruchi = next((i for i in items if "suruchi_soysauce_missing_netqty" in i["image_filename"]), None)
    if suruchi:
        s_detail = get_detail(suruchi["id"])
        print(f"  • Found: {suruchi['image_filename']}")
        print(f"    Summary: {s_detail['summary']}")
        decls = s_detail["declarations"]
        net_qty = next((d for d in decls if d["field_name"] == "net_quantity"), None)
        assert net_qty is not None and not net_qty["compliant"], "Suruchi Net Quantity was not flagged non-compliant!"
        print("    --> Verified: 'Net Quantity' explicitly flagged non-compliant!")

    # Check 2: Missing MRP (01 Balaji Gathiya Front)
    mrp_missing = next((i for i in items if "missing_mrp" in i["image_filename"]), None)
    if mrp_missing:
        m_detail = get_detail(mrp_missing["id"])
        print(f"  • Found: {mrp_missing['image_filename']}")
        print(f"    Summary: {m_detail['summary']}")
        decls = m_detail["declarations"]
        mrp_decl = next((d for d in decls if d["field_name"] == "mrp"), None)
        assert mrp_decl is not None and not mrp_decl["compliant"], "MRP was not flagged non-compliant!"
        print("    --> Verified: 'MRP missing' explicitly flagged non-compliant!")

    # Check 3: Compliant Back Panel (02 Balaji Gathiya Back)
    compliant_rec = next((i for i in items if "02_balaji_gathiya_back_compliant" in i["image_filename"]), None)
    if compliant_rec:
        c_detail = get_detail(compliant_rec["id"])
        print(f"  • Found: {compliant_rec['image_filename']}")
        print(f"    Overall Compliant: {c_detail['overall_compliant']}")
        assert c_detail["overall_compliant"] is True, "02 Balaji Gathiya should be compliant!"
        print("    --> Verified: Genuinely Compliant (PASS)!")

    # Check 4: Cylindrical Review (21 Ponds Talc)
    ponds = next((i for i in items if "21_ponds_talc" in i["image_filename"]), None)
    if ponds:
        p_detail = get_detail(ponds["id"])
        print(f"  • Found: {ponds['image_filename']}")
        print(f"    Summary: {p_detail['summary']}")
        decls = p_detail["declarations"]
        review_req = any(d.get("placement_review_required") for d in decls)
        assert review_req, "Pond's talc did not flag placement_review_required!"
        print("    --> Verified: 'placement_review_required' triggered for curved surface fallback!")

    # 5. Test Export Formats (PDF, DOCX, CSV, JSON)
    print("\n[5/5] Testing Export Endpoints (PDF, DOCX, CSV, JSON):")
    
    # Pick a non-compliant inspection ID for Form LM-N1 notice tests
    sample_insp_id = suruchi["id"] if suruchi else items[0]["id"]

    # A) PDF Notice Export
    pdf_url = f"{BASE_URL}/api/v1/inspections/{sample_insp_id}/notice.pdf"
    req = urllib.request.Request(pdf_url, headers=headers)
    with urllib.request.urlopen(req) as resp:
        pdf_bytes = resp.read()
        content_type = resp.headers.get("Content-Type")
        print(f"  • PDF Notice Download: {len(pdf_bytes)} bytes | MIME: {content_type} | Magic: {pdf_bytes[:4]}")
        assert pdf_bytes[:4] == b"%PDF", "PDF magic bytes %PDF missing!"

    # B) DOCX Notice Export
    docx_url = f"{BASE_URL}/api/v1/inspections/{sample_insp_id}/notice.docx"
    req = urllib.request.Request(docx_url, headers=headers)
    with urllib.request.urlopen(req) as resp:
        docx_bytes = resp.read()
        content_type = resp.headers.get("Content-Type")
        print(f"  • DOCX Notice Download: {len(docx_bytes)} bytes | MIME: {content_type} | Magic: {docx_bytes[:2]}")
        assert docx_bytes[:2] == b"PK", "DOCX zip magic bytes PK missing!"

    # C) CSV Export (All Inspections)
    csv_url = f"{BASE_URL}/api/v1/inspections/export/all.csv?days=30"
    req = urllib.request.Request(csv_url, headers=headers)
    with urllib.request.urlopen(req) as resp:
        csv_text = resp.read().decode("utf-8")
        lines = csv_text.strip().split("\n")
        print(f"  • CSV Export Download: {len(csv_text)} chars | Rows: {len(lines)}")
        print(f"    Header: {lines[0]}")
        assert len(lines) >= 30, f"Expected at least 30 CSV lines (header + 29 data), got {len(lines)}"

    # D) JSON Export (Individual & Audit Log)
    json_url = f"{BASE_URL}/api/v1/inspections/{sample_insp_id}/export.json"
    req = urllib.request.Request(json_url, headers=headers)
    with urllib.request.urlopen(req) as resp:
        json_data = json.loads(resp.read())
        print(f"  • JSON Export: Successfully downloaded record for {json_data.get('id')}")
        print(f"    Total Declarations in JSON: {len(json_data.get('declarations', []))}")
        assert json_data.get("id") == sample_insp_id, "Inspection ID mismatch in JSON export!"

    print("\n" + "=" * 70)
    print("  ALL 5 VERIFICATION CHECKS PASSED WITH ZERO ERRORS!")
    print("=" * 70 + "\n")

if __name__ == "__main__":
    run_tests()
