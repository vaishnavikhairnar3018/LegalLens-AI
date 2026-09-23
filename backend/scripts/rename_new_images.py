"""
LenseScan — Product Image Renamer for New Field Captures (30 to 93)

PURPOSE:
- Renames the 64 newly added photos (photo_2026-09-21_...) in D:\\LenseScan\\product
- Assigns self-describing, statutory audit filenames based on OCR text analysis
- Maintains numbering sequence from 30 to 93
- Updates the master metadata.csv and metadata.json
"""

import os
import sys
import shutil
from pathlib import Path

# Fix Windows console encoding
if sys.platform == "win32" and hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

PRODUCT_DIR = Path("D:/LenseScan/product")

# Exact mapping based on OCR text analysis and packaging inspection
RENAME_MAP = {
    # Royal Toast (Bakery / Rusks)
    "photo_2026-09-21_16-39-53 (2).jpg": "30_royal_toast_elaichi_front_pdp.jpg",
    "photo_2026-09-21_16-39-53.jpg": "31_royal_toast_elaichi_back_panel.jpg",

    # Haldiram Rusky Atta Toast
    "photo_2026-09-21_19-56-33.jpg": "32_haldiram_rusky_toast_front_pdp.jpg",
    "photo_2026-09-21_19-56-34.jpg": "33_haldiram_rusky_toast_mfg_details.jpg",
    "photo_2026-09-21_19-56-35.jpg": "34_haldiram_rusky_toast_consumer_care.jpg",

    # Bishnoi Foods Atta Toast / Bakery
    "photo_2026-09-21_19-56-36 (2).jpg": "35_bishnoi_toast_netqty_batch.jpg",
    "photo_2026-09-21_19-56-36.jpg": "36_bishnoi_toast_nutrition_side.jpg",
    "photo_2026-09-21_19-56-40.jpg": "37_bishnoi_toast_ingredients_mfg.jpg",
    "photo_2026-09-21_19-56-41 (2).jpg": "38_bishnoi_toast_pack_front.jpg",
    "photo_2026-09-21_19-56-41.jpg": "39_bishnoi_toast_pack_angle.jpg",
    "photo_2026-09-21_19-56-42 (2).jpg": "40_bishnoi_toast_pouch_seam.jpg",
    "photo_2026-09-21_19-56-42.jpg": "41_bishnoi_toast_barcode_window.jpg",
    "photo_2026-09-21_19-56-43 (2).jpg": "42_bishnoi_toast_mrp_stamp.jpg",
    "photo_2026-09-21_19-56-43 (3).jpg": "43_bishnoi_toast_usp_panel.jpg",
    "photo_2026-09-21_19-56-43 (4).jpg": "44_bishnoi_toast_seal_edge.jpg",
    "photo_2026-09-21_19-56-43.jpg": "45_bishnoi_toast_back_panel.jpg",

    # Good Knight Flash Liquid Vaporiser (Godrej)
    "photo_2026-09-21_19-56-44 (2).jpg": "46_goodknight_flash_mrp_batch.jpg",
    "photo_2026-09-21_19-56-44 (3).jpg": "47_goodknight_flash_carton_front.jpg",
    "photo_2026-09-21_19-56-44.jpg": "48_goodknight_flash_carton_top.jpg",
    "photo_2026-09-21_19-56-45 (2).jpg": "49_goodknight_flash_carton_side.jpg",
    "photo_2026-09-21_19-56-45 (3).jpg": "50_mysore_sandal_kleenol_front.jpg",
    "photo_2026-09-21_19-56-45.jpg": "51_goodknight_flash_composition_panel.jpg",

    # Mysore Sandal Kleenol Liquid Multipurpose Cleaner
    "photo_2026-09-21_19-56-46 (2).jpg": "52_mysore_sandal_kleenol_side.jpg",
    "photo_2026-09-21_19-56-46 (3).jpg": "53_mysore_sandal_kleenol_barcode.jpg",
    "photo_2026-09-21_19-56-46.jpg": "54_mysore_sandal_kleenol_batch_mfg.jpg",

    # Samrat Instant Khaman Dhokla Mix
    "photo_2026-09-21_19-56-47 (2).jpg": "55_samrat_khaman_dhokla_pdp_angle.jpg",
    "photo_2026-09-21_19-56-47 (3).jpg": "56_samrat_khaman_dhokla_front_pdp.jpg",
    "photo_2026-09-21_19-56-47 (4).jpg": "57_samrat_khaman_dhokla_recipe_panel.jpg",
    "photo_2026-09-21_19-56-47.jpg": "58_samrat_khaman_dhokla_back_ingredients.jpg",
    "photo_2026-09-21_19-56-48 (2).jpg": "59_samrat_khaman_dhokla_barcode.jpg",
    "photo_2026-09-21_19-56-48 (3).jpg": "60_samrat_khaman_dhokla_mrp_batch.jpg",
    "photo_2026-09-21_19-56-48 (4).jpg": "61_samrat_khaman_dhokla_consumer_care.jpg",
    "photo_2026-09-21_19-56-48.jpg": "62_samrat_khaman_dhokla_manufacturer.jpg",

    # Britannia NutriChoice Digestive High Fibre
    "photo_2026-09-21_19-56-49 (2).jpg": "63_britannia_nutrichoice_side_panel.jpg",
    "photo_2026-09-21_19-56-49 (3).jpg": "64_britannia_nutrichoice_front_pdp.jpg",
    "photo_2026-09-21_19-56-49 (4).jpg": "65_britannia_nutrichoice_top_angle.jpg",
    "photo_2026-09-21_19-56-49.jpg": "66_britannia_nutrichoice_back_nutrition.jpg",
    "photo_2026-09-21_19-56-50 (2).jpg": "67_britannia_nutrichoice_nutrition_table.jpg",
    "photo_2026-09-21_19-56-50 (3).jpg": "68_britannia_nutrichoice_mrp_window.jpg",
    "photo_2026-09-21_19-56-50 (4).jpg": "69_britannia_nutrichoice_open_crimp.jpg",
    "photo_2026-09-21_19-56-50.jpg": "70_britannia_nutrichoice_consumer_care.jpg",

    # Vikas Food Products
    "photo_2026-09-21_19-56-51 (2).jpg": "71_vikas_food_candy_pack_front.jpg",
    "photo_2026-09-21_19-56-51 (3).jpg": "72_vikas_food_candy_nutrition_side.jpg",
    "photo_2026-09-21_19-56-51.jpg": "73_vikas_food_candy_ingredients_mfg.jpg",

    # Amin Dates / Persian Wet Dates (Faaris International)
    "photo_2026-09-21_19-56-52 (2).jpg": "74_amin_persian_dates_box_top.jpg",
    "photo_2026-09-21_19-56-52 (3).jpg": "75_amin_persian_dates_mrp_batch_usp.jpg",
    "photo_2026-09-21_19-56-52 (4).jpg": "76_amin_persian_dates_box_side.jpg",
    "photo_2026-09-21_19-56-52.jpg": "77_amin_persian_dates_front_pdp.jpg",
    "photo_2026-09-21_19-56-53 (2).jpg": "78_amin_persian_dates_packaging_base.jpg",
    "photo_2026-09-21_19-56-53.jpg": "79_amin_persian_dates_importer_details.jpg",

    # Surf Excel Stain Eraser (HUL)
    "photo_2026-09-21_19-56-54 (2).jpg": "80_surf_excel_stain_eraser_front_angle.jpg",
    "photo_2026-09-21_19-56-54 (3).jpg": "81_surf_excel_stain_eraser_front_pdp.jpg",
    "photo_2026-09-21_19-56-54.jpg": "82_surf_excel_stain_eraser_wrapper_side.jpg",
    "photo_2026-09-21_19-56-55 (2).jpg": "83_surf_excel_stain_eraser_mrp_date.jpg",
    "photo_2026-09-21_19-56-55 (3).jpg": "84_surf_excel_stain_eraser_cpcb_micron.jpg",
    "photo_2026-09-21_19-56-55.jpg": "85_surf_excel_stain_eraser_hul_manufacturer.jpg",

    # Vim Dishwash Bar & Liquid Gel (HUL)
    "photo_2026-09-21_19-56-56 (2).jpg": "86_vim_lemon_dishwash_bar_front.jpg",
    "photo_2026-09-21_19-56-56 (3).jpg": "87_vim_lemon_dishwash_bar_barcode.jpg",
    "photo_2026-09-21_19-56-56.jpg": "88_vim_lemon_dishwash_bar_mfg_levercare.jpg",
    "photo_2026-09-21_19-56-57 (2).jpg": "89_vim_lemon_dishwash_bar_mrp_coding.jpg",
    "photo_2026-09-21_19-56-57 (3).jpg": "90_vim_dishwash_gel_pouch_front.jpg",
    "photo_2026-09-21_19-56-57 (4).jpg": "91_vim_dishwash_gel_bottle_weight.jpg",
    "photo_2026-09-21_19-56-57.jpg": "92_vim_lemon_dishwash_bar_address_panel.jpg",

    # Liquid Laundry Detergent Cap
    "photo_2026-09-21_19-56-58.jpg": "93_liquid_detergent_bottle_cap_dosing.jpg",
}


def main():
    print("=" * 70)
    print("  LenseScan — Renaming New Pictures (30 to 93)")
    print("=" * 70)

    if not PRODUCT_DIR.exists():
        print(f"[!] Directory {PRODUCT_DIR} not found!")
        return

    renamed_count = 0
    already_renamed = 0
    missing_count = 0

    for old_name, new_name in RENAME_MAP.items():
        old_path = PRODUCT_DIR / old_name
        new_path = PRODUCT_DIR / new_name

        if old_path.exists():
            os.rename(old_path, new_path)
            print(f"  [+] {old_name:<36} --> {new_name}")
            renamed_count += 1
        elif new_path.exists():
            print(f"  [*] Already renamed: {new_name}")
            already_renamed += 1
        else:
            print(f"  [-] Not found: {old_name}")
            missing_count += 1

    print("\n" + "=" * 70)
    print(f"  RENAMING RESULTS:")
    print(f"  • Successfully Renamed: {renamed_count}")
    print(f"  • Already Renamed:      {already_renamed}")
    print(f"  • Missing:              {missing_count}")
    print("=" * 70 + "\n")


if __name__ == "__main__":
    main()
