from typing import List, Optional

from pydantic import BaseModel, Field


class CVProject(BaseModel):
    name: str
    description: Optional[str] = None
    skills: List[str] = Field(default_factory=list)


class ParsedCV(BaseModel):
    full_name: Optional[str] = None
    skills: List[str] = Field(default_factory=list)
    courses: List[str] = Field(default_factory=list)
    certifications: List[str] = Field(default_factory=list)
    projects: List[CVProject] = Field(default_factory=list)
    years_experience: float = 0.0
    education_level: Optional[str] = None


class AnalyzeCVRequest(BaseModel):
    target_role: str = Field(..., description="e.g., backend_engineer")
    parsed_cv: ParsedCV
    job_title: str = ""
    job_description: str = ""


class RetrievedChunk(BaseModel):
    topic: str
    source: str
    score: float
    content: str


class ScoreBreakdown(BaseModel):
    skills_component: float
    projects_experience_component: float
    education_component: float
    final_score: int


class AnalyzeCVResponse(BaseModel):
    specialization: str
    target_role: str
    score_breakdown: ScoreBreakdown
    missing_skills: List[str]
    recommended_courses: List[str]
    recommended_projects: List[str]
    retrieved_evidence: List[RetrievedChunk]


class IngestResponse(BaseModel):
    ingested_documents: int
    persist_directory: str


class RoleOption(BaseModel):
    role: str
    specialization: str
    label: str

