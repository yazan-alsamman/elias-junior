# cv-s — low ATS score test CVs

Generated samples for upload testing. **Use `cv_ats_score_05.pdf` for score ~5.**

| File | App score | Notes |
|------|-----------|--------|
| cv_ats_score_05.pdf | **5** | 7 failed rules |
| cv_ats_score_05b.pdf | **5** | 7 failed rules |
| cv_ats_score_15.pdf | **15** | 6 failed rules |
| cv_ats_score_35.pdf | **60** | 4 failed rules |
| cv_ats_score_25.docx | **35** | 4 failed rules |
| cv_ats_score_55.docx | **45** | 3 failed rules |

Score ~5 PDFs are ~5.2 MB (triggers file-size rule). Regenerate:

```powershell
cd cv-parser
.venv\Scripts\activate
pip install python-docx fpdf2 -q
python ..\cv-s\generate_samples.py
```

Requires ATS: `http://127.0.0.1:8000` and app stack: `start-local-dev.cmd`
