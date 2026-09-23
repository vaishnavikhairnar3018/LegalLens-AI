"""
Unit tests for LenseScan backend components:
- Rule engine & LMPC Rules 2011 compliance checks
- Declaration classifier regex matching
- Input sanitizer & magic byte validator
- Core security (JWT & bcrypt)
"""

import pytest
from app.services.rule_engine import load_rules, validate_compliance
from app.services.declaration_classifier import classify_declarations
from app.schemas.scan import OCRResult, BoundingBox
from app.utils.sanitizer import sanitize_ocr_text, sanitize_filename, validate_image_content, check_sql_injection
from app.core.security import get_password_hash, verify_password, create_access_token, decode_token


def _dummy_bbox():
    return BoundingBox(
        top_left=[10.0, 10.0],
        top_right=[200.0, 10.0],
        bottom_right=[200.0, 40.0],
        bottom_left=[10.0, 40.0],
    )


def test_load_rules():
    """Verify that LMPC rules are loaded from JSON properly."""
    rules = load_rules()
    assert "rules" in rules
    assert len(rules["rules"]) >= 8
    fields = [r["field"] for r in rules["rules"]]
    assert "mrp" in fields
    assert "net_quantity" in fields
    assert "manufacturer_details" in fields
    assert "consumer_care" in fields


def test_declaration_classifier_mrp():
    """Test detection of MRP declaration from OCR text."""
    ocr_items = [
        OCRResult(
            text="MRP Rs. 150.00 (Incl. of all taxes)",
            confidence=0.96,
            bbox=_dummy_bbox(),
            font_height_px=30.0,
            font_height_mm=2.5,
        ),
        OCRResult(
            text="Net Qty: 500 g",
            confidence=0.92,
            bbox=_dummy_bbox(),
            font_height_px=25.0,
            font_height_mm=2.2,
        ),
    ]

    classified = classify_declarations(ocr_items)
    assert "mrp" in classified
    assert classified["mrp"]["detected"] is True
    assert "150.00" in classified["mrp"]["value"]

    assert "net_quantity" in classified
    assert classified["net_quantity"]["detected"] is True
    assert "500" in classified["net_quantity"]["value"]


def test_rule_engine_compliance_pass():
    """Test rule engine validation when all criteria are satisfied."""
    ocr_items = [
        OCRResult(
            text="MRP Rs. 99.00 (Incl. of all taxes)",
            confidence=0.95,
            bbox=_dummy_bbox(),
            font_height_px=35.0,
            font_height_mm=3.0,
        ),
        OCRResult(
            text="Net Qty: 200 ml",
            confidence=0.91,
            bbox=_dummy_bbox(),
            font_height_px=30.0,
            font_height_mm=2.5,
        ),
    ]

    classified = classify_declarations(ocr_items)
    fields = validate_compliance(classified, ocr_items, default_font_min_mm=1.0)

    mrp_field = next(f for f in fields if f.field_name == "mrp")
    assert mrp_field.detected is True
    assert mrp_field.compliant is True
    assert len(mrp_field.violations) == 0


def test_rule_engine_font_violation():
    """Test rule engine flagging font height violation."""
    ocr_items = [
        OCRResult(
            text="Net Qty: 500 g",
            confidence=0.90,
            bbox=_dummy_bbox(),
            font_height_px=10.0,
            font_height_mm=0.8,  # Below LMPC requirement
        ),
    ]

    classified = classify_declarations(ocr_items)
    fields = validate_compliance(classified, ocr_items, default_font_min_mm=2.0)

    net_field = next(f for f in fields if f.field_name == "net_quantity")
    assert net_field.detected is True
    assert net_field.compliant is False
    assert any("minimum required" in v.lower() or "font" in v.lower() for v in net_field.violations)


def test_sanitizer():
    """Test XSS, control char, and filename sanitization."""
    dirty_text = "<script>alert('hack')</script>Hello World! \x00\x08"
    clean_text = sanitize_ocr_text(dirty_text)
    assert "<script>" not in clean_text
    assert "Hello World!" in clean_text
    assert "\x00" not in clean_text

    safe_name = sanitize_filename("../../../etc/passwd.jpg")
    assert ".." not in safe_name
    assert "/" not in safe_name
    assert "\\" not in safe_name

    # Magic byte checks
    jpeg_header = b"\xff\xd8\xff\xe0" + b"\x00" * 100
    assert validate_image_content(jpeg_header) == "image/jpeg"

    fake_file = b"MZ\x90\x00" + b"\x00" * 100
    assert validate_image_content(fake_file) is None

    # SQL injection check
    assert check_sql_injection("SELECT * FROM users WHERE 1=1") is True
    assert check_sql_injection("MRP Rs. 50 (incl of taxes)") is False


def test_security_hash_and_token():
    """Test password hashing and JWT token creation/decoding."""
    password = "SuperSecretPassword123!"
    hashed = get_password_hash(password)
    assert verify_password(password, hashed) is True
    assert verify_password("WrongPassword", hashed) is False

    token = create_access_token(data={"sub": "testofficer", "role": "officer"})
    decoded = decode_token(token)
    assert decoded["sub"] == "testofficer"
    assert decoded["role"] == "officer"


def test_placement_validation_proximity_fail():
    """Verify that widely separated MRP and Net Quantity trigger Rule 6(2) PDP violation on clear flat scan."""
    mrp_bbox = BoundingBox(
        top_left=[50.0, 50.0],
        top_right=[150.0, 50.0],
        bottom_right=[150.0, 100.0],
        bottom_left=[50.0, 100.0],
    )
    net_bbox = BoundingBox(
        top_left=[850.0, 850.0],
        top_right=[950.0, 850.0],
        bottom_right=[950.0, 900.0],
        bottom_left=[850.0, 900.0],
    )
    boundary_bbox = BoundingBox(
        top_left=[0.0, 0.0],
        top_right=[1000.0, 0.0],
        bottom_right=[1000.0, 1000.0],
        bottom_left=[0.0, 1000.0],
    )
    mfg_bbox = BoundingBox(
        top_left=[200.0, 400.0],
        top_right=[500.0, 400.0],
        bottom_right=[500.0, 450.0],
        bottom_left=[200.0, 450.0],
    )
    care_bbox = BoundingBox(
        top_left=[200.0, 500.0],
        top_right=[500.0, 500.0],
        bottom_right=[500.0, 550.0],
        bottom_left=[200.0, 550.0],
    )

    ocr_items = [
        OCRResult(text="Boundary", confidence=0.95, bbox=boundary_bbox, font_height_px=10, font_height_mm=2.0),
        OCRResult(text="MRP Rs. 100 (incl of all taxes)", confidence=0.95, bbox=mrp_bbox, font_height_px=30, font_height_mm=3.0),
        OCRResult(text="Net Qty: 500 g", confidence=0.95, bbox=net_bbox, font_height_px=30, font_height_mm=3.0),
        OCRResult(text="Mfg by ABC Foods Ltd 400001", confidence=0.95, bbox=mfg_bbox, font_height_px=20, font_height_mm=2.0),
        OCRResult(text="Call 1800-111-222 care@abc.com", confidence=0.95, bbox=care_bbox, font_height_px=20, font_height_mm=2.0),
    ]
    classified = classify_declarations(ocr_items)
    fields = validate_compliance(classified, ocr_items, default_font_min_mm=1.0)

    mrp_field = next(f for f in fields if f.field_name == "mrp")
    assert mrp_field.placement_compliant is False
    assert mrp_field.placement_review_required is False
    assert any("Principal Display Panel" in v or "separated" in v for v in mrp_field.placement_violations)


def test_placement_validation_proximity_pass():
    """Verify that MRP and Net Quantity placed close together pass PDP placement check."""
    mrp_bbox = BoundingBox(
        top_left=[100.0, 200.0],
        top_right=[200.0, 200.0],
        bottom_right=[200.0, 250.0],
        bottom_left=[100.0, 250.0],
    )
    net_bbox = BoundingBox(
        top_left=[100.0, 270.0],
        top_right=[200.0, 270.0],
        bottom_right=[200.0, 320.0],
        bottom_left=[100.0, 320.0],
    )
    boundary_bbox = BoundingBox(
        top_left=[0.0, 0.0],
        top_right=[1000.0, 0.0],
        bottom_right=[1000.0, 1000.0],
        bottom_left=[0.0, 1000.0],
    )
    mfg_bbox = BoundingBox(
        top_left=[100.0, 400.0],
        top_right=[400.0, 400.0],
        bottom_right=[400.0, 450.0],
        bottom_left=[100.0, 450.0],
    )

    ocr_items = [
        OCRResult(text="Boundary", confidence=0.95, bbox=boundary_bbox, font_height_px=10, font_height_mm=2.0),
        OCRResult(text="MRP Rs. 100 (incl of all taxes)", confidence=0.95, bbox=mrp_bbox, font_height_px=30, font_height_mm=3.0),
        OCRResult(text="Net Qty: 500 g", confidence=0.95, bbox=net_bbox, font_height_px=30, font_height_mm=3.0),
        OCRResult(text="Mfg by ABC Foods Ltd 400001", confidence=0.95, bbox=mfg_bbox, font_height_px=20, font_height_mm=2.0),
    ]
    classified = classify_declarations(ocr_items)
    fields = validate_compliance(classified, ocr_items, default_font_min_mm=1.0)

    mrp_field = next(f for f in fields if f.field_name == "mrp")
    net_field = next(f for f in fields if f.field_name == "net_quantity")
    assert mrp_field.placement_compliant is True
    assert net_field.placement_compliant is True
    assert mrp_field.placement_review_required is False
    assert len(mrp_field.placement_violations) == 0


def test_placement_unclear_geometry_triggers_review_state():
    """
    Verify that when geometry confidence is low (curved bottle, sparse anchors, skewed angle),
    the placement engine does NOT produce a false violation. Instead, it flags the declaration
    with placement_review_required=True and retains compliant=True.
    """
    # Curved bottle photo with only 2 detections and lower confidence
    mrp_bbox = BoundingBox(
        top_left=[50.0, 50.0],
        top_right=[150.0, 50.0],
        bottom_right=[150.0, 100.0],
        bottom_left=[50.0, 100.0],
    )
    net_bbox = BoundingBox(
        top_left=[850.0, 850.0],
        top_right=[950.0, 850.0],
        bottom_right=[950.0, 900.0],
        bottom_left=[850.0, 900.0],
    )

    # Only 2 detections with 0.58 confidence -> geometry confidence < 0.65 threshold
    ocr_items = [
        OCRResult(text="MRP Rs. 100 (incl of all taxes)", confidence=0.58, bbox=mrp_bbox, font_height_px=30, font_height_mm=3.0),
        OCRResult(text="Net Qty: 500 g", confidence=0.58, bbox=net_bbox, font_height_px=30, font_height_mm=3.0),
    ]
    classified = classify_declarations(ocr_items)
    fields = validate_compliance(classified, ocr_items, default_font_min_mm=1.0)

    mrp_field = next(f for f in fields if f.field_name == "mrp")
    net_field = next(f for f in fields if f.field_name == "net_quantity")

    # MUST NOT be marked as an illegal statutory breach
    assert mrp_field.compliant is True
    assert net_field.compliant is True
    assert len(mrp_field.violations) == 0
    assert len(net_field.violations) == 0

    # MUST be flagged for manual review with explanatory reason
    assert mrp_field.placement_review_required is True
    assert mrp_field.placement_review_reason is not None
    assert "manual officer verification" in mrp_field.placement_review_reason.lower()


