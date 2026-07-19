"""Select and run transports for a job."""

from __future__ import annotations

from typing import Any

from ..jobs import save_job
from . import headless, job_file, tmux_paste, window_paste
from .base import TransportResult


def parse_transport_plan(
    default: str,
    *,
    no_paste: bool = False,
    headless_only: bool = False,
    paste_only: bool = False,
) -> list[str]:
    if headless_only:
        return ["job_file", "headless"]
    if paste_only:
        return ["job_file", "tmux_paste", "window_paste"]
    if no_paste:
        return ["job_file"]
    d = (default or "job+paste").lower().strip()
    if d in ("job", "job_file", "file"):
        return ["job_file"]
    if d in ("headless", "cli"):
        return ["job_file", "headless"]
    if d in ("paste", "tmux"):
        return ["job_file", "tmux_paste"]
    if d in ("window",):
        return ["job_file", "window_paste"]
    # job+paste (default): file always; try paste for human-visible TUI
    return ["job_file", "tmux_paste", "window_paste"]


def dispatch_job(
    job: dict[str, Any],
    worker: dict[str, Any],
    state: dict[str, Any],
    plan: list[str] | None = None,
) -> list[TransportResult]:
    plan = plan or parse_transport_plan(str(state.get("transport_default") or "job+paste"))
    results: list[TransportResult] = []
    used: list[str] = list(job.get("transports_used") or [])
    mode = str(worker.get("mode") or state.get("claude_mode") or "tmux")

    for name in plan:
        if name == "job_file":
            r = job_file.send(job, worker, state)
        elif name == "tmux_paste":
            if mode == "window" and "window_paste" in plan:
                continue  # prefer window when worker is window-linked
            r = tmux_paste.send(job, worker, state)
        elif name == "window_paste":
            if mode != "window" and "tmux_paste" in plan:
                # try window only if tmux not in plan or after tmux fails — handled below
                if any(x.name == "tmux_paste" and x.ok for x in results):
                    continue
            r = window_paste.send(job, worker, state)
        elif name == "headless":
            r = headless.send(job, worker, state)
        else:
            r = TransportResult(name, False, "unknown transport")
        results.append(r)
        if r.ok and name not in used:
            used.append(name)

    job["transports_used"] = used
    # Status: job_file success means queued at least; any notify success → notified
    notify_ok = any(r.ok and r.name != "job_file" for r in results)
    file_ok = any(r.ok and r.name == "job_file" for r in results)
    if file_ok and notify_ok:
        job["status"] = "notified"
    elif file_ok:
        job["status"] = "queued"
        job["error"] = "; ".join(
            f"{r.name}:{r.detail}" for r in results if not r.ok and r.name != "job_file"
        ) or None
    else:
        job["status"] = "failed"
        job["error"] = "job_file transport failed"
    save_job(job)
    return results
