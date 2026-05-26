#!/usr/bin/env python3
"""
Generate ATS-friendly test CV PDFs in the same layout as sample_cv.pdf
(plain text, standard headings, contact in body, single-column).

Usage:
  pip install fpdf2 pypdf
  python cv-s/generate_test_cvs.py

Optional — verify scores against local ATS (:8000):
  python cv-s/generate_test_cvs.py --check
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import List

from fpdf import FPDF

ROOT = Path(__file__).resolve().parent
ATS_URL = os.environ.get("ATS_URL", "http://127.0.0.1:8000/ats-format/check")
PASS_SCORE_THRESHOLD = 70


@dataclass
class CvProfile:
    filename: str
    name: str
    title: str
    email: str
    phone: str
    location: str
    linkedin: str
    github: str
    summary: str
    skills_block: List[str]
    experience: List[str]
    education: List[str]
    projects: List[str]
    page2_sections: List[tuple[str, List[str]]]


PROFILES: List[CvProfile] = [
    CvProfile(
        filename="cv_test_01_jordan_chen.pdf",
        name="JORDAN CHEN",
        title="Senior Software Engineer",
        email="jordan.chen.dev@email.com",
        phone="+1 (206) 555-0142",
        location="Seattle, WA, USA",
        linkedin="linkedin.com/in/jordanchendev",
        github="github.com/jchen-dev",
        summary=(
            "Senior engineer with 9+ years delivering scalable backends, event-driven "
            "systems, and developer platforms. Led squads of 5 engineers across fintech "
            "and SaaS. Strong in Python, Java, and AWS with a focus on reliability and "
            "clear API design."
        ),
        skills_block=[
            "Languages: Python, Java, TypeScript, SQL, Bash",
            "Frameworks: Spring Boot, FastAPI, React, gRPC",
            "Data: PostgreSQL, DynamoDB, Redis, Kafka, Spark",
            "Cloud & DevOps: AWS (EKS, Lambda, RDS), Docker, Terraform, CI/CD",
            "Practices: SRE, design reviews, incident management, mentoring",
        ],
        experience=[
            "Principal Engineer | Cascade Payments | Remote | Mar 2021 - Present",
            "- Rebuilt settlement service handling $2B+ annual volume; 99.99% uptime over 18 months.",
            "- Introduced contract testing and canary deploys; cut production regressions by 45%.",
            "- Coached two teams on domain-driven design and observability standards.",
            "Senior Software Engineer | Blue Harbor Tech | Seattle, WA | Jun 2017 - Feb 2021",
            "- Owned checkout and billing microservices (Java/Spring) on AWS ECS.",
            "- Migrated legacy MySQL workloads to Aurora with zero-downtime cutover playbook.",
            "Software Engineer | Lattice Apps | Portland, OR | Aug 2014 - May 2017",
            "- Built REST APIs and admin tooling in Python/Django for B2B customers.",
            "- Shipped feature flags and A/B experiment framework used by product team.",
        ],
        education=[
            "M.S. Software Engineering | Carnegie Mellon University | Pittsburgh, PA | 2012 - 2014",
            "B.S. Computer Science | Oregon State University | Corvallis, OR | 2008 - 2012",
        ],
        projects=[
            "- Maintainer of ledger-diff, an open-source reconciliation CLI (600+ GitHub stars).",
            "- Internal tech talk series lead on API versioning and backward compatibility.",
        ],
        page2_sections=[
            (
                "Languages",
                [
                    "English (native), Mandarin (fluent), Japanese (basic)",
                ],
            ),
            (
                "Volunteering",
                [
                    "Weekend coding workshops for career switchers (2020-2024).",
                ],
            ),
        ],
    ),
    CvProfile(
        filename="cv_test_02_priya_sharma.pdf",
        name="PRIYA SHARMA",
        title="Data Engineer",
        email="priya.sharma.data@email.com",
        phone="+1 (312) 555-0287",
        location="Chicago, IL, USA",
        linkedin="linkedin.com/in/priyasharmadata",
        github="github.com/psharma-etl",
        summary=(
            "Data engineer specializing in reliable pipelines, warehouse modeling, and "
            "analytics platforms. 7 years building batch and streaming jobs that power "
            "executive dashboards and ML feature stores."
        ),
        skills_block=[
            "Languages: Python, SQL, Scala, Bash",
            "Stack: Airflow, dbt, Spark, Flink, BigQuery, Snowflake",
            "Orchestration: Airflow, Dagster, GitHub Actions",
            "Cloud: GCP (BigQuery, Dataflow), AWS (S3, Glue, Redshift)",
            "Practices: data quality checks, lineage, cost optimization, documentation",
        ],
        experience=[
            "Senior Data Engineer | Meridian Retail Group | Chicago, IL | Jan 2020 - Present",
            "- Designed lakehouse ingestion for 120+ retail feeds; SLA 99.5% on daily loads.",
            "- Built dbt marts consumed by 40 analysts; reduced ad-hoc request backlog by 30%.",
            "Data Engineer | Insight Metrics Co. | Remote | Sep 2016 - Dec 2019",
            "- Migrated on-prem Hadoop jobs to GCP Dataflow and BigQuery.",
            "- Implemented Great Expectations suites for critical revenue tables.",
            "Analytics Engineer | Nova Health Analytics | Boston, MA | Jul 2014 - Aug 2016",
            "- Created patient cohort dashboards in Looker with HIPAA-aware row policies.",
        ],
        education=[
            "B.S. Statistics & Computer Science | University of Illinois | Urbana, IL | 2010 - 2014",
        ],
        projects=[
            "- Published blog series on incremental dbt models and late-arriving facts.",
            "- Speaker at local Data Council meetup: Practical data contracts.",
        ],
        page2_sections=[
            (
                "Certifications",
                [
                    "Google Professional Data Engineer (2022)",
                    "dbt Analytics Engineering Certification (2021)",
                ],
            ),
        ],
    ),
    CvProfile(
        filename="cv_test_03_marcus_webb.pdf",
        name="MARCUS WEBB",
        title="Product Manager",
        email="marcus.webb.pm@email.com",
        phone="+1 (646) 555-0319",
        location="New York, NY, USA",
        linkedin="linkedin.com/in/marcuswebbpm",
        github="github.com/mwebb-pm",
        summary=(
            "Product manager with 8 years shipping B2B SaaS features from discovery to launch. "
            "Partners with engineering and design to deliver measurable outcomes in growth, "
            "retention, and platform reliability."
        ),
        skills_block=[
            "Methods: discovery interviews, PRD writing, roadmap planning, OKRs",
            "Tools: Jira, Figma, Amplitude, Mixpanel, SQL (basic)",
            "Domains: integrations, billing, onboarding, admin consoles",
            "Stakeholders: engineering leads, sales, customer success, legal",
        ],
        experience=[
            "Senior Product Manager | Relay Cloud | New York, NY | Apr 2020 - Present",
            "- Launched partner API program contributing 18% net-new ARR in year one.",
            "- Reduced enterprise onboarding time from 21 days to 9 days via guided setup.",
            "Product Manager | Signal Desk | Remote | Jan 2017 - Mar 2020",
            "- Owned mobile notifications product; improved D7 retention by 12%.",
            "- Ran beta program with 25 design partners for workflow automation module.",
            "Associate Product Manager | Urban Stack | Brooklyn, NY | Jun 2014 - Dec 2016",
            "- Supported marketplace search and ranking experiments with A/B analysis.",
        ],
        education=[
            "M.B.A. | NYU Stern School of Business | New York, NY | 2012 - 2014",
            "B.A. Economics | Boston University | Boston, MA | 2008 - 2012",
        ],
        projects=[
            "- Side project: PM playbook Notion template (2k+ downloads).",
        ],
        page2_sections=[
            (
                "Languages",
                ["English (native), French (professional working proficiency)"],
            ),
        ],
    ),
    CvProfile(
        filename="cv_test_04_elena_kowalski.pdf",
        name="ELENA KOWALSKI",
        title="DevOps / Platform Engineer",
        email="elena.kowalski.ops@email.com",
        phone="+1 (512) 555-0471",
        location="Austin, TX, USA",
        linkedin="linkedin.com/in/elenakowalskiops",
        github="github.com/ekowalski-infra",
        summary=(
            "Platform engineer focused on Kubernetes, GitOps, and secure CI/CD. 6+ years "
            "automating infrastructure for product teams and improving deployment safety."
        ),
        skills_block=[
            "Languages: Python, Go, Bash, HCL",
            "Platforms: Kubernetes, Helm, Argo CD, Terraform, Ansible",
            "Observability: Prometheus, Grafana, Loki, PagerDuty",
            "Security: OIDC, Vault, image scanning, policy-as-code",
        ],
        experience=[
            "Staff Platform Engineer | Orbit Security | Austin, TX | Feb 2021 - Present",
            "- Standardized golden paths for 12 services; deploy frequency up 3x with fewer incidents.",
            "- Built self-service preview environments per pull request on EKS.",
            "DevOps Engineer | ClearPath Logistics | Dallas, TX | May 2018 - Jan 2021",
            "- Migrated Jenkins pipelines to GitHub Actions with reusable workflow library.",
            "- Cut cloud spend 22% via rightsizing and S3 lifecycle policies.",
            "Systems Administrator | Lone Star Hosting | Austin, TX | Aug 2015 - Apr 2018",
            "- Managed Linux fleet and monitoring for 200+ customer VMs.",
        ],
        education=[
            "B.S. Information Technology | Texas State University | San Marcos, TX | 2011 - 2015",
        ],
        projects=[
            "- Contributor to internal Helm chart library adopted org-wide.",
        ],
        page2_sections=[
            (
                "Certifications",
                [
                    "CKA: Certified Kubernetes Administrator (2023)",
                    "HashiCorp Terraform Associate (2022)",
                ],
            ),
        ],
    ),
    CvProfile(
        filename="cv_test_05_sam_okonkwo.pdf",
        name="SAM OKONKWO",
        title="Junior Software Developer",
        email="sam.okonkwo.junior@email.com",
        phone="+1 (404) 555-0523",
        location="Atlanta, GA, USA",
        linkedin="linkedin.com/in/samokonkwodev",
        github="github.com/sokonkwo",
        summary=(
            "Recent computer science graduate eager to contribute to full-stack teams. "
            "Internship experience building web apps, writing tests, and collaborating in Agile sprints."
        ),
        skills_block=[
            "Languages: JavaScript, TypeScript, Python, Java, HTML/CSS",
            "Frameworks: React, Node.js, Express, Spring Boot",
            "Tools: Git, GitHub, PostgreSQL, Docker basics, Jest",
            "Coursework: algorithms, databases, software engineering capstone",
        ],
        experience=[
            "Software Engineering Intern | Brightline Health Tech | Atlanta, GA | May 2025 - Aug 2025",
            "- Implemented patient intake form validation and unit tests (React + TypeScript).",
            "- Fixed 15+ bugs in scheduling API integration during sprint demos.",
            "Teaching Assistant | Georgia Tech | Atlanta, GA | Jan 2025 - May 2025",
            "- Led weekly labs for Introduction to Object-Oriented Programming (120 students).",
            "Freelance Web Developer | Self-employed | Remote | Jun 2024 - Dec 2024",
            "- Built portfolio sites for two local nonprofits using React and Netlify.",
        ],
        education=[
            "B.S. Computer Science | Georgia Institute of Technology | Atlanta, GA | 2021 - 2025",
            "GPA: 3.6/4.0 | Dean's List (3 semesters)",
        ],
        projects=[
            "- Capstone: campus event finder PWA with Firebase auth and map search.",
            "- Hackathon winner: accessibility audit browser extension (2024).",
        ],
        page2_sections=[
            (
                "Languages",
                ["English (native), Igbo (conversational)"],
            ),
        ],
    ),
]


class AtsCvPdf(FPDF):
    """Plain-text CV PDF matching sample_cv.pdf style."""

    def __init__(self) -> None:
        super().__init__()
        self.set_auto_page_break(auto=True, margin=18)
        self.set_margins(left=18, top=18, right=18)

    @property
    def content_width(self) -> float:
        return self.w - self.l_margin - self.r_margin

    def section(self, title: str) -> None:
        self.set_x(self.l_margin)
        self.ln(4)
        self.set_font("Helvetica", "B", 11)
        self.multi_cell(self.content_width, 6, title)
        self.set_font("Helvetica", "", 9)
        self.set_x(self.l_margin)
        self.multi_cell(self.content_width, 5, "-" * 72)

    def body_lines(self, lines: List[str], line_height: float = 5.5) -> None:
        self.set_font("Helvetica", "", 10)
        for line in lines:
            self.set_x(self.l_margin)
            self.multi_cell(self.content_width, line_height, line)


def build_pdf(profile: CvProfile, out_path: Path) -> None:
    pdf = AtsCvPdf()
    pdf.add_page()

    w = pdf.content_width
    pdf.set_font("Helvetica", "B", 14)
    pdf.cell(w, 8, profile.name, new_x="LMARGIN", new_y="NEXT")
    pdf.set_font("Helvetica", "", 11)
    pdf.cell(w, 6, profile.title, new_x="LMARGIN", new_y="NEXT")
    pdf.ln(2)

    contact = [
        f"Email: {profile.email}",
        f"Phone: {profile.phone}",
        f"Location: {profile.location}",
        f"LinkedIn: {profile.linkedin}",
        f"GitHub: {profile.github}",
    ]
    pdf.body_lines(contact)
    pdf.ln(2)

    pdf.section("Professional Summary")
    pdf.body_lines([profile.summary])

    pdf.section("Technical Skills")
    pdf.body_lines(profile.skills_block)

    pdf.section("Experience")
    pdf.body_lines(profile.experience)

    pdf.section("Education")
    pdf.body_lines(profile.education)

    if profile.projects:
        pdf.section("Projects & Open Source")
        pdf.body_lines(profile.projects)

    if profile.page2_sections:
        pdf.add_page()
        for title, lines in profile.page2_sections:
            pdf.section(title)
            pdf.body_lines(lines)

    pdf.output(str(out_path))


def app_score(decision: str, failed_rules: int, failed_basic: bool) -> int:
    if decision.upper() == "PASS":
        return 100
    penalty = failed_rules * 10 + (25 if failed_basic else 0)
    return max(5, min(99, 100 - penalty))


def check_ats(path: Path) -> dict:
    boundary = "----cvtestboundary"
    with path.open("rb") as f:
        data = f.read()
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
    parser.add_argument(
        "--check",
        action="store_true",
        help="POST each PDF to local ATS (:8000) and print scores",
    )
    args = parser.parse_args()

    ROOT.mkdir(parents=True, exist_ok=True)
    print(f"Writing PDFs to {ROOT}")

    for profile in PROFILES:
        out = ROOT / profile.filename
        build_pdf(profile, out)
        size_kb = out.stat().st_size // 1024
        print(f"  OK  {profile.filename} ({size_kb} KB)")

    if args.check:
        print(f"\nChecking ATS at {ATS_URL} ...")
        for profile in PROFILES:
            path = ROOT / profile.filename
            try:
                raw = check_ats(path)
                decision = str(raw.get("decision", "FAIL"))
                failed = int(raw.get("failed_rules_count", 0))
                basic = bool(raw.get("failed_basic"))
                score = app_score(decision, failed, basic)
                ui = "PASS" if score > PASS_SCORE_THRESHOLD else "FAIL"
                print(
                    f"  {profile.filename}: engine={decision} score={score} ui={ui} "
                    f"rules_failed={failed}"
                )
            except Exception as exc:
                print(f"  {profile.filename}: ATS check skipped ({exc})")

    print("\nDone. Upload any file from cv-s/ in the app with ATS on :8000 running.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
