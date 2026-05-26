# ATS test CVs (`cv-s/`)

Five PDFs for testing **different ATS scores and failure types** in the app (local ATS on `:8000`).

| File | What it tests | Typical score | UI (score > 70) |
|------|----------------|---------------|-----------------|
| `cv_test_01_score_100_strong.pdf` | Good single-column CV, all sections + contact | **100** | PASS |
| `cv_test_02_score_65_columns.pdf` | **Two-column** layout | **65** | FAIL |
| `cv_test_03_score_55_image.pdf` | **Photo / image** in PDF | **55** | FAIL |
| `cv_test_04_score_80_no_sections.pdf` | **No** standard headings, **no** email/phone | **80** | PASS |
| `cv_test_05_score_15_combo.pdf` | **Image + columns +** no contact/headings | **15** | FAIL |

Scores follow the app formula: `100 − 10×failed_rules − 25` if any basic rule fails.

## Regenerate

```powershell
pip install fpdf2
python cv-s/generate_test_cvs.py
python cv-s/generate_test_cvs.py --check   # needs ATS on :8000
```

## Test in Flutter

```powershell
.\start-local-dev.cmd
cd app
flutter run -d chrome
```

Upload each PDF from this folder and compare dashboard badges / post-upload ATS card.

## Layout reference

`cv_test_01` follows the same plain-text style as `sample_cv.pdf` on your Desktop. The others intentionally break specific ATS rules (columns, images, missing sections).
