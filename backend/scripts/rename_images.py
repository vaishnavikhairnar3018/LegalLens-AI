"""
LenseScan — Product Image Renamer for Live Enforcement Demonstrations

PURPOSE:
- Creates a backup of raw camera images in D:\\LenseScan\\product_backup.
- Renames the 29 product photographs in D:\\LenseScan\\product to clear,
  self-describing filenames based on brand, product, panel type, and test case.
- Ensures the Inspection Audit Log in the Web Control Room displays meaningful
  names (e.g., 'suruchi_soysauce_missing_netqty.jpg' instead of 'IMG_20260908_202736771.jpg').
"""

import os
import shutil
import sys
from pathlib import Path

# Fix Windows console encoding if needed
if sys.platform == "win32" and hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

PRODUCT_DIR = Path("D:/LenseScan/product")
BACKUP_DIR = Path("D:/LenseScan/product_backup")

# Exact mapping based on the statutory audit of genuine product photos
MAPPING = {
    # 1. Balaji Papdi Gathiya (Compliant)
    "IMG_20260908_202107.jpg": "01_balaji_gathiya_front_pass.jpg",
    "IMG_20260908_202122.jpg": "02_balaji_gathiya_back_pass.jpg",

    # 2. Balaji Mung Dal (Compliant)
    "IMG_20260908_202330.jpg": "03_balaji_mungdal_pdp_pass.jpg",
    "IMG_20260908_202343.jpg": "04_balaji_mungdal_back_pass.jpg",
    "IMG_20260908_202816.jpg": "05_balaji_mungdal_usp_pass.jpg",

    # 3. Balaji Sev Murmura (Compliant)
    "IMG_20260908_202443.jpg": "06_balaji_sev_murmura_front_pass.jpg",
    "IMG_20260908_202501.jpg": "07_balaji_sev_murmura_back_pass.jpg",
    "IMG_20260908_202535.jpg": "08_balaji_sev_murmura_batch_pass.jpg",

    # 4. Ram Bandhu Chakali Bhajani Mix (Compliant)
    "IMG_20260908_202653503.jpg": "09_ram_bandhu_chakali_front_pass.jpg",
    "IMG_20260908_202702021.jpg": "10_ram_bandhu_chakali_back_pass.jpg",

    # 5. Maggi Pichkoo Imli Sauce (Compliant / Font Size Check)
    "IMG_20260908_202714130.jpg": "11_maggi_pichkoo_sauce_front_pass.jpg",
    "IMG_20260908_202718475.jpg": "12_maggi_pichkoo_sauce_crimp_pass.jpg",

    # 6. Suruchi Dark Soy Sauce (CRITICAL DEFECT: Net Quantity Missing in Batch Stamp)
    "IMG_20260908_202729114.jpg": "13_suruchi_soysauce_pouch_front.jpg",
    "IMG_20260908_202736771.jpg": "14_suruchi_soysauce_missing_netqty_fail.jpg",

    # 7. Samrat MP Maida Flour (Compliant)
    "IMG_20260908_202745713.jpg": "15_samrat_maida_flour_front_pass.jpg",
    "IMG_20260908_202755838.jpg": "16_samrat_maida_flour_back_pass.jpg",

    # 8. Ching's Secret Manchow Instant Soup (Compliant)
    "IMG_20260908_202810290.jpg": "17_chings_manchow_soup_front_pass.jpg",
    "IMG_20260908_202818937.jpg": "18_chings_manchow_soup_back_pass.jpg",

    # 9. Balaji Khatta Mitha Mix (Compliant)
    "IMG_20260908_202842.jpg": "19_balaji_khatta_mitha_front_pass.jpg",
    "IMG_20260908_202851.jpg": "20_balaji_khatta_mitha_back_pass.jpg",

    # 10. Pond's Dreamflower Talc (CURVED CANISTER / Cylindrical Angle -> Geometry Review)
    "IMG_20260908_202925465.jpg": "21_ponds_talc_curved_review.jpg",
    "IMG_20260908_202930176.jpg": "22_ponds_talc_cylindrical_review.jpg",

    # 11. Sunfeast Dark Fantasy Bourbon Cookies (Compliant)
    "IMG_20260908_202928.jpg": "23_dark_fantasy_bourbon_box_pass.jpg",
    "IMG_20260908_203142.jpg": "24_dark_fantasy_bourbon_mrp_pass.jpg",
    "IMG_20260908_203209.jpg": "25_dark_fantasy_bourbon_batch_pass.jpg",

    # 12. Additional Packaged Items (Staples / Confectionery)
    "IMG_20260909_085710877.jpg": "26_packaged_staple_pdp_pass.jpg",
    "IMG_20260909_085717108.jpg": "27_packaged_staple_mfg_panel_pass.jpg",
    "IMG_20260909_085731215.jpg": "28_beverage_pouch_angled_review.jpg",
    "IMG_20260909_085741161.jpg": "29_snack_pouch_scattered_panel.jpg",
}


def main():
    print("=" * 70)
    print("  LenseScan -- Product Image Renamer for Live Demo")
    print("=" * 70)

    if not PRODUCT_DIR.exists():
        print(f"[!] Directory {PRODUCT_DIR} does not exist!")
        return

    # 1. Create backup folder
    BACKUP_DIR.mkdir(parents=True, exist_ok=True)
    print(f"\n[1/3] Ensuring backup directory: {BACKUP_DIR}")

    files = [f for f in os.listdir(PRODUCT_DIR) if f.lower().endswith((".jpg", ".jpeg", ".png"))]
    print(f"      Found {len(files)} files in {PRODUCT_DIR}.")

    # Copy files to backup if not already backed up
    for f in files:
        src = PRODUCT_DIR / f
        dst = BACKUP_DIR / f
        if not dst.exists():
            shutil.copy2(src, dst)
    print(f"  [+] Backup verified in {BACKUP_DIR}.")

    # 2. Rename files to descriptive names
    print("\n[2/3] Renaming files to descriptive demo titles...")
    renamed_count = 0
    for old_name, new_name in MAPPING.items():
        old_path = PRODUCT_DIR / old_name
        new_path = PRODUCT_DIR / new_name

        if old_path.exists():
            os.rename(old_path, new_path)
            print(f"  [+] {old_name:<28} --> {new_name}")
            renamed_count += 1
        elif new_path.exists():
            print(f"  [*] Already renamed: {new_name}")
            renamed_count += 1
        else:
            print(f"  [-] File not found: {old_name}")

    print("\n" + "=" * 70)
    print(f"  COMPLETE: {renamed_count} files organized with descriptive names.")
    print("=" * 70 + "\n")


if __name__ == "__main__":
    main()
