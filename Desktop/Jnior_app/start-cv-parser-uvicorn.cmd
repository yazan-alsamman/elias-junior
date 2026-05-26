@echo off
:: CV Parser (Llama 3.2 + LoRA) — Uvicorn on port 8001 (ATS uses 8000).

set ROOT=%~dp0
set PARSER_DIR=%ROOT%cv-parser

echo Starting CV Parser on Uvicorn: http://127.0.0.1:8001
echo Health: http://127.0.0.1:8001/health
echo Docs:   http://127.0.0.1:8001/docs
echo.
echo One-time setup (gated Llama model):
echo   1) Request access:  https://huggingface.co/meta-llama/Llama-3.2-3B-Instruct
echo   2) Create a token:  https://huggingface.co/settings/tokens (Read scope)
echo   3) Copy cv-parser\.env.example to cv-parser\.env and paste your token.
echo.

cd /d "%PARSER_DIR%"
if not exist ".venv" (
  echo Creating Python venv...
  python -m venv .venv
)
call .venv\Scripts\activate.bat
pip install -r requirements.txt -q

if not exist ".env" (
  echo.
  echo [!] cv-parser\.env not found. Copying .env.example so you can fill in HF_TOKEN.
  copy /Y ".env.example" ".env" >nul 2>&1
  echo     Edit cv-parser\.env now and put your real HF_TOKEN, then re-run this script.
  pause
  exit /b 1
)

call check-hf-env.cmd
if errorlevel 1 (
  pause
  exit /b 1
)

if not defined CV_API_ADAPTER_PATH set CV_API_ADAPTER_PATH=lora-resume-archive
if not defined CV_API_LOAD_IN_4BIT set CV_API_LOAD_IN_4BIT=1

uvicorn cv_api_server:app --host 0.0.0.0 --port 8001
