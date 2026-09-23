"""
LenseScan Rule Engine.
Validates classified declarations against LMPC Rules 2011.
Loads rules from JSON configuration and produces compliance reports.
"""

import json
import re
import math
import logging
from pathlib import Path
from typing import Dict, List, Optional, Any, Tuple
import numpy as np

from app.schemas.scan import DeclarationField, OCRResult, DetectionStatus
from app.services.calibration import CalibrationResult

logger = logging.getLogger(__name__)

# Rules loaded once at module level
_rules_config: Optional[Dict[str, Any]] = None
RULES_FILE = Path(__file__).parent.parent.parent / "rules" / "lmpc_rules.json"


def load_rules() -> Dict[str, Any]:
    """
    Load LMPC rules from JSON configuration file.
    Cached after first load.
    """
    global _rules_config
    if _rules_config is None:
        logger.info(f"Loading LMPC rules from {RULES_FILE}")
        with open(RULES_FILE, "r", encoding="utf-8") as f:
            _rules_config = json.load(f)
        logger.info(
            f"Loaded {len(_rules_config.get('rules', []))} rules "
            f"(v{_rules_config.get('metadata', {}).get('version', 'unknown')})"
        )
    return _rules_config


def calculate_geometry_confidence(
    ocr_results: List[OCRResult],
    bbox_centers: Dict[str, List[float]],
) -> float:
    """
    Evaluate the geometric stability and planarity of the scanned label.
    Detects non-planar, curved, or skewed conditions (e.g. bottles, pouches, angled camera shots)
    where automated placement coordinates cannot be certified with high certainty.
    """
    if not ocr_results:
        return 0.0

    confidence = 1.0

    # 1. Spatial anchor density: need at least 4 detections across the label to define a panel coordinate system
    num_boxes = len(ocr_results)
    if num_boxes < 4:
        confidence -= 0.40
    elif num_boxes < 6:
        confidence -= 0.15

    # 2. Average OCR detection confidence of detections
    confidences = [
        res.confidence for res in ocr_results
        if hasattr(res, "confidence") and res.confidence is not None
    ]
    if confidences:
        avg_conf = sum(confidences) / len(confidences)
        if avg_conf < 0.65:
            confidence -= 0.35
        elif avg_conf < 0.75:
            confidence -= 0.15

    # 3. Coordinate span & aspect ratio distortion
    all_x, all_y = [], []
    for entry in ocr_results:
        if hasattr(entry, "bbox") and entry.bbox:
            for pt in [
                entry.bbox.top_left,
                entry.bbox.top_right,
                entry.bbox.bottom_right,
                entry.bbox.bottom_left,
            ]:
                all_x.append(pt[0])
                all_y.append(pt[1])

    if all_x and all_y:
        span_x = max(all_x) - min(all_x)
        span_y = max(all_y) - min(all_y)
        aspect = span_x / max(span_y, 1.0)
        # Extreme aspect ratio typical of cylindrical bottle wrap-around scans
        if aspect > 5.0 or aspect < 0.20:
            confidence -= 0.25

    return max(0.0, min(1.0, confidence))


def calculate_font_uncertainty(
    font_height_mm: float,
    calibration_method: Optional[str],
    geometry_confidence: float,
) -> Tuple[float, float, float]:
    """
    Computes measurement uncertainty interval [lower_bound, upper_bound] and uncertainty delta.

    Formula:
        Delta_h = h * sqrt((eps_ref)^2 + (eps_ocr)^2 + (eps_geom)^2)
        - eps_ref: 0.02 (ArUco), 0.04 (Card), 0.05 (Coin)
        - eps_ocr: 0.05 (Bounding box edge estimation)
        - eps_geom: (1.0 - geometry_confidence) * 0.15 (Non-planar distortion)
    """
    method = (calibration_method or "").lower()
    if "aruco" in method:
        eps_ref = 0.02
    elif "card" in method:
        eps_ref = 0.04
    elif "coin" in method:
        eps_ref = 0.05
    else:
        eps_ref = 0.02

    eps_ocr = 0.05
    eps_geom = max(0.0, (1.0 - geometry_confidence) * 0.15)

    rel_unc = math.sqrt(eps_ref**2 + eps_ocr**2 + eps_geom**2)
    unc_mm = font_height_mm * rel_unc
    lower_mm = max(0.0, font_height_mm - unc_mm)
    upper_mm = font_height_mm + unc_mm
    return round(unc_mm, 2), round(lower_mm, 2), round(upper_mm, 2)


def validate_compliance(
    declarations: Dict[str, Any],
    ocr_results: List[OCRResult],
    default_font_min_mm: float = 1.0,
    calibration_result: Optional[CalibrationResult] = None,
    relative_prominence_threshold: float = 0.45,
) -> List[DeclarationField]:
    """
    Validate classified declarations against LMPC rules.

    Checks:
    1. Presence — Is each mandatory declaration detected?
    2. Format — Does the value match legal requirements (e.g., MRP format, PIN code)?
    3. Font size — Does the font height meet LMPC minimums (with physical calibration + uncertainty)?
    4. Special requirements (e.g., MRP must include taxes text)
    5. Placement — Rule 6 Principal Display Panel (PDP) grouping and margin checks
    6. Relative Prominence — Ratio check against panel median for uncalibrated scans

    Args:
        declarations: Output from declaration_classifier.classify_declarations()
        ocr_results: Raw OCR results for additional context
        default_font_min_mm: Default minimum font height if not specified in rules
        calibration_result: Physical reference scale recovery result
        relative_prominence_threshold: Minimum intra-panel font height ratio (default 0.45)

    Returns:
        List of DeclarationField results, one per rule.
    """
    config = load_rules()
    rules = config.get("rules", [])
    # ── Placement Validation (Rule 6 PDP co-location) ──
    # Build a map of field -> bbox center for detected fields
    bbox_centers = {}
    for rule in rules:
        field_name = rule["field"]
        detection = declarations.get(field_name, {})
        if detection.get("detected"):
            ocr_entries = detection.get("ocr_entries", [])
            if ocr_entries:
                # Calculate average center of all bounding boxes for this field
                xs, ys = [], []
                for entry in ocr_entries:
                    if hasattr(entry, 'bbox') and entry.bbox:
                        cx = (entry.bbox.top_left[0] + entry.bbox.top_right[0] +
                              entry.bbox.bottom_right[0] + entry.bbox.bottom_left[0]) / 4
                        cy = (entry.bbox.top_left[1] + entry.bbox.top_right[1] +
                              entry.bbox.bottom_right[1] + entry.bbox.bottom_left[1]) / 4
                        xs.append(cx)
                        ys.append(cy)
                if xs and ys:
                    bbox_centers[field_name] = [sum(xs) / len(xs), sum(ys) / len(ys)]

    # Determine image dimensions from OCR bounding boxes (approximate)
    all_x, all_y = [], []
    for entry in ocr_results:
        if hasattr(entry, 'bbox') and entry.bbox:
            for pt in [entry.bbox.top_left, entry.bbox.top_right,
                       entry.bbox.bottom_right, entry.bbox.bottom_left]:
                all_x.append(pt[0])
                all_y.append(pt[1])

    img_width = max(all_x) if all_x else 1.0
    img_height = max(all_y) if all_y else 1.0

    # Geometry confidence check
    geometry_confidence = calculate_geometry_confidence(ocr_results, bbox_centers)
    GEOMETRY_CONFIDENCE_THRESHOLD = 0.65
    unclear_geometry = geometry_confidence < GEOMETRY_CONFIDENCE_THRESHOLD

    # Placement Rule 1: MRP and Net Quantity must be on the same Principal Display Panel (PDP)
    # We check if they are within the same spatial quadrant or within a reasonable proximity
    PDP_PROXIMITY_THRESHOLD = 0.4  # max 40% of image dimension apart
    pdp_fields = ["mrp", "net_quantity"]
    pdp_centers = {f: bbox_centers[f] for f in pdp_fields if f in bbox_centers}

    placement_issues = {}  # field_name -> list of placement violations

    if len(pdp_centers) == 2:
        dx = abs(pdp_centers["mrp"][0] - pdp_centers["net_quantity"][0]) / max(img_width, 1)
        dy = abs(pdp_centers["mrp"][1] - pdp_centers["net_quantity"][1]) / max(img_height, 1)
        distance = (dx ** 2 + dy ** 2) ** 0.5

        if distance > PDP_PROXIMITY_THRESHOLD:
            violation_msg = (
                f"PLACEMENT: MRP and Net Quantity are separated by {distance:.0%} of "
                f"the label area. Rule 6(2) requires these declarations to appear "
                f"together on the Principal Display Panel (PDP)."
            )
            placement_issues.setdefault("mrp", []).append(violation_msg)
            placement_issues.setdefault("net_quantity", []).append(violation_msg)

    # Placement Rule 2: Key declarations should not be in extreme margins
    # (bottom 5% or right-edge 5% often indicates hidden/obscured text)
    MARGIN_THRESHOLD = 0.05
    for field_name, center in bbox_centers.items():
        norm_x = center[0] / max(img_width, 1)
        norm_y = center[1] / max(img_height, 1)

        if norm_y > (1.0 - MARGIN_THRESHOLD) or norm_x > (1.0 - MARGIN_THRESHOLD):
            if field_name in ["mrp", "net_quantity", "manufacturer_details"]:
                placement_issues.setdefault(field_name, []).append(
                    f"PLACEMENT: '{field_name}' appears in the extreme margin of the "
                    f"label (position: {norm_x:.0%}, {norm_y:.0%}). Rule 6 requires "
                    f"mandatory declarations to be prominently displayed, not hidden."
                )

    # Placement Rule 3: Critical declarations scattered across distant regions
    # If more than 2 key fields have centers spread > 60% of image diagonal, flag
    key_fields = ["mrp", "net_quantity", "manufacturer_details", "consumer_care"]
    key_centers = [bbox_centers[f] for f in key_fields if f in bbox_centers]

    if len(key_centers) >= 3:
        from itertools import combinations
        max_spread = 0
        for c1, c2 in combinations(key_centers, 2):
            dx = abs(c1[0] - c2[0]) / max(img_width, 1)
            dy = abs(c1[1] - c2[1]) / max(img_height, 1)
            spread = (dx ** 2 + dy ** 2) ** 0.5
            max_spread = max(max_spread, spread)

        if max_spread > 0.7:
            for f in key_fields:
                if f in bbox_centers:
                    placement_issues.setdefault(f, []).append(
                        f"PLACEMENT: Mandatory declarations are excessively scattered "
                        f"across the label (max spread: {max_spread:.0%} of diagonal). "
                        f"Rule 6 expects key declarations to be grouped conspicuously."
                    )

    # ── Relative Prominence Baseline (Section 5) ──
    # Calculate intra-panel median font height in pixels for uncalibrated scans
    valid_px_heights = [
        r.font_height_px for r in ocr_results
        if hasattr(r, "font_height_px") and r.font_height_px and r.font_height_px > 0
    ]
    median_panel_font_px = float(np.median(valid_px_heights)) if valid_px_heights else None

    # Build final results list
    results: List[DeclarationField] = []
    num_ocr_boxes = len(ocr_results)
    low_coverage = num_ocr_boxes < 4

    for rule in rules:
        field_name = rule["field"]
        display_name = rule["display_name"]
        required = rule.get("required", True)

        detection = declarations.get(field_name, {})
        detected = detection.get("detected", False)
        value = detection.get("value")
        confidence = detection.get("confidence")
        ocr_entries = detection.get("ocr_entries", [])

        violations: List[str] = []
        compliant = True

        # ── Absence Classification (Section 6) ──
        if detected:
            detection_status = DetectionStatus.DETECTED
            coverage_review_req = False
            coverage_review_msg = None
        else:
            if low_coverage:
                detection_status = DetectionStatus.NOT_DETECTED_LOW_COVERAGE
                coverage_review_req = True
                coverage_review_msg = (
                    f"Label spatial coverage is low (only {num_ocr_boxes} text regions detected). "
                    f"Absence of mandatory declaration '{display_name}' cannot be verified without physical inspection."
                )
            else:
                detection_status = DetectionStatus.NOT_DETECTED_CONFIRMED_ABSENT
                coverage_review_req = False
                coverage_review_msg = None

        # ── Check 1: Presence ──
        if required and not detected:
            if detection_status == DetectionStatus.NOT_DETECTED_LOW_COVERAGE:
                # Per prompt: when coverage is too low to assert absence, flag coverage_review_required
                # instead of issuing an unverified missing declaration citation.
                compliant = True
            else:
                violations.append(
                    f"MISSING: '{display_name}' is a mandatory declaration "
                    f"under {rule.get('section_reference', 'LMPC Rules 2011')} "
                    f"but was not detected on the label."
                )
                compliant = False

        # ── Check 2: Format (only if detected) ──
        if detected and value and rule.get("format_regex"):
            format_pattern = re.compile(rule["format_regex"], re.IGNORECASE)
            if not format_pattern.search(value):
                violations.append(
                    f"FORMAT: Detected value '{value}' does not match the "
                    f"expected format for {display_name}."
                )
                compliant = False

        # ── Check 3: Font Size & Uncertainty (Section 4 & 5) ──
        min_font_config = rule.get("min_font_height_mm")
        required_font_mm = None
        if min_font_config:
            if default_font_min_mm != 1.0:
                required_font_mm = default_font_min_mm
            else:
                # Schedule II weight brackets
                net_qty_val = (declarations.get("net_quantity", {}).get("value") or "").lower()
                weight_g = None
                m = re.search(r"(\d+(?:\.\d+)?)\s*(kg|g|gm|l|ml)", net_qty_val)
                if m:
                    num_val = float(m.group(1))
                    unit = m.group(2)
                    weight_g = num_val * 1000.0 if unit in ["kg", "l"] else num_val

                if weight_g is not None:
                    if weight_g > 500.0:
                        required_font_mm = float(min_font_config.get("above_500g", 4.0))
                    elif weight_g >= 200.0:
                        required_font_mm = float(min_font_config.get("200g_to_500g", 2.0))
                    else:
                        required_font_mm = float(min_font_config.get("up_to_200g", 1.0))
                else:
                    required_font_mm = float(min_font_config.get("up_to_200g", default_font_min_mm))

        font_height_mm = None
        font_uncertainty_mm = None
        lower_bound_mm = None
        upper_bound_mm = None
        font_review_req = False
        font_review_msg = None
        rel_prominence_flag = False
        rel_prominence_note = None

        cal_method = calibration_result.calibration_method if calibration_result else None
        cal_conf = calibration_result.calibration_confidence if calibration_result else None
        is_calibrated = (
            calibration_result is not None
            and calibration_result.pixels_per_mm is not None
            and calibration_result.pixels_per_mm > 0
        )
        is_explicitly_uncalibrated = (
            calibration_result is not None
            and calibration_result.pixels_per_mm is None
        )

        # Get maximum pixel height for this field
        field_font_px = None
        if detected and ocr_entries:
            pxs = [e.font_height_px for e in ocr_entries if hasattr(e, "font_height_px") and e.font_height_px]
            field_font_px = max(pxs) if pxs else None

        if detected and min_font_config:
            if is_calibrated:
                ppm = calibration_result.pixels_per_mm
                if field_font_px is not None:
                    raw_font_mm = field_font_px / ppm
                else:
                    raw_font_mm = detection.get("max_font_height_mm")

                if raw_font_mm is not None:
                    unc_mm, lower_mm, upper_mm = calculate_font_uncertainty(
                        raw_font_mm, cal_method, geometry_confidence
                    )
                    font_height_mm = round(raw_font_mm, 2)
                    font_uncertainty_mm = unc_mm
                    lower_bound_mm = lower_mm
                    upper_bound_mm = upper_mm

                    if lower_bound_mm >= required_font_mm:
                        font_review_req = False
                    elif upper_bound_mm < required_font_mm:
                        violations.append(
                            f"FONT SIZE: Measured font height {font_height_mm:.2f}mm "
                            f"[{lower_bound_mm:.2f}mm - {upper_bound_mm:.2f}mm] "
                            f"is below minimum required {required_font_mm:.1f}mm "
                            f"per LMPC Schedule II."
                        )
                        compliant = False
                    else:
                        font_review_req = True
                        font_review_msg = (
                            f"Measurement uncertainty interval [{lower_bound_mm:.2f}mm - {upper_bound_mm:.2f}mm] "
                            f"straddles Schedule II threshold of {required_font_mm:.1f}mm. "
                            f"Flagged for manual officer verification."
                        )
            elif is_explicitly_uncalibrated:
                # Uncalibrated quick scan mode: never guess a DPI!
                font_height_mm = None
                font_review_req = True
                font_review_msg = (
                    "Uncalibrated scan (no physical reference detected in frame). "
                    "Physical font height cannot be legally certified in millimeters without calibration reference."
                )
                if median_panel_font_px and field_font_px:
                    ratio = field_font_px / median_panel_font_px
                    if ratio < relative_prominence_threshold:
                        rel_prominence_flag = True
                        rel_prominence_note = (
                            f"Relative prominence warning: Declaration font height ({field_font_px:.1f}px) "
                            f"is {ratio:.0%} of panel median ({median_panel_font_px:.1f}px), "
                            f"below prominence threshold ({relative_prominence_threshold:.0%})."
                        )
            else:
                # calibration_result was None (legacy caller or unit tests with pre-populated mm)
                raw_font_mm = detection.get("max_font_height_mm")
                if raw_font_mm is not None:
                    unc_mm, lower_mm, upper_mm = calculate_font_uncertainty(
                        raw_font_mm, "none", geometry_confidence
                    )
                    font_height_mm = round(raw_font_mm, 2)
                    font_uncertainty_mm = unc_mm
                    lower_bound_mm = lower_mm
                    upper_bound_mm = upper_mm

                    if upper_bound_mm < required_font_mm:
                        violations.append(
                            f"FONT SIZE: Measured font height ({font_height_mm:.1f}mm) "
                            f"is below the minimum required ({required_font_mm}mm) "
                            f"per LMPC Schedule II."
                        )
                        compliant = False
                    elif lower_bound_mm < required_font_mm <= upper_bound_mm:
                        font_review_req = True
                        font_review_msg = (
                            f"Measurement uncertainty interval [{lower_bound_mm:.2f}mm - {upper_bound_mm:.2f}mm] "
                            f"straddles Schedule II threshold of {required_font_mm:.1f}mm."
                        )

        # ── Check 4: Special requirements ──
        if field_name == "mrp" and detected and value:
            must_include_taxes = rule.get("must_include_taxes", False)
            if must_include_taxes:
                taxes_keywords = rule.get("taxes_keywords", [])
                value_lower = value.lower()
                full_ocr_text = " ".join(r.text.lower() for r in ocr_results)
                has_taxes_text = any(
                    kw in value_lower or kw in full_ocr_text
                    for kw in taxes_keywords
                )
                if not has_taxes_text:
                    violations.append(
                        "MRP TAXES: MRP declaration should include "
                        "'inclusive of all taxes' text as required by LMPC rules."
                    )

        if field_name == "manufacturer_details" and detected:
            requires_pin = rule.get("requires_pin_code", False)
            if requires_pin and value:
                pin_pattern = re.compile(r"\b\d{6}\b")
                full_ocr_text = " ".join(r.text for r in ocr_results)
                if not pin_pattern.search(value) and not pin_pattern.search(full_ocr_text):
                    violations.append(
                        "ADDRESS: Manufacturer address should include a 6-digit PIN code."
                    )

        if field_name == "consumer_care" and detected:
            requires_contact = rule.get("requires_phone_or_email", False)
            if requires_contact and value:
                has_contact = (
                    re.search(r"\d{10,}", value) or
                    re.search(r"@", value)
                )
                if not has_contact:
                    violations.append(
                        "CONTACT: Consumer care details should include "
                        "a telephone number or email address."
                    )

        # ── Check 5: Placement ──
        field_placement_violations = placement_issues.get(field_name, [])
        placement_ok = len(field_placement_violations) == 0
        placement_review_req = False
        placement_review_msg = None

        if not placement_ok:
            if unclear_geometry:
                # Geometric ambiguity (e.g. curved bottle surface, angled photo, or sparse spatial anchors):
                # Do NOT trigger a hard statutory violation or seizure notice.
                # Flag for manual officer review instead.
                placement_review_req = True
                placement_review_msg = (
                    f"Label surface curvature or sparse spatial geometry (confidence {geometry_confidence:.0%}) "
                    f"precludes certified automated PDP verification. Rule 6 placement flagged for manual officer verification."
                )
                placement_ok = True  # Do not trigger a false fail
                field_placement_violations = []  # Clear from hard statutory violations
            else:
                compliant = False
                violations.extend(field_placement_violations)

        results.append(
            DeclarationField(
                field_name=field_name,
                display_name=display_name,
                detected=detected,
                detection_status=detection_status,
                coverage_review_required=coverage_review_req,
                coverage_review_reason=coverage_review_msg,
                value=value,
                compliant=compliant,
                violations=violations,
                font_height_mm=font_height_mm,
                font_uncertainty_mm=font_uncertainty_mm,
                lower_bound_mm=lower_bound_mm,
                upper_bound_mm=upper_bound_mm,
                font_review_required=font_review_req,
                font_review_reason=font_review_msg,
                calibration_method=cal_method,
                calibration_confidence=cal_conf,
                relative_prominence_flag=rel_prominence_flag,
                relative_prominence_note=rel_prominence_note,
                required_font_height_mm=required_font_mm,
                confidence=confidence,
                placement_compliant=placement_ok,
                placement_violations=field_placement_violations,
                bbox_center=bbox_centers.get(field_name),
                placement_review_required=placement_review_req,
                placement_review_reason=placement_review_msg,
            )
        )

    logger.info(
        f"Compliance check complete: "
        f"{sum(1 for r in results if r.compliant)}/{len(results)} fields compliant"
    )

    return results


def generate_summary(declarations: List[DeclarationField]) -> str:
    """
    Generate a human-readable compliance summary.

    Args:
        declarations: List of validated declaration results.

    Returns:
        Summary string.
    """
    total = len(declarations)
    compliant_count = sum(1 for d in declarations if d.compliant)
    non_compliant = [d for d in declarations if not d.compliant]

    review_sections = []

    # 1. Placement reviews
    placement_fields = [d for d in declarations if getattr(d, "placement_review_required", False)]
    if placement_fields:
        r_names = ", ".join(d.display_name for d in placement_fields)
        review_sections.append(
            f"🔍 PLACEMENT REVIEW: Surface curvature/geometry confidence was below threshold. "
            f"Officer must visually confirm Rule 6 PDP placement for {r_names}."
        )

    # 2. Font measurement reviews
    font_fields = [d for d in declarations if getattr(d, "font_review_required", False)]
    if font_fields:
        f_names = ", ".join(d.display_name for d in font_fields)
        review_sections.append(
            f"🔍 FONT VERIFICATION REQUIRED: Uncertainty interval straddles Schedule II minimum or uncalibrated scan. "
            f"Physical ruler/caliper confirmation recommended for {f_names}."
        )

    # 3. Coverage reviews
    cov_fields = [d for d in declarations if getattr(d, "coverage_review_required", False)]
    if cov_fields:
        c_names = ", ".join(d.display_name for d in cov_fields)
        review_sections.append(
            f"🔍 LOW COVERAGE: Few text regions detected on panel. "
            f"Absence of {c_names} requires physical package inspection."
        )

    # 4. Relative prominence warnings
    prom_fields = [d for d in declarations if getattr(d, "relative_prominence_flag", False)]
    if prom_fields:
        p_names = ", ".join(d.display_name for d in prom_fields)
        review_sections.append(
            f"⚠️ RELATIVE PROMINENCE: {p_names} text height is significantly smaller than panel median."
        )

    review_note = ""
    if review_sections:
        review_note = "\n\n" + "\n\n".join(review_sections)

    if compliant_count == total:
        return (
            f"✅ COMPLIANT: All {total} mandatory declarations under "
            f"LMPC Rules 2011 are present and meet requirements."
            f"{review_note}"
        )

    summary_parts = [
        f"⚠️ NON-COMPLIANT: {len(non_compliant)} of {total} mandatory "
        f"declarations have issues.",
        "",
        "Violations found:",
    ]

    for decl in non_compliant:
        summary_parts.append(f"  • {decl.display_name}:")
        for violation in decl.violations:
            summary_parts.append(f"    - {violation}")

    if review_note:
        summary_parts.append(review_note)

    return "\n".join(summary_parts)
