import re
from datetime import datetime
from typing import Any

from cv_rag.schemas import AnalyzeCVRequest, CVProject, ParsedCV
from cv_rag.skill_aliases import (
    canonicalize_skill,
    extract_skills_from_text,
    skills_from_course_title,
)


def _as_list(value: Any) -> list[Any]:
    if value is None:
        return []
    if isinstance(value, list):
        return value
    return [value]


def _extract_skill_list(skills_value: Any) -> list[str]:
    raw: list[str] = []
    if isinstance(skills_value, list):
        raw = [str(item).strip() for item in skills_value if str(item).strip()]
    elif isinstance(skills_value, dict):
        for value in skills_value.values():
            raw.extend(_extract_skill_list(value))
    elif isinstance(skills_value, str) and skills_value.strip():
        raw = [skills_value.strip()]

    # Deduplicate by canonical id while preserving readable labels in output.
    seen: set[str] = set()
    result: list[str] = []
    for skill in raw:
        canonical = canonicalize_skill(skill)
        if canonical and canonical not in seen:
            seen.add(canonical)
            result.append(canonical)
    return result


def _extract_projects(projects_value: Any) -> list[CVProject]:
    projects: list[CVProject] = []
    for item in _as_list(projects_value):
        if not isinstance(item, dict):
            continue
        name = str(item.get("name", "")).strip() or "Untitled Project"
        description = item.get("description")
        skills = _extract_skill_list(item.get("skills"))
        if not skills:
            skills = _extract_skill_list(item.get("technologies"))
        projects.append(CVProject(name=name, description=description, skills=skills))
    return projects


def _extract_courses(value: Any) -> list[str]:
    courses: list[str] = []
    for item in _as_list(value):
        if isinstance(item, dict):
            title = item.get("title") or item.get("name")
            if title:
                courses.append(str(title).strip())
        elif isinstance(item, str) and item.strip():
            courses.append(item.strip())
    return courses


def _extract_certifications(value: Any) -> list[str]:
    certs: list[str] = []
    for item in _as_list(value):
        if isinstance(item, dict):
            name = item.get("name") or item.get("title")
            if name:
                certs.append(str(name).strip())
        elif isinstance(item, str) and item.strip():
            certs.append(item.strip())
    return certs


def _parse_years_experience(raw_years: Any, work_experience: Any) -> float:
    if raw_years is not None:
        try:
            return float(raw_years)
        except (TypeError, ValueError):
            pass

    current_year = datetime.now().year
    total = 0.0
    for item in _as_list(work_experience):
        if not isinstance(item, dict):
            continue
        duration = str(item.get("duration", ""))
        full_years = re.findall(r"(?:19|20)\d{2}", duration)
        if len(full_years) >= 2:
            start = int(full_years[0])
            end = int(full_years[-1])
            total += max(0, end - start)
        elif "present" in duration.lower():
            if full_years:
                total += max(0, current_year - int(full_years[0]))
    return round(total, 1)


def _merge_course_skills(
    skills: list[str], courses: list[str], certifications: list[str]
) -> list[str]:
    merged = list(skills)
    seen = set(skills)
    for title in courses + certifications:
        for skill in skills_from_course_title(title):
            if skill not in seen:
                seen.add(skill)
                merged.append(skill)
    return merged


def _infer_education_level(value: Any) -> str | None:
    if value and isinstance(value, str):
        normalized = value.strip().lower()
        if "phd" in normalized or "doctor" in normalized:
            return "phd"
        if "master" in normalized:
            return "master"
        if "bachelor" in normalized:
            return "bachelor"
        if "associate" in normalized:
            return "associate"
        if "high school" in normalized:
            return "high_school"
        return normalized

    for item in _as_list(value):
        if isinstance(item, dict):
            degree = str(item.get("degree", "")).lower()
            inferred = _infer_education_level(degree)
            if inferred:
                return inferred
    return None


def _enrich_cv_skills(parsed_payload: dict[str, Any]) -> None:
    """Merge skills from summary, experience bullets, and explicit lists."""
    profile = parsed_payload.get("profile") or {}
    text_parts: list[str] = [
        str(profile.get("summary", "")),
        str(parsed_payload.get("summary", "")),
    ]
    for row in _as_list(parsed_payload.get("work_experience") or parsed_payload.get("experience")):
        if isinstance(row, dict):
            text_parts.append(str(row.get("description", "")))
            text_parts.append(str(row.get("position", "")))
            text_parts.append(str(row.get("company", "")))
    blob = " ".join(text_parts)
    merged = list(
        dict.fromkeys(
            _extract_skill_list(parsed_payload.get("skills"))
            + extract_skills_from_text(blob)
        )
    )
    parsed_payload["skills"] = merged


def _job_fields(payload: dict[str, Any]) -> tuple[str, str]:
    return (
        str(payload.get("job_title") or payload.get("jobTitle") or "").strip(),
        str(payload.get("job_description") or payload.get("jobDescription") or "").strip(),
    )


def normalize_analyze_request(payload: dict[str, Any]) -> AnalyzeCVRequest:
    """
    Accept multiple input shapes and normalize into AnalyzeCVRequest.
    Supported:
    1) Native shape: {target_role, parsed_cv}
    2) Rich CV shape: {target_role, name, work_experience, skills{...}, projects...}
    """
    if "target_role" not in payload and "role" in payload:
        payload["target_role"] = payload["role"]

    target_role = payload.get("target_role")
    if not target_role:
        raise ValueError("Missing required field: target_role")

    if "parsedCv" in payload and "parsed_cv" not in payload:
        payload["parsed_cv"] = payload["parsedCv"]

    if "parsed_cv" in payload:
        parsed_payload = dict(payload["parsed_cv"])
        if "profile" in parsed_payload:
            profile = parsed_payload.get("profile") or {}
            parsed_payload.setdefault("full_name", profile.get("name"))
            top_skills = _extract_skill_list(parsed_payload.get("skills"))
            if not top_skills:
                top_skills = _extract_skill_list(profile.get("skills"))
            parsed_payload["skills"] = top_skills
            if not parsed_payload.get("work_experience") and parsed_payload.get("experience"):
                work_rows: list[dict[str, str]] = []
                for item in _as_list(parsed_payload.get("experience")):
                    if not isinstance(item, dict):
                        continue
                    work_rows.append(
                        {
                            "position": str(item.get("position", "")).strip(),
                            "company": str(item.get("company", "")).strip(),
                            "duration": str(
                                item.get("period") or item.get("duration") or ""
                            ).strip(),
                            "description": str(item.get("description", "")).strip(),
                        }
                    )
                parsed_payload["work_experience"] = work_rows
            parsed_payload["years_experience"] = _parse_years_experience(
                parsed_payload.get("years_experience"),
                parsed_payload.get("work_experience"),
            )
            parsed_payload["education_level"] = _infer_education_level(
                parsed_payload.get("education_level") or parsed_payload.get("education")
            )
        courses = _extract_courses(parsed_payload.get("courses"))
        certifications = _extract_certifications(parsed_payload.get("certifications"))
        parsed_payload["skills"] = _merge_course_skills(
            _extract_skill_list(parsed_payload.get("skills")),
            courses,
            certifications,
        )
        parsed_payload["courses"] = courses
        parsed_payload["certifications"] = certifications
        _enrich_cv_skills(parsed_payload)
        job_title, job_description = _job_fields(payload)
        return AnalyzeCVRequest(
            target_role=target_role,
            parsed_cv=ParsedCV(**parsed_payload),
            job_title=job_title,
            job_description=job_description,
        )

    courses = _extract_courses(payload.get("courses"))
    certifications = _extract_certifications(payload.get("certifications"))
    rich_payload: dict[str, Any] = {
        "full_name": payload.get("full_name") or payload.get("name"),
        "skills": _merge_course_skills(
            _extract_skill_list(payload.get("skills")), courses, certifications
        ),
        "courses": courses,
        "certifications": certifications,
        "projects": _extract_projects(payload.get("projects")),
        "years_experience": _parse_years_experience(
            payload.get("years_experience"), payload.get("work_experience")
        ),
        "education_level": _infer_education_level(
            payload.get("education_level") or payload.get("education")
        ),
        "work_experience": payload.get("work_experience"),
        "experience": payload.get("experience"),
        "profile": payload.get("profile"),
        "summary": payload.get("summary"),
    }
    _enrich_cv_skills(rich_payload)
    parsed_cv = ParsedCV(
        full_name=rich_payload.get("full_name"),
        skills=rich_payload.get("skills") or [],
        courses=courses,
        certifications=certifications,
        projects=rich_payload.get("projects") or [],
        years_experience=float(rich_payload.get("years_experience") or 0),
        education_level=rich_payload.get("education_level"),
    )
    job_title, job_description = _job_fields(payload)
    return AnalyzeCVRequest(
        target_role=str(target_role),
        parsed_cv=parsed_cv,
        job_title=job_title,
        job_description=job_description,
    )

