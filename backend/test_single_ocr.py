import cv2
import easyocr
import sys

if sys.platform == "win32" and hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

img_path = r"D:\LenseScan\product\02_balaji_gathiya_back_pass.jpg"
img = cv2.imread(img_path)

# Test 1: EasyOCR with languages=['en'] directly
reader_en = easyocr.Reader(['en'], gpu=False)
res_en = reader_en.readtext(img_path, detail=0)

print(f"=== EasyOCR ['en'] on raw image ({len(res_en)} text lines) ===")
for t in res_en[:25]:
    print(" ", t)
