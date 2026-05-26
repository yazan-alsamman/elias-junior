#!/usr/bin/env python3
"""
Generate five ATS test CV PDFs — each targets a different score / failure mode:

  01  Strong single-column (PASS, score 100)
  02  Two-column layout (B2, score ~75)
  03  Photo / image embedded (B1, score ~75)
  04  Missing sections & contact (E4/E6, score ~70)
  05  Image + columns + no ATS headings (many rules, score ~5–25)

Usage:
  pip install fpdf2
  python cv-s/generate_test_cvs.py
  python cv-s/generate_test_cvs.py --check
"""

from __future__ import annotations

import argparse
import json
import os
import struct
import sys
import urllib.request
import zlib
from pathlib import Path
from typing import Callable, List, Tuple

from fpdf import FPDF

ROOT = Path(__file__).resolve().parent
ATS_URL = os.environ.get("ATS_URL", "http://127.0.0.1:8000/ats-format/check")
PASS_SCORE_THRESHOLD = 70
AVATAR_PATH = ROOT / "_assets" / "avatar.png"

# ---------------------------------------------------------------------------
# Shared content (Alex Rivera–style baseline)
# ---------------------------------------------------------------------------

BASE_NAME = "JORDAN CHEN"
BASE_TITLE = "Senior Software Engineer"
BASE_EMAIL = "jordan.chen.dev@email.com"
BASE_PHONE = "+1 (206) 555-0142"
BASE_LOCATION = "Seattle, WA, USA"

SUMMARY = (
    "Results-driven engineer with 8+ years building distributed systems, APIs, "
    "and data pipelines. Led teams of 4-6 engineers; experienced in Python, Go, "
    "and cloud platforms (AWS)."
)

SKILLS = [
    "Languages: Python, Go, TypeScript, SQL",
    "Frameworks: FastAPI, Django, React, Node.js",
    "Cloud: AWS (ECS, Lambda, RDS), Docker, Kubernetes, Terraform",
]

EXPERIENCE = [
    "Staff Software Engineer | Northwind Analytics | Remote | Jan 2022 - Present",
    "- Own ingestion pipeline processing 50M+ events/day; reduced p99 latency by 35%.",
    "- Designed multi-tenant API gateway (FastAPI) for partner integrations.",
    "Senior Backend Engineer | Harbor Systems Inc. | Seattle, WA | Mar 2018 - Dec 2021",
    "- Built microservices in Go and Python on AWS ECS.",
    "- Introduced OpenTelemetry tracing; cut MTTR by 40%.",
]

EDUCATION = [
    "M.S. Computer Science | University of Washington | 2013 - 2015",
    "B.S. Mathematics & CS | UT Austin | 2009 - 2013",
]


def _tiny_png(path: Path) -> None:
    """Minimal valid PNG for ATS image detection (no PIL required)."""
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        return
    # 32x32 blue square
    w, h = 32, 32
    raw = b"".join(
        b"\x00" + bytes((40, 80, 200)) * w for _ in range(h)
    )
    def chunk(tag: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + tag + data + struct.pack(
            ">I", zlib.crc32(tag + data) & 0xFFFFFFFF
        )

    ihdr = struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)
    png = (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", ihdr)
        + chunk(b"IDAT", zlib.compress(raw))
        + chunk(b"IEND", b"")
    )
    path.write_bytes(png)


class AtsCvPdf(FPDF):
    def __init__(self) -> None:
        super().__init__()
        self.set_auto_page_break(auto=True, margin=16)
        self.set_margins(left=18, top=16, right=18)

    @property
    def content_width(self) -> float:
        return self.w - self.l_margin - self.r_margin

    def section(self, title: str) -> None:
        self.set_x(self.l_margin)
        self.ln(3)
        self.set_font("Helvetica", "B", 11)
        self.multi_cell(self.content_width, 6, title)
        self.set_font("Helvetica", "", 9)
        self.set_x(self.l_margin)
        self.multi_cell(self.content_width, 5, "-" * 72)

    def body_lines(self, lines: List[str], size: int = 10, lh: float = 5.5) -> None:
        self.set_font("Helvetica", "", size)
        for line in lines:
            self.set_x(self.l_margin)
            self.multi_cell(self.content_width, lh, line)

    def header_block(
        self,
        *,
        name: str = BASE_NAME,
        title: str = BASE_TITLE,
        email: str = BASE_EMAIL,
        phone: str = BASE_PHONE,
        include_contact: bool = True,
    ) -> None:
        w = self.content_width
        self.set_font("Helvetica", "B", 14)
        self.cell(w, 8, name, new_x="LMARGIN", new_y="NEXT")
        self.set_font("Helvetica", "", 11)
        self.cell(w, 6, title, new_x="LMARGIN", new_y="NEXT")
        self.ln(2)
        if include_contact:
            self.body_lines(
                [
                    f"Email: {email}",
                    f"Phone: {phone}",
                    f"Location: {BASE_LOCATION}",
                    "LinkedIn: linkedin.com/in/jordanchendev",
                ]
            )
            self.ln(2)


def build_strong(out: Path) -> None:
    """01 — Best ATS layout: single column, all required headings, full contact."""
    pdf = AtsCvPdf()
    pdf.add_page()
    pdf.header_block()
    # Education early so ATS text sample (first ~2600 chars) always includes it.
    pdf.section("Education")
    pdf.body_lines(EDUCATION)
    pdf.section("Technical Skills")
    pdf.body_lines(SKILLS)
    pdf.section("Experience")
    pdf.body_lines(EXPERIENCE[:3])
    pdf.section("Professional Summary")
    pdf.body_lines([SUMMARY[:200]])
    pdf.output(str(out))


def build_two_columns(out: Path) -> None:
    """02 — Deliberate two-column body (triggers B2_NO_COLUMNS)."""
    pdf = AtsCvPdf()
    pdf.add_page()
    pdf.header_block()
    pdf.body_lines(
        [
            "Education: University of Washington. Skills: Python, AWS, SQL.",
            "Experience: Northwind Analytics, Harbor Systems.",
        ]
    )
    pdf.ln(2)

    # Right column must sit past mid + split_tol (~362pt on letter page).
    left_x, right_x = 18.0, 370.0
    line_h = 4.2
    y = 58.0
    pdf.set_font("Helvetica", "", 9)

    left_topics = SKILLS + EXPERIENCE + EDUCATION
    right_topics = [
        "Right column filler for ATS two-column detection testing.",
        "Additional metrics, ownership, and delivery highlights.",
        "Cross-functional work with product, design, and operations.",
    ] * 20

    for i in range(48):
        if y > 270:
            pdf.add_page()
            y = 20.0
        pdf.set_xy(left_x, y)
        pdf.cell(
            160,
            line_h,
            (left_topics[i % len(left_topics)] if left_topics else "Left col")[:62],
            new_x="RIGHT",
            new_y="TOP",
        )
        pdf.set_xy(right_x, y)
        pdf.cell(
            160,
            line_h,
            right_topics[i % len(right_topics)][:62],
            new_x="RIGHT",
            new_y="TOP",
        )
        y += line_h

    pdf.output(str(out))


def build_with_image(out: Path) -> None:
    """03 — Headshot image + otherwise good single-column CV (triggers B1_NO_IMAGES)."""
    _tiny_png(AVATAR_PATH)
    pdf = AtsCvPdf()
    pdf.add_page()
    pdf.image(str(AVATAR_PATH), x=18, y=16, w=28, h=28)
    pdf.set_xy(52, 18)
    pdf.set_font("Helvetica", "B", 14)
    pdf.cell(0, 8, BASE_NAME)
    pdf.set_xy(52, 26)
    pdf.set_font("Helvetica", "", 11)
    pdf.cell(0, 6, BASE_TITLE)
    pdf.set_xy(18, 48)
    pdf.body_lines(
        [
            f"Email: {BASE_EMAIL}",
            f"Phone: {BASE_PHONE}",
            f"Location: {BASE_LOCATION}",
        ]
    )
    pdf.section("Education")
    pdf.body_lines(EDUCATION)
    pdf.section("Technical Skills")
    pdf.body_lines(SKILLS)
    pdf.section("Experience")
    pdf.body_lines(EXPERIENCE[:3])
    pdf.section("Professional Summary")
    pdf.body_lines([SUMMARY[:180]])
    pdf.output(str(out))


def build_minimal_no_sections(out: Path) -> None:
    """04 — No standard headings, no email or phone (E6 + 2x E4)."""
    pdf = AtsCvPdf()
    pdf.add_page()
    pdf.set_font("Helvetica", "B", 14)
    pdf.cell(pdf.content_width, 8, BASE_NAME, new_x="LMARGIN", new_y="NEXT")
    pdf.set_font("Helvetica", "", 11)
    pdf.cell(pdf.content_width, 6, BASE_TITLE, new_x="LMARGIN", new_y="NEXT")
    pdf.ln(4)
    pdf.body_lines([f"Location: {BASE_LOCATION}", "Website: jordanchen.example.com"])
    pdf.ln(4)
    pdf.section("About Me")
    pdf.body_lines(
        [
            SUMMARY,
            "Work History: Northwind Analytics 2022-present, Harbor Systems 2018-2021.",
            "Studied at university; competencies in Python, AWS, APIs, Agile.",
        ]
    )
    pdf.output(str(out))


def build_worst_combo(out: Path) -> None:
    """05 — Image + two columns + non-standard headings + no contact (very low score)."""
    _tiny_png(AVATAR_PATH)
    pdf = AtsCvPdf()
    pdf.add_page()
    pdf.image(str(AVATAR_PATH), x=150, y=12, w=40, h=40)
    pdf.set_font("Helvetica", "B", 16)
    pdf.cell(pdf.content_width, 10, "ALEX GRAPHIC CV", new_x="LMARGIN", new_y="NEXT")
    pdf.set_font("Helvetica", "", 10)
    pdf.cell(pdf.content_width, 6, "Designer / Developer", new_x="LMARGIN", new_y="NEXT")
    pdf.ln(6)

    left_x, right_x = 16.0, 372.0
    line_h = 4.0
    y = 62.0
    pdf.set_font("Helvetica", "", 8)
    filler_left = [
        "Profile: creative technologist with portfolio of visual projects.",
        "Work: built landing pages, brand kits, and social media templates.",
    ] * 25
    filler_right = [
        "Tools: Photoshop, Illustrator, Figma, Canva, HTML/CSS animations.",
        "Notes: prefer visual layouts over plain text documents.",
    ] * 25
    for i in range(50):
        if y > 275:
            break
        pdf.set_xy(left_x, y)
        pdf.cell(
            150,
            line_h,
            filler_left[i % len(filler_left)][:55],
            new_x="RIGHT",
            new_y="TOP",
        )
        pdf.set_xy(right_x, y)
        pdf.cell(
            150,
            line_h,
            filler_right[i % len(filler_right)][:55],
            new_x="RIGHT",
            new_y="TOP",
        )
        y += line_h
    pdf.output(str(out))


BUILDERS: List[Tuple[str, str, Callable[[Path], None]]] = [
    (
        "cv_test_01_score_100_strong.pdf",
        "Strong ATS layout — expect score 100 / PASS",
        build_strong,
    ),
    (
        "cv_test_02_score_65_columns.pdf",
        "Two-column layout — expect score ~65 (B2 columns)",
        build_two_columns,
    ),
    (
        "cv_test_03_score_55_image.pdf",
        "Embedded photo — expect score ~55 (B1 + B5 images)",
        build_with_image,
    ),
    (
        "cv_test_04_score_80_no_sections.pdf",
        "No ATS headings, no email/phone — expect score ~80",
        build_minimal_no_sections,
    ),
    (
        "cv_test_05_score_15_combo.pdf",
        "Image + columns + no contact — expect score ~15",
        build_worst_combo,
    ),
]


def app_score(decision: str, failed_rules: int, failed_basic: bool) -> int:
    if decision.upper() == "PASS":
        return 100
    penalty = failed_rules * 10 + (25 if failed_basic else 0)
    return max(5, min(99, 100 - penalty))


def check_ats(path: Path) -> dict:
    boundary = "----cvtestboundary"
    data = path.read_bytes()
    body = (
        f"--{boundary}\r\n"
        f'Content-Disposition: form-data; name="file"; filename="{path.name}"\r\n'
        "Content-Type: application/pdf\r\n\r\n"
    ).encode() + data + f"\r\n--{boundary}--\r\n".encode()
    req = urllib.request.Request(
        ATS_URL,
        data=body,
        headers={"Content-Type": f"multipart/form-data; boundary={boundary}"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.loads(resp.read().decode())


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()

    ROOT.mkdir(parents=True, exist_ok=True)
    _tiny_png(AVATAR_PATH)
    print(f"Writing PDFs to {ROOT}\n")

    for filename, desc, builder in BUILDERS:
        out = ROOT / filename
        builder(out)
        print(f"  {filename}")
        print(f"    {desc} ({out.stat().st_size // 1024} KB)")

    if args.check:
        print(f"\nATS check ({ATS_URL}):\n")
        for filename, _, _ in BUILDERS:
            path = ROOT / filename
            try:
                raw = check_ats(path)
                fails = raw.get("failures") or []
                rule_ids = [f.get("rule_id", "?") for f in fails[:6]]
                decision = str(raw.get("decision", "FAIL"))
                n = int(raw.get("failed_rules_count", 0))
                basic = bool(raw.get("failed_basic"))
                score = app_score(decision, n, basic)
                ui = "PASS" if score > PASS_SCORE_THRESHOLD else "FAIL"
                print(
                    f"  {filename}\n"
                    f"    score={score} ui={ui} engine={decision} "
                    f"failed={n} basic={basic}\n"
                    f"    rules: {', '.join(rule_ids) or 'none'}\n"
                )
            except Exception as exc:
                print(f"  {filename}: skipped ({exc})\n")

    print("Done.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
