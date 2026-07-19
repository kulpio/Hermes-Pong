"""Job control plane — source of truth for handoffs."""

from __future__ import annotations

import time
import uuid
from pathlib import Path
from typing import Any

from .jsonutil import read_json, write_json
from .paths import ensure_layout, jobs_dir
from .state import (
    format_permissions_block,
    format_team_context,
    load_session_state,
    resolve_worker,
    session_artifact,
    workers_from_state,
)

STATUSES = (
    "queued",
    "notified",
    "running",
    "done",
    "failed",
    "rejected",
    "human_takeover",
    "cancelled",
)


def new_job_id() -> str:
    ts = time.strftime("%Y%m%d_%H%M%S")
    return f"job_{ts}_{uuid.uuid4().hex[:6]}"


def job_path(session: str, job_id: str) -> Path:
    return jobs_dir(session) / f"{job_id}.json"


def load_job(session: str, job_id: str) -> dict[str, Any]:
    return read_json(job_path(session, job_id))


def save_job(job: dict[str, Any]) -> Path:
    sess = str(job["session"])
    jid = str(job["id"])
    ensure_layout(sess)
    job["updated_at"] = time.time()
    path = job_path(sess, jid)
    write_json(path, job)
    # pointer for panel / conductor convenience
    write_json(jobs_dir(sess) / "latest.json", {"id": jid, "path": str(path)})
    return path


def list_jobs(session: str, *, status: str | None = None) -> list[dict[str, Any]]:
    d = jobs_dir(session)
    if not d.exists():
        return []
    out: list[dict[str, Any]] = []
    for p in sorted(d.glob("job_*.json"), reverse=True):
        j = read_json(p)
        if not j:
            continue
        if status and j.get("status") != status:
            continue
        out.append(j)
    return out


def build_task_prompt(job: dict[str, Any], state: dict[str, Any]) -> str:
    """Full text a worker would see (TUI paste or headless)."""
    parts: list[str] = []
    ctx = format_team_context(state)
    if ctx:
        parts.append(ctx.rstrip())
    perms = format_permissions_block(state)
    if perms:
        parts.append(perms.rstrip())
    parts.append(f"## JOB `{job['id']}`")
    parts.append(f"- worker: {job.get('worker')}")
    parts.append(f"- round: {job.get('round', 1)}")
    if job.get("project_root"):
        parts.append(f"- project_root: {job['project_root']}")
    parts.append("")
    parts.append(str(job.get("task") or "").rstrip())
    parts.append("")
    acc = job.get("acceptance") or []
    if acc:
        parts.append("## Acceptance")
        for i, a in enumerate(acc, 1):
            if isinstance(a, dict):
                parts.append(f"{i}. `{a.get('cmd')}` (expect exit {a.get('expect_exit', 0)})")
            else:
                parts.append(f"{i}. {a}")
        parts.append("")
    marker = job.get("done_marker") or "##WORKER_DONE##"
    if job.get("require_claim", True):
        parts.append(
            "When completely done, print exactly "
            f"{marker} on its own line, then a CLAIM block:\n"
            "```\nCLAIM:\nfiles: <comma-separated paths>\n"
            "commands: <what you ran>\n"
            "summary: <one short paragraph>\n```"
        )
    else:
        parts.append(
            f"When completely done, print exactly {marker} on its own line, "
            "then a short summary."
        )
    parts.append("")
    parts.append(
        f"Job file: {job_path(str(job['session']), str(job['id']))}\n"
        "Prefer updating the job claim via `pong job claim` if available; "
        "CLAIM text is the fallback."
    )
    return "\n".join(parts) + "\n"


def create_job(
    *,
    session: str | None,
    worker_key: str | None,
    task: str,
    acceptance: list[Any] | None = None,
    require_claim: bool = True,
    round_n: int = 1,
    extra: dict[str, Any] | None = None,
) -> dict[str, Any]:
    state = load_session_state(session)
    sess = state.get("session") or session
    if not sess:
        raise ValueError("no bound session — start a team or pass --session")
    worker = resolve_worker(state, worker_key)
    jid = new_job_id()
    now = time.time()
    job: dict[str, Any] = {
        "id": jid,
        "session": sess,
        "worker": worker.get("id"),
        "worker_type": worker.get("type"),
        "worker_label": worker.get("label"),
        "status": "queued",
        "task": task,
        "project_root": state.get("project_root") or "",
        "team_brief": state.get("team_brief") or "",
        "acceptance": acceptance or [],
        "done_marker": worker.get("done_marker") or "##WORKER_DONE##",
        "require_claim": require_claim,
        "human_takeover": False,
        "round": round_n,
        "created_at": now,
        "updated_at": now,
        "claim": None,
        "error": None,
        "transports_used": [],
        "prompt_path": None,
    }
    if extra:
        job.update(extra)
    prompt = build_task_prompt(job, state)
    ensure_layout(str(sess))
    prompt_path = session_artifact(state, f"{jid}.prompt.txt")
    prompt_path.write_text(prompt, encoding="utf-8")
    job["prompt_path"] = str(prompt_path)
    # last-sent mirror
    sent = session_artifact(state, "last-sent.txt")
    sent.write_text(prompt, encoding="utf-8")
    from .paths import state_dir

    (state_dir() / "last-sent.txt").write_text(prompt, encoding="utf-8")
    save_job(job)
    job["_prompt"] = prompt
    job["_state"] = state
    job["_worker"] = worker
    return job


def set_status(session: str, job_id: str, status: str, **fields: Any) -> dict[str, Any]:
    if status not in STATUSES:
        raise ValueError(f"invalid status {status!r}; want one of {STATUSES}")
    job = load_job(session, job_id)
    if not job:
        raise FileNotFoundError(job_id)
    job["status"] = status
    for k, v in fields.items():
        job[k] = v
    save_job(job)
    return job


def record_claim(
    session: str,
    job_id: str,
    *,
    files: list[str] | None = None,
    commands: str | None = None,
    summary: str | None = None,
    raw: str | None = None,
) -> dict[str, Any]:
    job = load_job(session, job_id)
    if not job:
        raise FileNotFoundError(job_id)
    claim = {
        "files": files or [],
        "commands": commands or "",
        "summary": summary or "",
        "raw": raw or "",
        "at": time.time(),
    }
    job["claim"] = claim
    job["status"] = "done"
    save_job(job)
    # reply artifact
    state = load_session_state(session)
    text = raw or summary or json_fallback(claim)
    reply = session_artifact(state, "last-reply.txt")
    reply.write_text(text + "\n", encoding="utf-8")
    # legacy name
    session_artifact(state, "last-claude.txt").write_text(text + "\n", encoding="utf-8")
    from .paths import state_dir

    (state_dir() / "last-claude.txt").write_text(text + "\n", encoding="utf-8")
    (state_dir() / "last-reply.txt").write_text(text + "\n", encoding="utf-8")
    return job


def json_fallback(claim: dict[str, Any]) -> str:
    import json

    return json.dumps(claim, indent=2)


def pending_for_worker(session: str, worker_id: str) -> list[dict[str, Any]]:
    return [
        j
        for j in list_jobs(session)
        if j.get("worker") == worker_id
        and j.get("status") in ("queued", "notified")
        and not j.get("human_takeover")
    ]
