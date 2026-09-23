import sys
from pathlib import Path

BACKEND_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(BACKEND_DIR))

if sys.platform == "win32" and hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

import re

# Simulate full_text and ocr_entries from 02_balaji_gathiya_back_pass.jpg
full_text = 'Wul Kooh NAMKEEW BALAJI ALLERGEMADVICE: CONTAINS WHEAT Flour: PROduct Of INDIA WAFERS NUTRITIONAL INFORMATION PER 100g EneRGY 226 Kcal PROTEIN 12.7g CARBOHYDRATES 38.2g BALAJI TOTAL SUGARS 1.1g ADDED SUGARS 0.0g TRY TOTAL DIETARY FIBER 8.3g This: TOTAL FAT SATURATED FAT TRANS FAT 0.2g CHOLESTEROL <mg SODIUM 82mg APPROXIMATE VALUES REGD OFFLLE V: BALAJI WAFERS 2000 KCAL PFR FSSAI LABELLING & DISPLAY: SERVING PER PACKAGE SERVING SIZE IDIA IviT WEIGHT : 24g MRP ? 5.00 (INCL OF All taxeS) 20 UNIT SALE PRICE : ? 0.21 PERg B.NO:: PKD, offICE TO OR EXPIRV DATE : KEEP AWAY FROM direct 6 Heat Fssai Gathiya 3519 788 9 TiL 0323435 91 7069014141 CoM Follow'

net_pat = re.compile(r'(?:[NI1|l][eiaovzct]{1,3}t?\.?\s*(?:Wt\.?|Weight|Qty\.?|Quantity|Content|Vol\.?|Volume))\s*[:\-]?\s*[\d.]+\s*(?:g|gm|gms|kg|kgs|ml|mL|l|L|ltr|litre|cm|m|mm|pieces?|pcs?|nos?)\b', re.I)
mrp_pat = re.compile(r'(?:M\.?\s*R\.?\s*P\.?|Maximum\s*Retail\s*Price|Retail\s*Price|Rs\.?|INR)\s*[:\-?]?\s*(?:[₹Rs\.\?]\s*)?[\d,]+(?:\.\d{1,2})?(?:\s*(?:incl\.?|inclusive|all\s*taxes|\([^)]*taxes[^)]*\)))?', re.I)
mfg_pat = re.compile(r'(?:REGD[^A-Za-z0-9]*OFF[A-Z]*|Manu?f(?:actur(?:ed|ing)|d\.?)?|Packed|Marketed|Distributed|Imported)(?:\s*(?:by|&\s*Packed\s*by))?[\s:;\-\.]*(?:[A-Z]{1,2}[:;\-\.\s]+)?([A-Za-z0-9\s,\.\-&]{4,60})', re.I)
mfg_date_pat = re.compile(r'(?:Mf[gd]\.?|Manu?f(?:actur(?:ed|ing)|d\.?)?|Pack(?:ed|ing)?|PKD\.?|Dom|Date\s*of\s*(?:Manufacture|Mfg|Packing))', re.I)
exp_pat = re.compile(r'(?:Best\s*Before|Exp(?:ir[vy])?\.?\s*(?:Date)?|Use\s*By|BB|Shelf\s*Life)', re.I)
care_pat = re.compile(r'(?:[CLO]onsumer|Customer)\s*(?:Care|Service|Helpline|Grievance|Support|Executive|Cell|Complaint|Contact)|(?:(?:Tel|Phone|Mob|Helpline)\s*[:\-]?\s*)?(?:\+?91[\-\s]?)?[6-9]\d{9}', re.I)
origin_pat = re.compile(r'(?:Made\s*in|Product\s*of|Country\s*of\s*Origin|Origin)\s*[:\-]?\s*(?:India|Bharat|[A-Z][a-z]+)', re.I)
generic_pat = re.compile(r'\b(?:Gathiya|Gothiya|Wafers|Chakali|Sauce|Flour|Maida|Soup|Noodles|Biscuits|Talc|Powder|Namkeen|Snacks)\b', re.I)

print("MRP:          ", mrp_pat.search(full_text).group(0) if mrp_pat.search(full_text) else None)
print("Net Qty:      ", net_pat.search(full_text).group(0) if net_pat.search(full_text) else None)
print("Mfg Details:  ", mfg_pat.search(full_text).group(0) if mfg_pat.search(full_text) else None)
print("Mfg Date:     ", mfg_date_pat.search(full_text).group(0) if mfg_date_pat.search(full_text) else None)
print("Expiry:       ", exp_pat.search(full_text).group(0) if exp_pat.search(full_text) else None)
print("Consumer Care:", care_pat.search(full_text).group(0) if care_pat.search(full_text) else None)
print("Origin:       ", origin_pat.search(full_text).group(0) if origin_pat.search(full_text) else None)
print("Generic Name: ", generic_pat.search(full_text).group(0) if generic_pat.search(full_text) else None)
