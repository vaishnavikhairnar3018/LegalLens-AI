import os
from pathlib import Path

PRODUCT_DIR = Path("D:/LenseScan/product")

# Rename mapping from current names to crystal-clear demo names
RENAME_MAP = {
    "01_balaji_gathiya_front_pass.jpg": "01_balaji_gathiya_front_missing_mrp.jpg",
    "02_balaji_gathiya_back_pass.jpg": "02_balaji_gathiya_back_compliant.jpg",
    "03_balaji_mungdal_pdp_pass.jpg": "03_balaji_mungdal_pdp_missing_netqty.jpg",
    "04_balaji_mungdal_back_pass.jpg": "04_balaji_mungdal_back_compliant.jpg",
    "05_balaji_mungdal_usp_pass.jpg": "05_balaji_mungdal_usp_compliant.jpg",
    "06_balaji_sev_murmura_front_pass.jpg": "06_balaji_sev_murmura_front_missing_mrp.jpg",
    "07_balaji_sev_murmura_back_pass.jpg": "07_balaji_sev_murmura_back_compliant.jpg",
    "08_balaji_sev_murmura_batch_pass.jpg": "08_balaji_sev_murmura_batch_compliant.jpg",
    "09_ram_bandhu_chakali_front_pass.jpg": "09_ram_bandhu_chakali_front_missing_declarations.jpg",
    "10_ram_bandhu_chakali_back_pass.jpg": "10_ram_bandhu_chakali_back_font_violation.jpg",
    "11_maggi_pichkoo_sauce_front_pass.jpg": "11_maggi_pichkoo_sauce_front_compliant.jpg",
    "12_maggi_pichkoo_sauce_crimp_pass.jpg": "12_maggi_pichkoo_sauce_crimp_compliant.jpg",
    "13_suruchi_soysauce_pouch_front.jpg": "13_suruchi_soysauce_missing_mrp.jpg",
    "14_suruchi_soysauce_missing_netqty_fail.jpg": "14_suruchi_soysauce_missing_netqty_fail.jpg",
    "15_samrat_maida_flour_front_pass.jpg": "15_samrat_maida_flour_front_compliant.jpg",
    "16_samrat_maida_flour_back_pass.jpg": "16_samrat_maida_flour_back_font_violation.jpg",
    "17_chings_manchow_soup_front_pass.jpg": "17_chings_manchow_soup_missing_mfg_date.jpg",
    "18_chings_manchow_soup_back_pass.jpg": "18_chings_manchow_soup_back_font_violation.jpg",
    "19_balaji_khatta_mitha_front_pass.jpg": "19_balaji_khatta_mitha_front_missing_mrp.jpg",
    "20_balaji_khatta_mitha_back_pass.jpg": "20_balaji_khatta_mitha_back_compliant.jpg",
    "21_ponds_talc_curved_review.jpg": "21_ponds_talc_curved_review.jpg",
    "22_ponds_talc_cylindrical_review.jpg": "22_ponds_talc_cylindrical_review.jpg",
    "23_dark_fantasy_bourbon_box_pass.jpg": "23_dark_fantasy_bourbon_box_placement_violation.jpg",
    "24_dark_fantasy_bourbon_mrp_pass.jpg": "24_dark_fantasy_bourbon_mrp_compliant.jpg",
    "25_dark_fantasy_bourbon_batch_pass.jpg": "25_dark_fantasy_bourbon_batch_compliant.jpg",
    "26_packaged_staple_pdp_pass.jpg": "26_packaged_staple_missing_consumer_care.jpg",
    "27_packaged_staple_mfg_panel_pass.jpg": "27_packaged_staple_mfg_panel_compliant.jpg",
    "28_beverage_pouch_angled_review.jpg": "28_beverage_pouch_angled_review.jpg",
    "29_snack_pouch_scattered_panel.jpg": "29_snack_pouch_scattered_placement_violation.jpg",
}

for old_name, new_name in RENAME_MAP.items():
    old_file = PRODUCT_DIR / old_name
    new_file = PRODUCT_DIR / new_name
    if old_file.exists() and old_name != new_name:
        old_file.rename(new_file)
        print(f"Renamed: {old_name} -> {new_name}")

print("\nAll 29 product files updated to narrative demo names.")
