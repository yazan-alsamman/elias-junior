@echo off
:: Local stack for Jnior CareerPath:
::   - ATS rule engine        http://127.0.0.1:8000
::   - CV parser (LoRA model) http://127.0.0.1:8001
::   - Node API (save to Mongo) http://127.0.0.1:3003  ← needed until Hostinger deploys save-analysis
::
:: The Flutter app calls ATS + parser directly, then saves via Hostinger OR local Node.
::
:: Run from this folder:
::   PowerShell: .\start-local-dev.cmd
::   CMD:        start-local-dev.cmd

set ROOT=%~dp0
set ATS_DIR=%ROOT%Junior_code\ats-rule-engine copy

echo [1/3] ATS Rule Engine (Uvicorn) on http://127.0.0.1:8000 ...
start "Uvicorn - ATS :8000" cmd /k "cd /d "%ATS_DIR%" && pip install -r requirements.txt -q 2>nul && uvicorn app.main:app --host 0.0.0.0 --port 8000"

timeout /t 2 /nobreak >nul

echo [2/3] CV Parser (optional — needs HF token in cv-parser\.env) ...
start "Uvicorn - CV Parser :8001" cmd /k "call "%ROOT%start-cv-parser-uvicorn.cmd""

timeout /t 2 /nobreak >nul

echo [3/3] Node API (Mongo save fallback) on http://127.0.0.1:3003 ...
start "Node - CareerPath API :3003" cmd /k "cd /d "%ROOT%backend" && npm start"

echo.
echo ============================================================
echo  Local features started:
echo    ATS:     http://127.0.0.1:8000/
echo    Parser:  http://127.0.0.1:8001/health  (wait for model load)
echo    Node:    http://127.0.0.1:3003/health  (saves ATS + parsed JSON to Mongo)
echo  Storage:   Hostinger first, falls back to local Node on 404
echo ============================================================
echo.
echo Now run the Flutter app:
echo    cd app
echo    flutter run -d chrome
echo.
pause
