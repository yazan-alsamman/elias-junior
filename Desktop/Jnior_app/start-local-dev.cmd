@echo off
:: Local stack for Jnior CareerPath:
::   - ATS rule engine        http://127.0.0.1:8000
::   - CV parser (LoRA model) http://127.0.0.1:8001
::
:: The Flutter app calls these two URLs DIRECTLY for ATS and parsing.
:: The main backend stays on Hostinger:
::   https://rosybrown-jackal-732122.hostingersite.com
::
:: Run from this folder:
::   PowerShell: .\start-local-dev.cmd
::   CMD:        start-local-dev.cmd

set ROOT=%~dp0
set ATS_DIR=%ROOT%Junior_code\ats-rule-engine copy

echo [1/2] ATS Rule Engine (Uvicorn) on http://127.0.0.1:8000 ...
start "Uvicorn - ATS :8000" cmd /k "cd /d "%ATS_DIR%" && pip install -r requirements.txt -q 2>nul && uvicorn app.main:app --host 0.0.0.0 --port 8000"

timeout /t 2 /nobreak >nul

echo [2/2] CV Parser (Uvicorn + Llama 3.2 LoRA) on http://127.0.0.1:8001 ...
start "Uvicorn - CV Parser :8001" cmd /k "call "%ROOT%start-cv-parser-uvicorn.cmd""

echo.
echo ============================================================
echo  Local features started:
echo    ATS:     http://127.0.0.1:8000/
echo    Parser:  http://127.0.0.1:8001/health  (wait for model load)
echo  Main backend: https://rosybrown-jackal-732122.hostingersite.com
echo ============================================================
echo.
echo Now run the Flutter app:
echo    cd app
echo    flutter run -d chrome     (Web)
echo    flutter run -d windows    (Desktop)
echo    flutter run               (Android emulator — uses 10.0.2.2)
echo.
pause
