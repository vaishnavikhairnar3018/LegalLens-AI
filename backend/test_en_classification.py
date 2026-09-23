import cv2
import easyocr
import sys

if sys.platform == "win32" and hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

from app.services.ocr_pipeline import extract_text
from app.services.declaration_classifier import classify_declarations
from app.services.rule_engine import validate_compliance, generate_summary

img_path = r"D:\LenseScan\product\02_balaji_gathiya_back_pass.jpg"
image = cv2.imread(img_path)

# Run extract_text with languages=['en']
ocr_results = extract_text(image, dpi=300, languages=['en'])
print(f"Extracted {len(ocr_results)} text boxes with English OCR.")

# Sample first 15 detections
for r in ocr_results[:15]:
    print(f"  [conf: {r.confidence:.2f}] {r.text}")

classified = classify_declarations(ocr_results)
print("\nClassified Declarations:")
for k, v in classified.items():
    print(f"  {k}: detected={v['detected']}, val='{v['value']}'")

validated = validate_compliance(classified, ocr_results)
print("\nValidation Results:")
for f in validated:
    print(f"  {f.field_name}: compliant={f.compliant}, violations={f.violations}")

summary = generate_summary(validated)
print("\nSummary:")
print(summary)
