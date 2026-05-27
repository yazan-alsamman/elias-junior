import json
import re
from functools import lru_cache
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
KB_SPECIALIZATIONS_DIR = ROOT / "kb" / "specializations"
ALIASES_FILE = ROOT / "kb" / "skill_aliases.json"


def _to_key(skill: str) -> str:
    text = skill.strip().lower()
    text = re.sub(r"[./\-]+", " ", text)
    text = re.sub(r"[^a-z0-9\s_+#]", "", text)
    text = re.sub(r"\s+", " ", text).strip()
    return text.replace(" ", "_")


@lru_cache(maxsize=1)
def _alias_payload() -> dict:
    if not ALIASES_FILE.exists():
        return {"skill_aliases": {}, "course_title_to_skills": {}}
    return json.loads(ALIASES_FILE.read_text(encoding="utf-8"))


@lru_cache(maxsize=1)
def _skill_alias_map() -> dict[str, str]:
    return _alias_payload().get("skill_aliases", {})


@lru_cache(maxsize=1)
def _course_title_to_skills() -> dict[str, list[str]]:
    return _alias_payload().get("course_title_to_skills", {})


@lru_cache(maxsize=1)
def canonical_skills() -> frozenset[str]:
    skills: set[str] = set()
    for path in KB_SPECIALIZATIONS_DIR.glob("*.json"):
        data = json.loads(path.read_text(encoding="utf-8"))
        for key in ("required_skills", "nice_to_have_skills"):
            skills.update(data.get(key, []))
        for course in data.get("recommended_courses", []):
            skills.update(course.get("skills_covered", []))
        for project in data.get("recommended_projects", []):
            skills.update(project.get("skills_covered", []))
    return frozenset(skills)


def canonicalize_skill(skill: str) -> str:
    if not skill or not skill.strip():
        return ""
    key = _to_key(skill)
    if not key:
        return ""

    alias_map = _skill_alias_map()
    if key in alias_map:
        return alias_map[key]

    known = canonical_skills()
    if key in known:
        return key

    compact = key.replace("_", "")
    if compact in alias_map:
        return alias_map[compact]

    for canonical in known:
        if canonical.replace("_", "") == compact:
            return canonical

    return key


def canonicalize_skills(skills: list[str]) -> set[str]:
    return {canonical for skill in skills if (canonical := canonicalize_skill(skill))}


def extract_skills_from_text(text: str) -> list[str]:
    """Find KB skills mentioned in free text (CV summary, experience, job description)."""
    if not text or not text.strip():
        return []
    known = canonical_skills()
    found: list[str] = []

    for segment in re.split(r"[,;\n/|]+", text):
        token = segment.strip()
        if not token or len(token) > 40:
            continue
        canonical = canonicalize_skill(token)
        if canonical and canonical in known:
            found.append(canonical)

    lower = text.lower()
    for skill in known:
        phrase = skill.replace("_", " ")
        if len(phrase) >= 2 and phrase in lower:
            found.append(skill)

    seen: set[str] = set()
    ordered: list[str] = []
    for item in found:
        if item not in seen:
            seen.add(item)
            ordered.append(item)
    return ordered


def skills_from_course_title(title: str) -> list[str]:
    """Map a CV course/certification title to KB skills when recognized."""
    key = _to_key(title)
    if not key:
        return []
    mapped = _course_title_to_skills().get(key, [])
    return [canonicalize_skill(skill) for skill in mapped if canonicalize_skill(skill)]
