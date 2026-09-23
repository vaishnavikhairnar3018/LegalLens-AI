"""
LenseScan Cross-Panel Consistency Service.

Validates multi-image/multi-panel product inspections to detect contradictory
declarations across different package surfaces (e.g. Front PDP vs Back Informational Panel).

Enforces LMPC Section 6 consistency requirements:
- Identical MRP across all product panels.
- Consistent Net Quantity declarations.
- Matching Manufacturing and Expiry/Best Before dates.
- Harmonized Country of Origin declarations.
"""

import re
import logging
from typing import List, Dict, Any, Optional

logger = logging.getLogger(__name__)


def _extract_numeric_price(val: Optional[str]) -> Optional[float]:
    """Extract numeric price from raw currency string."""
    if not val:
        return None
    cleaned = val.replace(",", "")
    match = re.search(r"(\d+(?:\.\d{1,2})?)", cleaned)
    if match:
        try:
            return float(match.group(1))
        except ValueError:
            return None
    return None


def _normalize_quantity(val: Optional[str]) -> Optional[str]:
    """Normalize net quantity string (strip spaces, lowercase)."""
    if not val:
        return None
    cleaned = re.sub(r"\s+", "", val.lower())
    # Extract digits and unit
    match = re.search(r"(\d+(?:\.\d+)?)(kg|g|l|ml|m|cm|mm|units?|n|u)", cleaned)
    if match:
        num = float(match.group(1))
        unit = match.group(2)
        # Normalize equivalent units (e.g., 1000g -> 1kg or standardize to grams/ml)
        if unit == "kg":
            return f"{num * 1000:g}g"
        elif unit == "l":
            return f"{num * 1000:g}ml"
        return f"{num:g}{unit}"
    return cleaned


def _normalize_date(val: Optional[str]) -> Optional[str]:
    """Normalize date string for comparison."""
    if not val:
        return None
    cleaned = re.sub(r"[^\w/.-]", "", val.lower())
    return cleaned


def check_cross_panel_consistency(
    panels: List[Dict[str, Any]],
) -> List[Dict[str, Any]]:
    """
    Check for cross-panel declaration mismatches across multiple package images.

    Args:
        panels: List of panel data dictionaries.
            Each item must contain:
            - "panel_id": str identifier (e.g. "front_pdp", "back_panel", "image_1")
            - "declarations": List[DeclarationField] or Dict[field_name, value]

    Returns:
        List of conflict dictionaries detailing mismatched declarations.
    """
    if len(panels) < 2:
        return []

    # Map of field -> {panel_id: (raw_value, normalized_value)}
    field_observations: Dict[str, Dict[str, Dict[str, Any]]] = {}

    tracked_fields = {
        "mrp": ("Maximum Retail Price", _extract_numeric_price),
        "net_quantity": ("Net Quantity", _normalize_quantity),
        "date_of_manufacture": ("Date of Manufacture", _normalize_date),
        "expiry_date": ("Expiry / Best Before Date", _normalize_date),
        "country_of_origin": ("Country of Origin", lambda s: s.strip().lower() if s else None),
    }

    for panel in panels:
        panel_id = str(panel.get("panel_id") or "panel")
        decls = panel.get("declarations", [])

        # Extract values into dict
        val_map: Dict[str, str] = {}
        if isinstance(decls, dict):
            for k, v in decls.items():
                if isinstance(v, dict):
                    if v.get("detected") and v.get("value"):
                        val_map[k] = str(v["value"])
                elif v:
                    val_map[k] = str(v)
        else:
            for item in decls:
                f_name = getattr(item, "field_name", None) or item.get("field_name")
                f_det = getattr(item, "detected", None) if hasattr(item, "detected") else item.get("detected")
                f_val = getattr(item, "value", None) if hasattr(item, "value") else item.get("value")
                if f_name and f_det and f_val:
                    val_map[f_name] = str(f_val)

        for field_name, (disp_name, normalizer) in tracked_fields.items():
            if field_name in val_map:
                raw = val_map[field_name]
                norm = normalizer(raw)
                if norm is not None:
                    field_observations.setdefault(field_name, {})[panel_id] = {
                        "raw": raw,
                        "normalized": norm,
                        "display_name": disp_name,
                    }

    mismatches: List[Dict[str, Any]] = []

    for field_name, obs_by_panel in field_observations.items():
        if len(obs_by_panel) >= 2:
            unique_norms = set(data["normalized"] for data in obs_by_panel.values())
            if len(unique_norms) > 1:
                disp_name = tracked_fields[field_name][0]
                conflicts = []
                summary_items = []
                for p_id, p_info in obs_by_panel.items():
                    conflicts.append({
                        "panel_id": p_id,
                        "raw_value": p_info["raw"],
                        "normalized_value": p_info["normalized"],
                    })
                    summary_items.append(f"'{p_info['raw']}' on [{p_id}]")

                description = (
                    f"Cross-panel mismatch for {disp_name}: conflicting declarations found: "
                    f"{' vs '.join(summary_items)}."
                )

                mismatches.append({
                    "field_name": field_name,
                    "display_name": disp_name,
                    "conflicts": conflicts,
                    "description": description,
                    "severity": "violation" if field_name in ["mrp", "net_quantity"] else "warning",
                })
                logger.warning(f"Detected cross-panel mismatch: {description}")

    return mismatches
