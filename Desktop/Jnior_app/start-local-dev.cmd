@echo off
:: Local stack (ATS-only mode — CV parser paused):
::   - ATS rule engine  http://127.0.0.1:8000
::   - Node API         http://127.0.0.1:3003  (saves ATS results to Mongo)
::
:: Run:  .\start-local-dev.cmd
:: Then: cd app && flutter run -d chrome

set ROOT=%~dp0
set ATS_DIR=%ROOT%Junior_code\ats-rule-engine copy

echo [1/2] ATS Rule Engine (Uvicorn) on http://127.0.0.1:8000 ...
start "Uvicorn - ATS :8000" cmd /k "cd /d "%ATS_DIR%" && pip install -r requirements.txt -q 2>nul && uvicorn app.main:app --host 0.0.0.0 --port 8000"

timeout /t 2 /nobreak >nul

echo [2/2] Node API (Mongo save) on http://127.0.0.1:3003 ...
start "Node - CareerPath API :3003" cmd /k "cd /d "%ROOT%backend" && npm start"

echo.
echo ============================================================
echo  Started (CV parser paused):
echo    ATS:  http://127.0.0.1:8000/
echo    Node: http://127.0.0.1:3003/health
echo  Storage: Hostinger, falls back to local Node on 404
echo ============================================================
echo.
echo  To re-enable CV parser later:
echo    flutter run --dart-define=CV_PARSER_ENABLED=true
echo    and run start-cv-parser-uvicorn.cmd separately
echo.
pause
