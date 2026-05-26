# ATS test CVs (`cv-s/`)

Five PDF résumés in the same **plain-text, ATS-friendly layout** as `sample_cv.pdf` on your Desktop:

- Standard sections: **Professional Summary**, **Technical Skills**, **Experience**, **Education**
- Contact email + phone in the document body (not header/footer only)
- Selectable text, no images, single-column layout

## Files

| File | Role |
|------|------|
| `cv_test_01_jordan_chen.pdf` | Senior Software Engineer |
| `cv_test_02_priya_sharma.pdf` | Data Engineer |
| `cv_test_03_marcus_webb.pdf` | Product Manager |
| `cv_test_04_elena_kowalski.pdf` | DevOps / Platform Engineer |
| `cv_test_05_sam_okonkwo.pdf` | Junior Software Developer |

## Regenerate

```powershell
pip install fpdf2 pypdf
python cv-s/generate_test_cvs.py
```

With local ATS running on port **8000**:

```powershell
.\start-local-dev.cmd
python cv-s/generate_test_cvs.py --check
```

## Test in the app

1. Start ATS: `.\start-local-dev.cmd` (or `start-ats-uvicorn.cmd`)
2. `cd app` → `flutter run -d chrome`
3. Upload any `cv_test_*.pdf` from this folder on the dashboard

**Pass/fail in the UI:** score **> 70** = PASS, **≤ 70** = FAIL (rule issues may still appear in recommendations).

## Reference

Template matches `C:\Users\LOQ\Desktop\sample_cv.pdf` (Alex Rivera, 2-page software engineer CV).
