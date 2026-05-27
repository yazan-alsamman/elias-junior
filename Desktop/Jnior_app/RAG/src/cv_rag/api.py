from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from cv_rag.config import chroma_is_ready, require_openai_api_key, require_rag_ready, settings
from cv_rag.ingestion import ingest_kb
from cv_rag.kb_repository import KBRepository
from cv_rag.normalization import normalize_analyze_request
from cv_rag.recommendations import generate_recommendations
from cv_rag.retrieval import retrieve_evidence
from cv_rag.scoring import compute_cv_score
from cv_rag.schemas import AnalyzeCVResponse, IngestResponse, RoleOption

app = FastAPI(title="CV Enhancement RAG API", version="0.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


def _role_label(specialization: str, role: str) -> str:
    spec = specialization.replace("_", " ").title()
    role_name = role.replace("_", " ").title()
    return f"{role_name} ({spec})"


@app.get("/roles", response_model=list[RoleOption])
def list_roles() -> list[RoleOption]:
    repository = KBRepository(settings.kb_directory)
    options: list[RoleOption] = []
    for profile in repository.load_all_profiles():
        options.append(
            RoleOption(
                role=profile.role,
                specialization=profile.specialization,
                label=_role_label(profile.specialization, profile.role),
            )
        )
    return sorted(options, key=lambda item: item.label.lower())


@app.get("/health")
def health() -> dict:
    openai_configured = bool(settings.openai_api_key.strip())
    chroma_ready = chroma_is_ready()
    ready = openai_configured and chroma_ready
    return {
        "status": "ok" if ready else "degraded",
        "embedding_model": settings.embedding_model,
        "similarity_threshold": settings.rag_score_threshold,
        "openai_configured": openai_configured,
        "chroma_ready": chroma_ready,
    }


@app.post("/ingest-kb", response_model=IngestResponse)
def ingest_kb_endpoint() -> IngestResponse:
    try:
        require_openai_api_key()
    except ValueError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc

    try:
        count = ingest_kb(
            kb_directory=settings.kb_directory,
            persist_directory=settings.chroma_persist_directory,
        )
    except Exception as exc:  # pragma: no cover
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    return IngestResponse(
        ingested_documents=count,
        persist_directory=settings.chroma_persist_directory,
    )


@app.post("/analyze-cv", response_model=AnalyzeCVResponse)
def analyze_cv(payload: dict) -> AnalyzeCVResponse:
    try:
        request = normalize_analyze_request(payload)
    except Exception as exc:
        raise HTTPException(status_code=422, detail=f"Invalid request payload: {exc}") from exc

    try:
        require_rag_ready()
    except ValueError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc

    repository = KBRepository(settings.kb_directory)
    try:
        profile = repository.load_role_profile_by_role(role=request.target_role)
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc

    score_breakdown, missing_skills = compute_cv_score(request.parsed_cv, profile)
    recommended_courses, recommended_projects = generate_recommendations(profile, missing_skills)

    query = (
        f"Requirements for {request.target_role} in {profile.specialization}. "
        f"Candidate skills: {', '.join(request.parsed_cv.skills)}"
    )
    try:
        evidence = retrieve_evidence(
            query=query,
            specialization=profile.specialization,
            role=profile.role,
        )
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Retrieval failed: {exc}") from exc

    return AnalyzeCVResponse(
        specialization=profile.specialization,
        target_role=profile.role,
        score_breakdown=score_breakdown,
        missing_skills=missing_skills,
        recommended_courses=recommended_courses,
        recommended_projects=recommended_projects,
        retrieved_evidence=evidence,
    )
