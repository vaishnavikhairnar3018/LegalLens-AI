# LenseScan — API Reference

**Base URL:** `http://localhost:8000/api/v1`  
**Authentication:** All endpoints (except login and health) require `Authorization: Bearer <jwt_token>`

---

## 1. Authentication (`/api/v1/auth`)

### `POST /auth/login`
Authenticate and receive a JWT access token.

| Parameter | Type | Location | Required |
|-----------|------|----------|----------|
| username | string | form-data | ✓ |
| password | string | form-data | ✓ |

**Response (200):**
```json
{
  "access_token": "eyJhbGciOi...",
  "token_type": "bearer",
  "role": "officer",
  "username": "inspector_verma"
}
```

### `POST /auth/register` *(Admin only)*
Register a new user account.

| Parameter | Type | Required |
|-----------|------|----------|
| username | string | ✓ |
| full_name | string | ✓ |
| password | string | ✓ |
| role | string (officer/admin/supervisor) | ✓ |

### `GET /auth/me`
Get the current authenticated user's profile.

**Response (200):**
```json
{
  "id": 1,
  "username": "admin",
  "full_name": "System Administrator",
  "role": "admin",
  "is_active": true
}
```

---

## 2. Label Scanning (`/api/v1/scan`)

### `POST /scan/`
Upload a packaged commodity label image for compliance checking.

| Parameter | Type | Location | Required |
|-----------|------|----------|----------|
| file | image (JPEG/PNG) | multipart | ✓ |
| dpi | integer | form-data | ✗ (default: 300) |

**Response (200):**
```json
{
  "scan_id": "uuid",
  "timestamp": "2026-09-20T10:00:00Z",
  "image_filename": "label.jpg",
  "image_hash_sha256": "e3b0c442...",
  "dpi_used": 300,
  "overall_compliant": false,
  "total_fields": 8,
  "compliant_fields": 7,
  "non_compliant_fields": 1,
  "declarations": [...],
  "raw_ocr_results": [...],
  "summary": "⚠️ NON-COMPLIANT: 1 of 8 mandatory declarations have issues."
}
```

---

## 3. Inspections Audit Trail (`/api/v1/inspections`)

### `GET /inspections/`
List past inspections (paginated). Officers see own; Admins/Supervisors see all.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| skip | integer | 0 | Pagination offset |
| limit | integer | 20 | Page size (max 100) |
| compliant_only | boolean | null | Filter by compliance status |

### `GET /inspections/{id}`
Get full inspection detail including declarations breakdown.

### `GET /inspections/{id}/notice.pdf`
Download statutory PDF notice (Form LM-N1 or Form LM-C1).

### `GET /inspections/{id}/notice.docx`
Download editable Word document version of the inspection report.

### `GET /inspections/{id}/export.json`
Download machine-readable JSON export of a single inspection.

### `GET /inspections/export/all.csv` *(Admin/Supervisor only)*
Download batch CSV export of all inspections for audit spreadsheets.

---

## 4. Enforcement Dashboard (`/api/v1/dashboard`)

### `GET /dashboard/summary`
KPI summary cards for the dashboard.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| days | integer | 30 | Look-back period (1–365) |

**Response (200):**
```json
{
  "total_inspections": 142,
  "period_inspections": 38,
  "period_days": 30,
  "week_inspections": 12,
  "compliant_count": 98,
  "non_compliant_count": 44,
  "compliance_rate_pct": 69.0,
  "total_violation_flags": 67,
  "generated_at": "2026-09-20T10:00:00Z"
}
```

### `GET /dashboard/violations-by-type`
Violation breakdown by category and declaration field.

| Parameter | Type | Default |
|-----------|------|---------|
| days | integer | 30 |

**Response (200):**
```json
{
  "period_days": 30,
  "by_category": {
    "missing_declaration": 12,
    "font_violation": 8,
    "format_violation": 3,
    "placement_violation": 2,
    "other_violation": 1
  },
  "by_field": {
    "net_quantity": 10,
    "mrp": 5,
    "consumer_care": 3
  },
  "total_non_compliant_inspections": 18
}
```

### `GET /dashboard/trends`
Daily enforcement trend data for charting.

**Response (200):**
```json
{
  "period_days": 30,
  "dates": ["2026-08-21", "2026-08-22", ...],
  "totals": [5, 3, 8, ...],
  "compliant": [3, 2, 6, ...],
  "non_compliant": [2, 1, 2, ...]
}
```

### `GET /dashboard/officer-activity` *(Admin/Supervisor only)*
Per-officer enforcement activity breakdown.

**Response (200):**
```json
{
  "period_days": 30,
  "officers": [
    {
      "officer_id": 2,
      "username": "inspector_verma",
      "full_name": "Rajesh Verma",
      "total_inspections": 24,
      "compliant": 18,
      "non_compliant": 6,
      "compliance_rate_pct": 75.0
    }
  ]
}
```

---

## 5. System (`/`)

### `GET /health`
Health check endpoint (no auth required).

```json
{
  "status": "healthy",
  "service": "LenseScan API",
  "version": "2.0.0"
}
```

### `GET /dashboard`
Serves the Web Enforcement Control Room HTML dashboard (no auth required for page load; API calls require auth).
