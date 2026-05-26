"""
HTTP API for CV → JSON parsing (same pipeline as ``main.py``).

There is no automatic "API URL" for a local LoRA; you run this process and
call it over HTTP.

Run (from project root, venv active):

  pip install fastapi uvicorn python-multipart pypdf
  set CV_API_MODEL_ID=C:\\Users\\asus\\models\\Llama-3.2-3B-Instruct-HF
  set CV_API_ADAPTER_PATH=out\\lora-resume-archive
  set CV_API_LOAD_IN_4BIT=1
  uvicorn cv_api_server:app --host 0.0.0.0 --port 8000

Then:
  GET  http://127.0.0.1:8000/health
  POST http://127.0.0.1:8000/parse        JSON: {"resume_text": "..."}
  POST http://127.0.0.1:8000/parse/pdf    multipart form field ``file`` (PDF)

OpenAPI docs: http://127.0.0.1:8000/docs
"""

from __future__ import annotations

import os
import tempfile
import threading
from contextlib import asynccontextmanager
from pathlib import Path
from typing import Any

from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

# Project root = directory containing this file
ROOT = Path(__file__).resolve().parent
os.chdir(ROOT)


def _load_env_file(path: Path) -> None:
    """Load KEY=VALUE pairs from a .env file into os.environ (only if not already set).

    Keeps things dependency-free so we don't force python-dotenv on every install.
    """
    if not path.is_file():
        return
    for raw in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, val = line.partition("=")
        key = key.strip()
        val = val.strip().strip('"').strip("'")
        if key and key not in os.environ:
            os.environ[key] = val


_load_env_file(ROOT / ".env")

_PLACEHOLDER_TOKENS = frozenset(
    {
        "",
        "hf_replace_me",
        "your_huggingface_token",
        "hf_xxx",
        "hf_xxxxx",
    }
)


def _require_valid_hf_token(token: str | bool, model_id: str) -> str:
    """Return a usable token string or raise with setup instructions."""
    is_local = str(model_id).strip().lower().startswith(
        ("c:", "d:", "e:", "/", ".", "~")
    )
    if is_local:
        return token if isinstance(token, str) else ""

    if token is True or not isinstance(token, str):
        raise RuntimeError(
            "\n[cv-parser] No Hugging Face token configured.\n"
            "  Edit cv-parser/.env and set HF_TOKEN=hf_... (Read token).\n"
            "  Also request access:\n"
            "  https://huggingface.co/meta-llama/Llama-3.2-3B-Instruct\n"
        )

    cleaned = token.strip()
    lowered = cleaned.lower()
    if cleaned in _PLACEHOLDER_TOKENS or "replace" in lowered or lowered.startswith("your_"):
        raise RuntimeError(
            "\n[cv-parser] HF_TOKEN in cv-parser/.env is still a placeholder.\n"
            "  1) Open cv-parser/.env in a text editor\n"
            "  2) Replace hf_replace_me with your real token from:\n"
            "     https://huggingface.co/settings/tokens  (Read scope)\n"
            "  3) Request model access (one-time):\n"
            "     https://huggingface.co/meta-llama/Llama-3.2-3B-Instruct\n"
            "  4) Re-run start-local-dev.cmd\n"
            "\n  ATS (:8000) and Node (:3003) work without the CV parser.\n"
        )

    if not cleaned.startswith("hf_") or len(cleaned) < 20:
        raise RuntimeError(
            "\n[cv-parser] HF_TOKEN looks invalid (must start with hf_ and be ~37+ chars).\n"
            "  Update cv-parser/.env with a Read token from huggingface.co/settings/tokens\n"
        )

    return cleaned


class ParseTextBody(BaseModel):
    resume_text: str = Field(..., min_length=1, description="Plain-text CV content")
    max_new_tokens: int = Field(512, ge=64, le=4096)
    heuristic_fill: bool = True
    refine: bool = False


_state: dict[str, Any] = {}
_lock = threading.Lock()


def _env_bool(name: str, default: bool = False) -> bool:
    v = os.environ.get(name, "").strip().lower()
    if v in ("1", "true", "yes", "on"):
        return True
    if v in ("0", "false", "no", "off"):
        return False
    return default


@asynccontextmanager
async def lifespan(app: FastAPI):
    import torch

    import main as cv_main

    model_id = os.environ.get(
        "CV_API_MODEL_ID",
        os.environ.get("CV_FINETUNE_MODEL_ID", cv_main.DEFAULT_MODEL_ID),
    )
    adapter = os.environ.get("CV_API_ADAPTER_PATH", "").strip()
    adapter_path = Path(adapter).expanduser() if adapter else None
    load_4bit = _env_bool("CV_API_LOAD_IN_4BIT", False)

    hf_tok = _require_valid_hf_token(cv_main.huggingface_hub_token(), model_id)

    try:
        tokenizer = cv_main.load_pretrained_tokenizer(model_id, hf_tok)
    except OSError as err:
        msg = str(err)
        if "gated repo" in msg.lower() or "401" in msg:
            raise RuntimeError(
                "\n[cv-parser] Hugging Face rejected access to the Llama model.\n"
                "  Your token is set, but either:\n"
                "    • the token is wrong/expired, OR\n"
                "    • you have not been approved for meta-llama/Llama-3.2-3B-Instruct yet\n"
                "  Fix:\n"
                "    1) https://huggingface.co/meta-llama/Llama-3.2-3B-Instruct → Request access\n"
                "    2) Create a new Read token → paste into cv-parser/.env as HF_TOKEN=...\n"
                "    3) Re-run start-local-dev.cmd\n"
                "\n  ATS (:8000) and Node (:3003) still work without the parser.\n"
            ) from err
        raise
    cv_main.ensure_llama3_chat_template(tokenizer)
    gen_eos = cv_main.generation_eos_token_ids(tokenizer)

    use_4bit = bool(load_4bit and torch.cuda.is_available())
    model = cv_main.load_generative_model(model_id, hf_tok, load_in_4bit=use_4bit)
    if adapter_path is not None:
        if not adapter_path.is_dir():
            raise RuntimeError(f"CV_API_ADAPTER_PATH not a directory: {adapter_path}")
        from peft import PeftModel

        model = PeftModel.from_pretrained(model, str(adapter_path))
    model.eval()

    seed_s = os.environ.get("CV_API_SEED", "42")
    if seed_s.strip() != "" and int(seed_s) >= 0:
        cv_main.set_inference_seeds(int(seed_s))

    _state["model"] = model
    _state["tokenizer"] = tokenizer
    _state["gen_eos"] = gen_eos
    _state["model_id"] = model_id
    _state["adapter_path"] = str(adapter_path) if adapter_path else None
    _state["load_in_4bit"] = use_4bit

    yield
    _state.clear()


app = FastAPI(title="CV parse API", lifespan=lifespan)

# Allow Flutter web (Chrome) and other origins to call this API directly.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
def health() -> dict[str, Any]:
    return {
        "status": "ok",
        "model_id": _state.get("model_id"),
        "adapter_path": _state.get("adapter_path"),
        "load_in_4bit": _state.get("load_in_4bit"),
    }


@app.post("/parse")
def parse_text(body: ParseTextBody) -> dict[str, Any]:
    import main as cv_main

    if not _state.get("model"):
        raise HTTPException(503, "Model not loaded")

    with _lock:
        flat = cv_main.infer_flat_schema_dict(
            _state["model"],
            _state["tokenizer"],
            _state["gen_eos"],
            body.resume_text,
            max_new_tokens=body.max_new_tokens,
            heuristic_fill=body.heuristic_fill,
            llm_refine=body.refine,
            max_resume_chars=int(os.environ.get("CV_API_MAX_RESUME_CHARS", "0") or 0),
            canonicalize_headers=True,
            quiet=True,
        )
    return cv_main.make_portfolio_json(flat)


@app.post("/parse/pdf")
async def parse_pdf(
    file: UploadFile = File(..., description="CV as PDF"),
    max_new_tokens: int = 512,
    heuristic_fill: bool = True,
    refine: bool = False,
) -> dict[str, Any]:
    import main as cv_main

    if not _state.get("model"):
        raise HTTPException(503, "Model not loaded")
    if not file.filename or not file.filename.lower().endswith(".pdf"):
        raise HTTPException(400, "Upload a .pdf file")

    raw = await file.read()
    if not raw.strip():
        raise HTTPException(400, "Empty file")

    with tempfile.NamedTemporaryFile(suffix=".pdf", delete=False) as tmp:
        tmp.write(raw)
        tmp_path = Path(tmp.name)

    try:
        text = cv_main.read_resume_text(text_path=None, pdf_path=tmp_path)
    finally:
        tmp_path.unlink(missing_ok=True)

    if not text.strip():
        raise HTTPException(400, "No text extracted from PDF")

    with _lock:
        flat = cv_main.infer_flat_schema_dict(
            _state["model"],
            _state["tokenizer"],
            _state["gen_eos"],
            text,
            max_new_tokens=max(64, min(max_new_tokens, 4096)),
            heuristic_fill=heuristic_fill,
            llm_refine=refine,
            max_resume_chars=int(os.environ.get("CV_API_MAX_RESUME_CHARS", "0") or 0),
            canonicalize_headers=True,
            quiet=True,
        )
    return cv_main.make_portfolio_json(flat)
