# How to run Jnior — Hostinger backend + local ATS / CV parser

Architecture:

```
Flutter app ──auth/storage──► Hostinger:  https://rosybrown-jackal-732122.hostingersite.com
            ──ATS check─────► local PC :8000   (FastAPI rule engine)
            ──CV parse──────► local PC :8001   (Llama 3.2 + LoRA)
```

The Hostinger backend never reaches your PC. The app does the ATS check and CV
parsing directly against your local Uvicorn services, then sends both results to
Hostinger which saves them in MongoDB (used by the Portfolio page later).

---

## 1. Start the two local features

From the repo root (the folder that contains `app/`, `backend/`, `cv-parser/`):

```powershell
.\start-local-dev.cmd
```

You should see two new windows:

| Window | URL | Test |
|---|---|---|
| `Uvicorn - ATS :8000` | <http://127.0.0.1:8000/> | `{"service":"ATS Rule Engine","status":"ok"}` |
| `Uvicorn - CV Parser :8001` | <http://127.0.0.1:8001/health> | `{"status":"ok"}` (after model load) |

> The parser takes a while to load the model the first time. ATS works immediately.

### One-time CV parser setup (Hugging Face)

`meta-llama/Llama-3.2-3B-Instruct` is a **gated** model on Hugging Face.
You must do this once:

1. Open <https://huggingface.co/meta-llama/Llama-3.2-3B-Instruct> and click
   "Request access" (Meta usually approves in minutes).
2. Create a Read token at <https://huggingface.co/settings/tokens>.
3. Copy `cv-parser/.env.example` to `cv-parser/.env` and paste the token:

   ```
   HF_TOKEN=hf_xxxxxxxxxxxxxxxxxxxxx
   CV_API_MODEL_ID=meta-llama/Llama-3.2-3B-Instruct
   CV_API_ADAPTER_PATH=lora-resume-archive
   CV_API_LOAD_IN_4BIT=1
   ```

The parser auto-loads `cv-parser/.env` at startup, so you only do this once.

If you skip it, the ATS check still works — the parser will just fail to start
and the app shows a "CV parser skipped" toast on upload (placeholder portfolio).

---

## 2. Run the Flutter app

```powershell
cd app
flutter pub get
flutter run -d chrome     # browser
# or
flutter run -d windows    # native desktop
# or
flutter run               # Android emulator (uses 10.0.2.2 automatically)
```

The app already knows:

| URL | Source |
|---|---|
| Main API | `https://rosybrown-jackal-732122.hostingersite.com` (hard-coded) |
| ATS | `http://127.0.0.1:8000` (or `10.0.2.2:8000` on Android emulator) |
| CV parser | `http://127.0.0.1:8001` (or `10.0.2.2:8001` on Android emulator) |

### Optional overrides at build time

```powershell
flutter run --dart-define=ATS_URL=http://192.168.1.20:8000 ^
            --dart-define=CV_PARSER_URL=http://192.168.1.20:8001
```

Use these when running on a physical phone — replace `192.168.1.20` with your
PC's LAN IP. Allow inbound TCP 8000 and 8001 in Windows Firewall.

---

## 3. End-to-end test

1. Open the app, sign in (account on Hostinger).
2. Go to Dashboard → Upload CV → choose a real PDF.
3. The app will:
   - Send the file to `http://127.0.0.1:8000/ats-format/check` → real ATS score.
   - Send the file to `http://127.0.0.1:8001/parse/pdf` → JSON profile (skills, projects…).
   - Send both results to Hostinger `POST /api/cv/documents/save-analysis`.
4. The post-upload screen shows **Decision: PASS/FAIL**, **score = 100** for PASS or
   `100 − 10·rules − 25 (if basic failed)` for FAIL.
5. Open Portfolio — the preview should fill with your real name, summary, skills,
   and project titles from the parser JSON.

### Quick manual probes

```powershell
# ATS health
curl http://127.0.0.1:8000/

# ATS upload (PowerShell 7+ has curl alias to Invoke-WebRequest)
curl.exe -X POST "http://127.0.0.1:8000/ats-format/check" -F "file=@C:\path\to\cv.pdf"

# Parser health
curl http://127.0.0.1:8001/health

# Parser PDF
curl.exe -X POST "http://127.0.0.1:8001/parse/pdf" -F "file=@C:\path\to\cv.pdf"

# Hostinger save endpoint (needs JWT)
curl.exe -X POST https://rosybrown-jackal-732122.hostingersite.com/api/cv/documents/save-analysis ^
         -H "Authorization: Bearer <JWT>" ^
         -H "Content-Type: application/json" ^
         -d "{\"originalFileName\":\"x.pdf\",\"fileType\":\"pdf\",\"ats\":{\"decision\":\"PASS\",\"failed_basic\":false,\"failed_rules_count\":0,\"failures\":[]}}"
```

---

## 4. Deploy the new backend route to Hostinger

The app now calls `POST /api/cv/documents/save-analysis` on Hostinger. Push the
`backend/` folder to the `elias-junior` GitHub repo and let Hostinger redeploy:

```powershell
cd backend
git add src/controllers/cv.controller.js src/routes/cv.routes.js
git commit -m "Add POST /api/cv/documents/save-analysis for local ATS/parser results"
git push
```

After redeploy:

```powershell
curl https://rosybrown-jackal-732122.hostingersite.com/health
```

should return `{"ok":true,"service":"careerpath-api", ...}`.

---

## 5. Common issues

| Symptom | Fix |
|---|---|
| ATS score 28 / "Text-only estimate" banner | Old behavior. Restart Flutter, upload again. App now talks to 127.0.0.1:8000 directly. |
| `ATS engine offline` toast | The ATS Uvicorn window is closed. Run `start-local-dev.cmd` again. |
| `CV parser skipped` toast | `:8001` not reachable (model still loading or `HF_TOKEN` missing). ATS score still saved. |
| Portfolio shows fake names | Parser did not run for this CV. Re-upload after `:8001/health` returns `ok`. |
| Android phone (real device) can't reach ATS | Use `--dart-define=ATS_URL=http://<LAN_IP>:8000` and open firewall ports 8000/8001. |
