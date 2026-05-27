@echo off
:: Local stack:
::   - ATS rule engine  http://127.0.0.1:8000
::   - RAG job-fit API  http://127.0.0.1:8002  (needs OPENAI_API_KEY + ingest)
::   - Node API         http://127.0.0.1:3003  (saves ATS results to Mongo)
::
:: Run:  .\start-local-dev.cmd
:: Then: cd app && flutter run -d chrome

set ROOT=%~dp0
set ATS_DIR=%ROOT%Junior_code\ats-rule-engine copy

echo [1/3] ATS Rule Engine (Uvicorn) on http://127.0.0.1:8000 ...
start "Uvicorn - ATS :8000" cmd /k "cd /d "%ATS_DIR%" && pip install -r requirements.txt -q 2>nul && uvicorn app.main:app --host 0.0.0.0 --port 8000"

timeout /t 2 /nobreak >nul

set RAG_DIR=%ROOT%RAG
echo [2/3] RAG Job-Fit API on http://127.0.0.1:8002 ...
start "Uvicorn - RAG :8002" cmd /k "cd /d "%RAG_DIR%" && pip install -e . -q 2>nul && uvicorn cv_rag.api:app --host 0.0.0.0 --port 8002 --app-dir src"

timeout /t 2 /nobreak >nul

echo [3/3] Node API (Mongo save) on http://127.0.0.1:3003 ...
start "Node - CareerPath API :3003" cmd /k "cd /d "%ROOT%backend" && npm start"

echo.
echo ============================================================
echo  Started:
echo    ATS:  http://127.0.0.1:8000/
echo    RAG:  http://127.0.0.1:8002/health  (run: python -m cv_rag.cli ingest)
echo    Node: http://127.0.0.1:3003/health
echo  Storage: Hostinger, falls back to local Node on 404
echo ============================================================
echo.
echo  To re-enable CV parser later:
echo    flutter run --dart-define=CV_PARSER_ENABLED=true
echo    and run start-cv-parser-uvicorn.cmd separately
echo.
pause
