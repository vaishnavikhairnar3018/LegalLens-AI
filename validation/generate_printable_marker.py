"""
Generates the official LenseScan 40.0mm ArUco Calibration Marker printout.

Outputs:
1. validation/print_aruco_40mm.pdf: Vector-exact 40.0mm PDF with verification ruler.
2. validation/aruco_40mm_marker.png: 600 DPI PNG with physical pHYs metadata.
"""

import cv2
import numpy as np
from pathlib import Path
from PIL import Image

from reportlab.lib.pagesizes import A4
from reportlab.lib.units import mm
from reportlab.pdfgen import canvas

ARUCO_DICTIONARY_ID = cv2.aruco.DICT_4X4_50
MARKER_ID = 0
PHYSICAL_SIZE_MM = 40.0


def generate_png(output_path: Path, dpi: int = 600):
    """Generate high-resolution PNG with embedded physical DPI metadata."""
    # Compute exact pixel dimension for 40.0mm at given DPI
    # px = (40.0 / 25.4) * DPI
    pixel_size = int(round((PHYSICAL_SIZE_MM / 25.4) * dpi))  # 945 px for 600 DPI

    dictionary = cv2.aruco.getPredefinedDictionary(ARUCO_DICTIONARY_ID)
    # Generate marker image (black outer border + inner code)
    marker_img = cv2.aruco.generateImageMarker(dictionary, MARKER_ID, pixel_size)

    # Add 10% white border (quiet zone) for optical isolation
    margin_px = int(round((5.0 / 25.4) * dpi))
    full_img = cv2.copyMakeBorder(
        marker_img,
        margin_px, margin_px, margin_px, margin_px,
        cv2.BORDER_CONSTANT,
        value=255,
    )

    # Save via PIL with physical DPI metadata
    pil_img = Image.fromarray(full_img)
    pil_img.save(str(output_path), dpi=(dpi, dpi))
    print(f"Generated 600 DPI PNG: {output_path} (Black square: {pixel_size}x{pixel_size} px)")


def generate_pdf(output_path: Path):
    """Generate exact physical vector PDF for A4 printing at 100% scale."""
    c = canvas.Canvas(str(output_path), pagesize=A4)
    width, height = A4

    # Top title
    c.setFont("Helvetica-Bold", 16)
    c.drawCentredString(width / 2.0, height - 35 * mm, "LenseScan Physical Calibration Reference")

    c.setFont("Helvetica", 10)
    c.drawCentredString(
        width / 2.0,
        height - 42 * mm,
        "Legal Metrology (Packaged Commodities) Rules, 2011 Compliance System",
    )

    c.setFont("Helvetica-Bold", 11)
    c.drawCentredString(
        width / 2.0,
        height - 50 * mm,
        "Marker Specification: ArUco DICT_4X4_50 | Marker ID: 0 | Dimension: EXACTLY 40.0 mm x 40.0 mm",
    )

    # Instructions Box
    box_y = height - 82 * mm
    c.setLineWidth(0.5)
    c.rect(30 * mm, box_y, width - 60 * mm, 24 * mm, stroke=1, fill=0)

    c.setFont("Helvetica-Bold", 9)
    c.drawString(35 * mm, box_y + 18 * mm, "CRITICAL PRINTER SETUP INSTRUCTIONS:")
    c.setFont("Helvetica", 8.5)
    c.drawString(
        35 * mm,
        box_y + 13 * mm,
        "1. In your print dialog, select 'Actual Size' or Page Scaling: 'None' (100% scale).",
    )
    c.drawString(
        35 * mm,
        box_y + 8 * mm,
        "2. Do NOT choose 'Fit to Printable Area' or 'Shrink to Fit' - this will alter the physical scale.",
    )
    c.drawString(
        35 * mm,
        box_y + 3 * mm,
        "3. After printing, place a physical ruler on the verification bar below to confirm it measures exactly 50.0 mm.",
    )

    # Draw ArUco Marker
    # Generate high-res raster to embed
    dictionary = cv2.aruco.getPredefinedDictionary(ARUCO_DICTIONARY_ID)
    marker_cv = cv2.aruco.generateImageMarker(dictionary, MARKER_ID, 1200)
    temp_img_path = output_path.parent / "temp_marker_render.png"
    cv2.imwrite(str(temp_img_path), marker_cv)

    marker_x = (width - 40.0 * mm) / 2.0
    marker_y = height - 145 * mm
    marker_size = 40.0 * mm

    # Draw cut line rectangle with 5mm margin
    c.setDash(2, 2)
    c.setLineWidth(0.5)
    c.rect(marker_x - 5 * mm, marker_y - 5 * mm, marker_size + 10 * mm, marker_size + 10 * mm)
    c.setDash()

    # Draw marker
    c.drawImage(
        str(temp_img_path),
        marker_x,
        marker_y,
        width=marker_size,
        height=marker_size,
    )

    # Clean up temp image
    if temp_img_path.exists():
        temp_img_path.unlink()

    # Label marker dimensions
    c.setFont("Helvetica-Bold", 8)
    c.drawCentredString(width / 2.0, marker_y - 10 * mm, "◄── EXACTLY 40.0 mm (Outer Black Edge to Edge) ──►")

    # Verification Ruler (50.0 mm)
    ruler_y = marker_y - 35 * mm
    ruler_x_start = (width - 50.0 * mm) / 2.0
    ruler_x_end = ruler_x_start + 50.0 * mm

    c.setFont("Helvetica-Bold", 9)
    c.drawCentredString(width / 2.0, ruler_y + 10 * mm, "PHYSICAL PRINT VALIDATION RULER (50.0 mm)")

    c.setLineWidth(1.0)
    c.line(ruler_x_start, ruler_y, ruler_x_end, ruler_y)

    # Draw tick marks every millimeter, longer every 5mm and 10mm
    c.setLineWidth(0.5)
    for i in range(51):
        x = ruler_x_start + (i * mm)
        if i % 10 == 0:
            c.line(x, ruler_y, x, ruler_y + 5 * mm)
            c.setFont("Helvetica", 7)
            c.drawCentredString(x, ruler_y - 3.5 * mm, f"{i // 10}cm")
        elif i % 5 == 0:
            c.line(x, ruler_y, x, ruler_y + 3.5 * mm)
        else:
            c.line(x, ruler_y, x, ruler_y + 2 * mm)

    c.setFont("Helvetica", 8)
    c.drawCentredString(
        width / 2.0,
        ruler_y - 9 * mm,
        "If a physical ruler does NOT align with 0 to 5 cm above, your printer scaled the page.",
    )

    # Footer note
    c.setFont("Helvetica-Oblique", 8)
    c.drawCentredString(
        width / 2.0,
        20 * mm,
        "LenseScan Physical Scale Recovery System — SIH 26034 | Legal Metrology Rules 2011",
    )

    c.save()
    print(f"Generated Vector Printable PDF: {output_path}")


if __name__ == "__main__":
    out_dir = Path(__file__).resolve().parent
    generate_png(out_dir / "aruco_40mm_marker.png", dpi=600)
    generate_pdf(out_dir / "print_aruco_40mm.pdf")
