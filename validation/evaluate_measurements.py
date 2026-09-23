"""
LenseScan Physical Font Measurement Benchmark Evaluator.

Calculates statistical error metrics (MAE, RMSE, Max Error) between
physical ground truth measurements (metric ruler) and LenseScan optical scale recovery.
"""

import csv
import math
from pathlib import Path
from typing import Dict, List, Any


def evaluate_ground_truth(csv_path: Path) -> Dict[str, Any]:
    """
    Evaluates ground truth measurement records and calculates error metrics.

    Args:
        csv_path: Path to ground_truth.csv.

    Returns:
        Dictionary containing overall and per-method metrics.
    """
    if not csv_path.exists():
        return {
            "total_records": 0,
            "measured_records": 0,
            "status": f"Ground truth file not found at {csv_path}",
        }

    records = []
    with open(csv_path, mode="r", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            records.append(row)

    valid_rows = []
    for r in records:
        gt_str = r.get("ground_truth_mm", "").strip()
        sys_str = r.get("system_font_height_mm", "").strip()
        if gt_str and sys_str:
            try:
                gt_val = float(gt_str)
                sys_val = float(sys_str)
                err = abs(sys_val - gt_val)
                method = r.get("calibration_method", "unknown").strip()
                valid_rows.append({
                    "image_id": r.get("image_id", ""),
                    "product_id": r.get("product_id", ""),
                    "declaration_type": r.get("declaration_type", ""),
                    "ground_truth_mm": gt_val,
                    "system_font_height_mm": sys_val,
                    "absolute_error_mm": err,
                    "calibration_method": method,
                })
            except ValueError:
                continue

    if not valid_rows:
        return {
            "total_records": len(records),
            "measured_records": 0,
            "status": "No ground truth measurement rows populated yet. "
                      "Populate validation/ground_truth.csv with physical package measurements to compute error statistics.",
        }

    total_err = sum(r["absolute_error_mm"] for r in valid_rows)
    sq_err = sum(r["absolute_error_mm"] ** 2 for r in valid_rows)
    n = len(valid_rows)

    mae = total_err / n
    rmse = math.sqrt(sq_err / n)
    max_err = max(r["absolute_error_mm"] for r in valid_rows)

    # Per-method breakdown
    by_method: Dict[str, Dict[str, Any]] = {}
    methods = set(r["calibration_method"] for r in valid_rows)
    for m in methods:
        m_rows = [r for r in valid_rows if r["calibration_method"] == m]
        m_n = len(m_rows)
        m_mae = sum(r["absolute_error_mm"] for r in m_rows) / m_n
        m_rmse = math.sqrt(sum(r["absolute_error_mm"] ** 2 for r in m_rows) / m_n)
        m_max = max(r["absolute_error_mm"] for r in m_rows)
        by_method[m] = {
            "count": m_n,
            "mae_mm": round(m_mae, 4),
            "rmse_mm": round(m_rmse, 4),
            "max_error_mm": round(m_max, 4),
        }

    return {
        "total_records": len(records),
        "measured_records": n,
        "overall_mae_mm": round(mae, 4),
        "overall_rmse_mm": round(rmse, 4),
        "max_error_mm": round(max_err, 4),
        "by_calibration_method": by_method,
        "status": "success",
    }


def main():
    root = Path(__file__).resolve().parent
    csv_file = root / "ground_truth.csv"
    results = evaluate_ground_truth(csv_file)

    print("=" * 60)
    print("LenseScan Physical Font Measurement Evaluation")
    print("=" * 60)
    print(f"Total benchmark records:    {results['total_records']}")
    print(f"Valid measured records:     {results['measured_records']}")

    if results.get("status") != "success":
        print(f"\nNote: {results.get('status')}")
        return

    print(f"\nOverall Statistics (Ruler vs System):")
    print(f"  • Mean Absolute Error (MAE): {results['overall_mae_mm']:.4f} mm")
    print(f"  • Root Mean Sq Error (RMSE):  {results['overall_rmse_mm']:.4f} mm")
    print(f"  • Maximum Absolute Error:     {results['max_error_mm']:.4f} mm")

    print("\nBreakdown by Calibration Method:")
    for method, metrics in results["by_calibration_method"].items():
        print(f"  [{method}] (n={metrics['count']}):")
        print(f"    - MAE:       {metrics['mae_mm']:.4f} mm")
        print(f"    - RMSE:      {metrics['rmse_mm']:.4f} mm")
        print(f"    - Max Error: {metrics['max_error_mm']:.4f} mm")
    print("=" * 60)


if __name__ == "__main__":
    main()
