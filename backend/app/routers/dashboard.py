"""
LenseScan Enforcement Dashboard API.
Aggregate analytics endpoints for monitoring inspections, violations,
and product compliance — as required by SIH Problem Statement 26034.

Provides:
- Summary KPIs (total inspections, compliance rate, violation counts)
- Violation breakdown by declaration type (MRP, Net Qty, Font, Placement, etc.)
- Enforcement trends over time (daily/weekly)
- Officer-wise activity table
"""

import json
import logging
from datetime import datetime, timedelta, timezone
from typing import List, Optional

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, case, and_, cast, Date

from app.database import get_db
from app.models.user import User, UserRole
from app.models.inspection import Inspection
from app.core.rbac import require_role

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/dashboard", tags=["Enforcement Dashboard"])


def _parse_violations_from_declarations(declarations_json: str) -> dict:
    """
    Parse declarations JSON and categorize violations by type.
    Returns dict with violation category counts.
    """
    categories = {
        "missing_declaration": 0,
        "font_violation": 0,
        "format_violation": 0,
        "placement_violation": 0,
        "other_violation": 0,
    }
    # Track which specific fields had violations
    field_violations = {}

    try:
        declarations = json.loads(declarations_json)
    except (json.JSONDecodeError, TypeError):
        return categories, field_violations

    for decl in declarations:
        field_name = decl.get("field_name", "unknown")
        violations = decl.get("violations", [])
        compliant = decl.get("compliant", True)

        if not compliant and not violations:
            # Detected as non-compliant but no explicit violations listed
            categories["other_violation"] += 1
            field_violations[field_name] = field_violations.get(field_name, 0) + 1

        for v in violations:
            v_lower = v.lower()
            if "missing" in v_lower:
                categories["missing_declaration"] += 1
            elif "font" in v_lower:
                categories["font_violation"] += 1
            elif "format" in v_lower:
                categories["format_violation"] += 1
            elif "placement" in v_lower or "panel" in v_lower:
                categories["placement_violation"] += 1
            else:
                categories["other_violation"] += 1

            field_violations[field_name] = field_violations.get(field_name, 0) + 1

    return categories, field_violations


@router.get("/summary")
async def dashboard_summary(
    days: int = Query(30, ge=1, le=365, description="Look-back period in days"),
    current_user: User = Depends(require_role(["officer", "admin", "supervisor"])),
    db: AsyncSession = Depends(get_db),
):
    """
    Dashboard summary KPI cards:
    - Total inspections (all-time and period)
    - Compliance rate
    - Violation counts
    - Inspections this week / this month

    Officers see only their own stats; Supervisors/Admins see department-wide.
    """
    now = datetime.now(timezone.utc)
    period_start = now - timedelta(days=days)
    week_start = now - timedelta(days=7)

    # Base query with RBAC
    base_filter = []
    if current_user.role == UserRole.OFFICER:
        base_filter.append(Inspection.officer_id == current_user.id)

    # Total inspections (all-time)
    stmt_total = select(func.count(Inspection.id))
    if base_filter:
        stmt_total = stmt_total.where(*base_filter)
    total_result = await db.execute(stmt_total)
    total_inspections = total_result.scalar() or 0

    # Inspections in period
    stmt_period = select(func.count(Inspection.id)).where(
        Inspection.created_at >= period_start, *base_filter
    )
    period_result = await db.execute(stmt_period)
    period_inspections = period_result.scalar() or 0

    # Inspections this week
    stmt_week = select(func.count(Inspection.id)).where(
        Inspection.created_at >= week_start, *base_filter
    )
    week_result = await db.execute(stmt_week)
    week_inspections = week_result.scalar() or 0

    # Compliant count (all-time)
    stmt_compliant = select(func.count(Inspection.id)).where(
        Inspection.overall_compliant == True, *base_filter  # noqa: E712
    )
    compliant_result = await db.execute(stmt_compliant)
    compliant_count = compliant_result.scalar() or 0

    # Non-compliant count (all-time)
    non_compliant_count = total_inspections - compliant_count

    # Compliance rate
    compliance_rate = (
        round((compliant_count / total_inspections) * 100, 1)
        if total_inspections > 0
        else 0.0
    )

    # Total violation flags (sum of non_compliant_fields across all inspections)
    stmt_violations = select(func.coalesce(func.sum(Inspection.non_compliant_fields), 0))
    if base_filter:
        stmt_violations = stmt_violations.where(*base_filter)
    violations_result = await db.execute(stmt_violations)
    total_violation_flags = violations_result.scalar() or 0

    return {
        "total_inspections": total_inspections,
        "period_inspections": period_inspections,
        "period_days": days,
        "week_inspections": week_inspections,
        "compliant_count": compliant_count,
        "non_compliant_count": non_compliant_count,
        "compliance_rate_pct": compliance_rate,
        "total_violation_flags": total_violation_flags,
        "generated_at": now.isoformat(),
    }


@router.get("/violations-by-type")
async def violations_by_type(
    days: int = Query(30, ge=1, le=365, description="Look-back period in days"),
    current_user: User = Depends(require_role(["officer", "admin", "supervisor"])),
    db: AsyncSession = Depends(get_db),
):
    """
    Violation breakdown by declaration type.
    Parses the declarations_json from each non-compliant inspection
    and categorizes violations (missing declaration, font size, format, placement).
    """
    now = datetime.now(timezone.utc)
    period_start = now - timedelta(days=days)

    stmt = select(Inspection.declarations_json).where(
        Inspection.overall_compliant == False,  # noqa: E712
        Inspection.created_at >= period_start,
    )
    if current_user.role == UserRole.OFFICER:
        stmt = stmt.where(Inspection.officer_id == current_user.id)

    result = await db.execute(stmt)
    declarations_list = result.scalars().all()

    # Aggregate violation categories
    totals = {
        "missing_declaration": 0,
        "font_violation": 0,
        "format_violation": 0,
        "placement_violation": 0,
        "other_violation": 0,
    }
    field_totals = {}

    for decl_json in declarations_list:
        categories, field_violations = _parse_violations_from_declarations(decl_json)
        for k, v in categories.items():
            totals[k] += v
        for k, v in field_violations.items():
            field_totals[k] = field_totals.get(k, 0) + v

    return {
        "period_days": days,
        "by_category": totals,
        "by_field": field_totals,
        "total_non_compliant_inspections": len(declarations_list),
    }


@router.get("/trends")
async def enforcement_trends(
    days: int = Query(30, ge=1, le=365, description="Look-back period in days"),
    current_user: User = Depends(require_role(["officer", "admin", "supervisor"])),
    db: AsyncSession = Depends(get_db),
):
    """
    Daily enforcement trend data: inspections and violations over time.
    Returns arrays suitable for charting (date labels + counts).
    """
    now = datetime.now(timezone.utc)
    period_start = now - timedelta(days=days)

    # Initialize continuous date buckets so charting is smooth without timeline gaps
    daily_stats = {}
    for i in range(days):
        d_str = (period_start + timedelta(days=i + 1)).strftime("%Y-%m-%d")
        daily_stats[d_str] = {"total": 0, "compliant": 0, "non_compliant": 0}

    stmt = select(Inspection.created_at, Inspection.overall_compliant).where(
        Inspection.created_at >= period_start
    )
    if current_user.role == UserRole.OFFICER:
        stmt = stmt.where(Inspection.officer_id == current_user.id)

    result = await db.execute(stmt)
    rows = result.all()

    for row in rows:
        created_dt = row.created_at
        if created_dt:
            date_str = created_dt.strftime("%Y-%m-%d")
            if date_str not in daily_stats:
                daily_stats[date_str] = {"total": 0, "compliant": 0, "non_compliant": 0}
            daily_stats[date_str]["total"] += 1
            if row.overall_compliant:
                daily_stats[date_str]["compliant"] += 1
            else:
                daily_stats[date_str]["non_compliant"] += 1

    sorted_dates = sorted(daily_stats.keys())
    return {
        "period_days": days,
        "dates": sorted_dates,
        "totals": [daily_stats[d]["total"] for d in sorted_dates],
        "compliant": [daily_stats[d]["compliant"] for d in sorted_dates],
        "non_compliant": [daily_stats[d]["non_compliant"] for d in sorted_dates],
    }


@router.get("/officer-activity")
async def officer_activity(
    days: int = Query(30, ge=1, le=365, description="Look-back period in days"),
    current_user: User = Depends(require_role(["officer", "admin", "supervisor"])),
    db: AsyncSession = Depends(get_db),
):
    """
    Officer-wise enforcement activity table.
    - Admins and Supervisors see department-wide activity across all officers.
    - Regular Officers see strictly their OWN performance stats (scoped to self; cannot see other officers).
    """
    now = datetime.now(timezone.utc)
    period_start = now - timedelta(days=days)

    stmt = (
        select(
            Inspection.officer_id,
            User.username,
            User.full_name,
            func.count(Inspection.id).label("total_inspections"),
            func.sum(
                case((Inspection.overall_compliant == True, 1), else_=0)  # noqa: E712
            ).label("compliant"),
            func.sum(
                case((Inspection.overall_compliant == False, 1), else_=0)  # noqa: E712
            ).label("non_compliant"),
        )
        .join(User, Inspection.officer_id == User.id)
        .where(Inspection.created_at >= period_start)
    )

    if current_user.role == UserRole.OFFICER:
        stmt = stmt.where(Inspection.officer_id == current_user.id)

    stmt = (
        stmt.group_by(Inspection.officer_id, User.username, User.full_name)
        .order_by(func.count(Inspection.id).desc())
    )

    result = await db.execute(stmt)
    rows = result.all()

    officers = []
    for row in rows:
        total = row.total_inspections or 0
        comp = row.compliant or 0
        rate = round((comp / total) * 100, 1) if total > 0 else 0.0
        officers.append({
            "officer_id": row.officer_id,
            "username": row.username,
            "full_name": row.full_name,
            "total_inspections": total,
            "compliant": comp,
            "non_compliant": row.non_compliant or 0,
            "compliance_rate_pct": rate,
        })

    return {
        "period_days": days,
        "officers": officers,
    }
