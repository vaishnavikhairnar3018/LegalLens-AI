# LenseScan — Deployment Guide

**System:** Legal Metrology Compliance Checking System  
**Version:** 2.0 | **Date:** September 2026

---

## 1. Prerequisites

- **Python** 3.12+
- **PostgreSQL** 16+ (or Docker)
- **Flutter** 3.x SDK (for mobile app builds)
- **Node.js** (optional, for any JS tooling)
- **Git**

---

## 2. Backend Deployment

### 2.1 Clone & Setup

```bash
git clone <repository-url> LenseScan
cd LenseScan/backend
```

### 2.2 Virtual Environment

```bash
python -m venv .venv

# Linux/Mac
source .venv/bin/activate

# Windows
.venv\Scripts\activate

pip install -r requirements.txt
```

### 2.3 Environment Configuration

Create a `.env` file in `backend/`:

```env
# Application
APP_NAME=LenseScan API
APP_VERSION=2.0.0
DEBUG=false

# Security — CHANGE THESE IN PRODUCTION
SECRET_KEY=<generate-a-64-byte-random-string>
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=60

# Database (PostgreSQL)
DATABASE_URL=postgresql+asyncpg://lensescan_user:strong_password@localhost:5432/lensescan_db

# CORS
ALLOWED_ORIGINS=http://localhost:3000,http://localhost:8000

# Upload Limits
MAX_UPLOAD_SIZE_MB=10

# OCR
OCR_LANGUAGES=en,hi
DEFAULT_DPI=300
```

### 2.4 Database Setup

```bash
# Create PostgreSQL database
psql -U postgres -c "CREATE DATABASE lensescan_db;"
psql -U postgres -c "CREATE USER lensescan_user WITH PASSWORD 'strong_password';"
psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE lensescan_db TO lensescan_user;"

# Run migrations (if Alembic is configured)
alembic upgrade head

# Or let the app auto-create tables on first startup
```

### 2.5 Run the Server

```bash
# Development
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload

# Production (multi-worker)
uvicorn app.main:app --host 0.0.0.0 --port 8000 --workers 4
```

### 2.6 Verify

- Health check: `http://localhost:8000/health`
- API docs: `http://localhost:8000/docs` (debug mode only)
- Web dashboard: `http://localhost:8000/dashboard`

---

## 3. Docker Deployment

### 3.1 Dockerfile

```dockerfile
FROM python:3.12-slim

WORKDIR /app

# Install system dependencies for OpenCV
RUN apt-get update && apt-get install -y \
    libgl1-mesa-glx libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "4"]
```

### 3.2 Docker Compose

```yaml
version: '3.8'

services:
  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: lensescan_db
      POSTGRES_USER: lensescan_user
      POSTGRES_PASSWORD: strong_password
    volumes:
      - pgdata:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U lensescan_user -d lensescan_db"]
      interval: 10s
      timeout: 5s
      retries: 5

  api:
    build: ./backend
    ports:
      - "8000:8000"
    environment:
      DATABASE_URL: postgresql+asyncpg://lensescan_user:strong_password@db:5432/lensescan_db
      SECRET_KEY: ${SECRET_KEY:-change-me-in-production}
      DEBUG: "false"
    depends_on:
      db:
        condition: service_healthy
    restart: unless-stopped

volumes:
  pgdata:
```

### 3.3 Launch

```bash
docker compose up -d
```

---

## 4. Flutter Mobile App

### 4.1 Build APK (Android)

```bash
cd lensescan
flutter pub get
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

### 4.2 Build App Bundle (Play Store)

```bash
flutter build appbundle --release
```

### 4.3 Build iOS

```bash
flutter build ipa --release
```

### 4.4 Configure API URL

Edit `lib/core/constants.dart` or the app's environment config to point to
the production backend URL.

---

## 5. Web Dashboard

The web dashboard is served directly from FastAPI at `/dashboard`.
No separate build step is required — it consists of static HTML/CSS/JS files
in `backend/app/static/dashboard/`.

To access:
1. Start the backend server
2. Navigate to `http://<server-ip>:8000/dashboard`
3. Log in with valid credentials

---

## 6. Security Hardening (Production)

| Item | Action |
|------|--------|
| SECRET_KEY | Generate with `python -c "import secrets; print(secrets.token_urlsafe(64))"` |
| DEBUG | Set to `false` |
| HTTPS | Deploy behind nginx/Caddy with TLS certificates |
| CORS | Restrict `ALLOWED_ORIGINS` to actual frontend domains |
| Database | Enable SSL for PostgreSQL connections |
| Rate Limiting | Add `slowapi` or nginx rate limiting |
| Logging | Configure structured logging to a SIEM |
| Passwords | Force password change from default `Admin@123456` |

---

## 7. Performance Tuning

| Parameter | Recommendation |
|-----------|---------------|
| Uvicorn Workers | `2 * CPU_CORES + 1` |
| PostgreSQL pool_size | 20 (configured in `database.py`) |
| PostgreSQL max_overflow | 10 |
| EasyOCR | Pre-loaded at startup (singleton pattern) |
| Image Upload Limit | 10MB default, adjustable via `MAX_UPLOAD_SIZE_MB` |
