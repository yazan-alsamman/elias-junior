# Local CV JSON (fake parser output)

The Flutter app mimics the Llama CV parser by reading/writing JSON in this shape.

## Bundled default

- `app/assets/cv_parsed/default_cv.json` — sample **ALEX RIVERA** profile (shipped with the app).

## On device (after upload)

Android emulator / phone:

```
/data/data/<your.app.package>/app_flutter/cv_parsed/
  latest.json
  <timestamp>_<filename>.json
```

Each file is an envelope:

```json
{
  "version": 1,
  "engine": "llama-lora-cv-parser-v1",
  "parsedAt": "...",
  "sourceFileName": "resume.pdf",
  "parsedCv": { "profile": { ... }, "skills": [], "experience": [] }
}
```

## Flow

1. Upload CV on Dashboard → ATS runs → text heuristics build `parsedCv` → saved to `cv_parsed/`.
2. Portfolio → **Generate portfolio preview** → loads `latest.json` (no Hostinger parser required).

To add more samples, copy valid envelopes into `app/assets/cv_parsed/` and list them in `pubspec.yaml`.
