# ============================================================
# LenseScan — 1-Click Runner for Mobile (Wi-Fi)
# ============================================================

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " Starting LenseScan Mobile Environment..." -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# 1. Build Flutter web if not already built
if (-not (Test-Path "lensescan\build\web\index.html")) {
    Write-Host "[*] Building Flutter Web production bundle (one-time setup)..." -ForegroundColor Yellow
    Set-Location lensescan
    flutter build web
    Set-Location ..
}

# 2. Start Backend on port 8000 if not already running
$backendRunning = Get-NetTCPConnection -LocalPort 8000 -ErrorAction SilentlyContinue
if (-not $backendRunning) {
    Write-Host "[+] Starting FastAPI backend on http://127.0.0.1:8000..." -ForegroundColor Green
    Start-Process powershell -ArgumentList "-NoExit", "-Command", ".\backend\.venv\Scripts\python.exe -m uvicorn app.main:app --app-dir backend --host 127.0.0.1 --port 8000"
    Start-Sleep -Seconds 3
} else {
    Write-Host "[√] FastAPI backend is already running on port 8000." -ForegroundColor Green
}

# 3. Start HTTPS Server on port 8443
Write-Host "[+] Launching Wi-Fi HTTPS Server on port 8443..." -ForegroundColor Green
.\backend\.venv\Scripts\python.exe scripts\wifi_ssl_proxy.py
