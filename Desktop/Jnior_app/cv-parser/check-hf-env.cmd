@echo off
:: Pre-flight check for cv-parser/.env before loading the 7GB Llama model.
setlocal
cd /d "%~dp0"

if not exist ".env" (
  echo [cv-parser] Missing .env — copy .env.example to .env and set HF_TOKEN.
  exit /b 1
)

for /f "usebackq tokens=1,* delims==" %%A in (".env") do (
  set "LINE=%%A"
  if /i "%%A"=="HF_TOKEN" (
    set "HF_VAL=%%B"
  )
)

set "VAL=%HF_VAL:"=%"
set "VAL=%VAL:'=%"

if "%VAL%"=="" (
  echo [cv-parser] HF_TOKEN is empty in .env
  exit /b 1
)
if /i "%VAL%"=="hf_replace_me" goto :placeholder
if /i "%VAL%"=="your_huggingface_token" goto :placeholder
echo %VAL% | findstr /i "replace your_ xxx" >nul && goto :placeholder
echo %VAL% | findstr /b "hf_" >nul || (
  echo [cv-parser] HF_TOKEN must start with hf_
  exit /b 1
)

echo [cv-parser] HF_TOKEN looks configured.
exit /b 0

:placeholder
echo.
echo ============================================================
echo  CV PARSER NOT STARTED — HF_TOKEN is still a placeholder
echo ============================================================
echo.
echo  Open this file in Notepad and paste your real token:
echo    %CD%\.env
echo.
echo  Get a Read token:  https://huggingface.co/settings/tokens
echo  Request access:    https://huggingface.co/meta-llama/Llama-3.2-3B-Instruct
echo.
echo  ATS (:8000) and Node (:3003) still work without the parser.
echo ============================================================
exit /b 1
