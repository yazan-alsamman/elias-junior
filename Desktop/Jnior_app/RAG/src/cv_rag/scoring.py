from cv_rag.config import settings
from cv_rag.models import RoleProfile
from cv_rag.schemas import ParsedCV, ScoreBreakdown
from cv_rag.skill_aliases import canonicalize_skills, extract_skills_from_text


def _normalize_items(items: list[str]) -> set[str]:
    return canonicalize_skills(items)


def _education_score(cv_education: str | None, preferred_education: str) -> float:
    if not cv_education:
        return 30.0
    cv_value = cv_education.strip().lower()
    preferred = preferred_education.strip().lower()

    order = {"high_school": 1, "associate": 2, "bachelor": 3, "master": 4, "phd": 5}
    cv_rank = order.get(cv_value, 0)
    pref_rank = order.get(preferred, 0)

    if cv_rank == 0 or pref_rank == 0:
        return 60.0 if cv_value == preferred else 40.0
    if cv_rank >= pref_rank:
        return 100.0
    if cv_rank + 1 == pref_rank:
        return 70.0
    return 40.0


def _projects_experience_score(cv: ParsedCV, profile: RoleProfile, required_skills: set[str]) -> float:
    project_skill_set: set[str] = set()
    for project in cv.projects:
        project_skill_set.update(_normalize_items(project.skills))

    if required_skills:
        project_overlap = len(project_skill_set & required_skills) / len(required_skills)
    else:
        project_overlap = 0.0
    project_score = project_overlap * 100

    min_years = max(profile.min_years_experience, 0.0)
    if min_years == 0:
        exp_score = 100.0
    else:
        exp_score = min((cv.years_experience / min_years) * 100, 100)

    return (0.7 * project_score) + (0.3 * exp_score)


def compute_cv_score(
    cv: ParsedCV,
    profile: RoleProfile,
    *,
    job_description: str = "",
) -> tuple[ScoreBreakdown, list[str]]:
    settings.validate()
    required_skills = _normalize_items(profile.required_skills)
    jd_skills = _normalize_items(extract_skills_from_text(job_description))
    if jd_skills:
        # Job posting skills + KB role requirements (union).
        required_skills = required_skills | jd_skills

    cv_skills = _normalize_items(cv.skills)
    missing_skills = sorted(required_skills - cv_skills)

    skills_score = (
        (len(required_skills & cv_skills) / len(required_skills)) * 100
        if required_skills
        else 0.0
    )
    projects_experience_score = _projects_experience_score(cv, profile, required_skills)
    education_score = _education_score(cv.education_level, profile.preferred_education)

    skills_component = (skills_score / 100) * settings.skills_weight * 100
    projects_component = (projects_experience_score / 100) * settings.projects_experience_weight * 100
    education_component = (education_score / 100) * settings.education_weight * 100

    final_score = round(skills_component + projects_component + education_component)
    final_score = max(1, min(100, final_score))

    return (
        ScoreBreakdown(
            skills_component=round(skills_component, 2),
            projects_experience_component=round(projects_component, 2),
            education_component=round(education_component, 2),
            final_score=final_score,
        ),
        missing_skills,
    )

