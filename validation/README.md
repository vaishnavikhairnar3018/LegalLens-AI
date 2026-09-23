# Physical Package Font Measurement Validation Suite

LenseScan physical scale and font-height verification benchmarks against real-world commodity packages under Legal Metrology (Packaged Commodities) Rules, 2011.

## Measurement Protocol & Equipment

- **Reference standard:** Metric steel rule with 0.5mm graduations (or optical comparator).
- **Recorded unit:** Millimeters (`ruler_mm`).
- **Classification rule:** Per project statutory verification constraints, physical handheld measurements must never be claimed as micrometer or digital caliper precision (`caliper_mm`), as flexible packaging yields under caliper jaw tension.

## Known Physical Measurement Limitations

1. **Parallax Error:** Optical angle between inspector eye, ruler surface, and curved or flexible packaging introduces up to $\pm 0.5\text{mm}$ manual variance.
2. **Surface Curvature & Wrinkles:** Cylindrical bottles (e.g., Dettol) and laminate pouches (e.g., Maggi) exhibit non-planar distortion. The rule engine calculates geometric confidence (`calculate_geometry_confidence`) to account for this.
3. **Ink Bleed & Lithographic Rasterization:** Commercial flexographic and gravure printing on corrugated cardboard or BOPP film produces microscopic ink spread (~0.05mm - 0.10mm) compared to vector typography.
4. **Lighting & Optical Glare:** Direct specular highlights on glossy foil packages can saturate camera pixels near marker corners. The pre-capture quality gate checks for localized marker glare (>10% saturation at luminance > 250).

## Evaluation Workflow

1. Place package alongside calibration reference (ArUco 40mm marker, ₹10 coin 26mm, or standard ID card 85.60x53.98mm) on a flat, well-lit surface.
2. Capture test image and store in `validation/images/`.
3. Measure physical capital letter / numeral height on the package using a metric rule and record in `ground_truth.csv`.
4. Run automated measurement evaluation:
   ```bash
   python validation/evaluate_measurements.py
   ```
