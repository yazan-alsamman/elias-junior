@echo off
:: ATS Rule Engine — run with Uvicorn (FastAPI ASGI server).
:: Flutter app + Node backend expect port 8010 (8000 is often used by other dev tools).

set ROOT=%~dp0
set ATS_DIR=%ROOT%Junior_code\ats-rule-engine copy

curl.exe -s -m 2 http://127.0.0.1:8010/ 2>nul | findstr /C:"ATS Rule Engine" >nul
if %ERRORLEVEL%==0 (
  echo.
  echo  ATS is already running on http://127.0.0.1:8010
  echo  Close the other "Uvicorn - ATS :8010" window if you want to restart.
  echo  Or run:  taskkill /F /PID ^(see netstat -ano ^| findstr :8010^)
  echo.
  pause
  exit /b 0
)

echo Starting ATS on Uvicorn: http://127.0.0.1:8010
echo OpenAPI docs: http://127.0.0.1:8010/docs
echo Health:      http://127.0.0.1:8010/
echo.
echo For Hostinger to reach this PC, use ngrok in another terminal:
echo   ngrok http 8010
echo Then set ATS_FASTAPI_URL on Hostinger to the https://....ngrok-free.dev URL.
echo.

cd /d "%ATS_DIR%"
pip install -r requirements.txt -q
uvicorn app.main:app --host 0.0.0.0 --port 8010 --reload
