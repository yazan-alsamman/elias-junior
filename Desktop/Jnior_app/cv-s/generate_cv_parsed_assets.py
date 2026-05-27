#!/usr/bin/env python3
"""Build app/assets/cv_parsed/*.json from every PDF in cv-s/ (portfolio seed data)."""

from __future__ import annotations

import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from pypdf import PdfReader

ROOT = Path(__file__).resolve().parent
ASSETS = ROOT.parent / "app" / "assets" / "cv_parsed"
ENGINE = "llama-lora-cv-parser-v1"

_EMAIL = re.compile(r"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}", re.I)
_PHONE = re.compile(r"(\+?\d[\d\s().-]{6,}\d)")
_JOB = re.compile(r"^(.+?)\s*\|\s*(.+?)\s*\|\s*(.+?)\s*\|\s*(.+)$", re.M)


def _str(v: Any) -> str:
    return str(v).strip() if v is not None else ""


def extract_text(pdf: Path) -> str:
    reader = PdfReader(str(pdf))
    return "\n".join((page.extract_text() or "") for page in reader.pages).strip()


def _email(text: str) -> str:
    m = _EMAIL.search(text)
    return m.group(0).strip() if m else ""


def _phone(text: str) -> str:
    for line in text.split("\n")[:25]:
        if re.search(r"phone|mobile|tel", line, re.I):
            m = _PHONE.search(line)
            if m:
                return m.group(1).strip()
    m = _PHONE.search(text)
    return m.group(1).strip() if m else ""


def _location(text: str) -> str:
    m = re.search(r"^\s*location\s*:\s*(.+)$", text, re.I | re.M)
    return m.group(1).strip() if m else ""


def _name(text: str) -> str:
    skip = re.compile(
        r"^(email|phone|location|linkedin|github|skills|experience|education|professional|technical|about)\s",
        re.I,
    )
    for line in text.split("\n")[:12]:
        t = line.strip()
        if not t or len(t) > 80:
            continue
        if _EMAIL.search(t) or _PHONE.search(t):
            continue
        if skip.match(t) or t.startswith(("-", "•")):
            continue
        if re.match(r"^-{3,}$", t):
            continue
        return t
    return ""


def _headline(text: str, name: str) -> str:
    name_l = name.lower()
    for line in text.split("\n")[:20]:
        t = line.strip()
        if not t or t.lower() == name_l:
            continue
        if _EMAIL.search(t) or _PHONE.search(t):
            continue
        if re.match(r"^(email|phone|location|linkedin|github)\s*:", t, re.I):
            continue
        if re.match(r"^-{3,}$", t):
            continue
        if len(t) < 120 and not t.startswith(("-", "•")):
            return t
    return ""


def _section(text: str, headings: list[str]) -> str:
    lines = text.split("\n")
    for i, line in enumerate(lines):
        low = line.strip().lower()
        if not any(h in low for h in headings):
            continue
        buf: list[str] = []
        for j in range(i + 1, min(i + 30, len(lines))):
            nxt = lines[j].strip()
            if not nxt:
                if buf:
                    break
                continue
            if re.match(r"^-{3,}$", nxt):
                continue
            if re.match(
                r"^(technical skills|skills|experience|education|projects|certifications|languages|volunteering)\b",
                nxt,
                re.I,
            ):
                break
            buf.append(nxt)
        return " ".join(buf).strip()
    return ""


def _skills(text: str) -> list[str]:
    out: list[str] = []
    in_skills = False
    for line in text.split("\n"):
        low = line.strip().lower()
        if re.search(r"technical skills|^skills\b|competencies", low):
            in_skills = True
            continue
        if in_skills and re.match(
            r"^(experience|education|projects|certifications|languages|volunteering|professional summary)\b",
            low,
        ):
            break
        if not in_skills:
            continue
        t = line.strip()
        if not t or re.match(r"^-{3,}$", t):
            continue
        if ":" in t:
            _, rhs = t.split(":", 1)
            for piece in re.split(r"[,;]", rhs):
                s = piece.strip()
                if 2 <= len(s) <= 40:
                    out.append(s)
        elif 2 <= len(t) <= 40:
            out.append(t)
    if not out:
        summary = _section(text, ["professional summary", "summary", "profile"])
        for piece in re.split(r"[,;]", summary):
            s = piece.strip()
            if re.match(r"^(python|java|typescript|javascript|go|sql|aws|react)", s, re.I):
                out.append(s)
    return out[:24]


def _experience(text: str) -> list[dict[str, str]]:
    items: list[dict[str, str]] = []
    in_exp = False
    for line in text.split("\n"):
        low = line.strip().lower()
        if re.match(r"^(experience|work history)\b", low):
            in_exp = True
            continue
        if in_exp and re.match(
            r"^(technical skills|skills|education|projects|certifications|professional summary|about me)\b",
            low,
        ):
            break
        if not in_exp:
            continue
        t = line.strip()
        if not t or re.match(r"^-{3,}$", t):
            continue
        m = _JOB.match(t)
        if m:
            pos, company, _loc, period = m.groups()
            items.append(
                {
                    "position": pos.strip(),
                    "company": company.strip(),
                    "period": period.strip(),
                    "description": "",
                }
            )
            continue
        if t.startswith(("-", "•")) and items:
            prev = items[-1]["description"]
            bullet = t.lstrip("-• ").strip()
            items[-1]["description"] = f"{prev}\n{bullet}".strip() if prev else bullet
    return items[:8]


def _education(text: str) -> list[dict[str, str]]:
    items: list[dict[str, str]] = []
    in_edu = False
    for line in text.split("\n"):
        low = line.strip().lower()
        if low.startswith("education"):
            in_edu = True
            continue
        if in_edu and re.match(
            r"^(technical skills|skills|experience|projects|certifications|languages|volunteering)\b",
            low,
        ):
            break
        if not in_edu:
            continue
        t = line.strip()
        if not t or re.match(r"^-{3,}$", t):
            continue
        if t.startswith(("-", "•")):
            continue
        m = re.match(r"^(.+?)\s*\|\s*(.+?)\s*\|\s*(.+?)\s*\|\s*(.+)$", t)
        if m:
            degree, school, _loc, period = m.groups()
            items.append(
                {
                    "degree": degree.strip(),
                    "school": school.strip(),
                    "period": period.strip(),
                }
            )
    return items[:6]


def _certifications(text: str) -> list[str]:
    block = _section(text, ["certifications"])
    out: list[str] = []
    for line in block.split("\n"):
        t = line.strip().lstrip("-• ")
        if t and len(t) < 120:
            out.append(t)
    return out[:8]


def parse_resume_text(text: str) -> dict[str, Any]:
    name = _name(text)
    headline = _headline(text, name)
    return {
        "profile": {
            "name": name,
            "headline": headline,
            "location": _location(text),
            "contact": {"email": _email(text), "phone": _phone(text)},
            "summary": _section(text, ["professional summary", "summary", "profile", "about me"]),
        },
        "skills": _skills(text),
        "experience": _experience(text),
        "education": _education(text),
        "projects": [],
        "certifications": _certifications(text),
    }


def has_portfolio_data(parsed: dict[str, Any]) -> bool:
    p = parsed.get("profile") or {}
    return bool(
        _str(p.get("name"))
        or _str(p.get("headline"))
        or _str(p.get("summary"))
        or _str((p.get("contact") or {}).get("email"))
        or parsed.get("skills")
        or parsed.get("experience")
        or parsed.get("education")
    )


def envelope(source_file: str, parsed: dict[str, Any]) -> dict[str, Any]:
    return {
        "version": 1,
        "engine": ENGINE,
        "parsedAt": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "sourceFileName": source_file,
        "parsedCv": parsed,
    }


def main() -> int:
    ASSETS.mkdir(parents=True, exist_ok=True)
    pdfs = sorted(ROOT.glob("*.pdf"))
    if not pdfs:
        print("No PDFs in cv-s/", file=sys.stderr)
        return 1

    index: dict[str, str] = {}
    written = 0
    for pdf in pdfs:
        text = extract_text(pdf)
        parsed = parse_resume_text(text)
        if not has_portfolio_data(parsed):
            print(f"  skip (no data): {pdf.name}")
            continue
        out_name = pdf.stem + ".json"
        out_path = ASSETS / out_name
        env = envelope(pdf.name, parsed)
        out_path.write_text(json.dumps(env, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        index[pdf.name.lower()] = f"assets/cv_parsed/{out_name}"
        written += 1
        print(f"  {pdf.name} -> {out_name}")

    # Default portfolio seed = Jordan Chen persona CV.
    jordan_key = "cv_test_01_jordan_chen.pdf"
    if jordan_key.lower() in index:
        src = ASSETS / "cv_test_01_jordan_chen.json"
        default = ASSETS / "default_cv.json"
        default.write_text(src.read_text(encoding="utf-8"), encoding="utf-8")
        print(f"  default_cv.json <- cv_test_01_jordan_chen.json")

    index_path = ASSETS / "index.json"
    index_path.write_text(
        json.dumps({"version": 1, "byFileName": index}, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"\nWrote {written} profiles + index.json ({len(index)} entries)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
