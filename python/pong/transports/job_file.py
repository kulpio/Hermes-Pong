"""Always-on transport: job already on disk."""

from __future__ import annotations

from typing import Any

from .base import TransportResult


def send(job: dict[str, Any], worker: dict[str, Any], state: dict[str, Any]) -> TransportResult:
    path = job.get("id")
    return TransportResult(
        name="job_file",
        ok=True,
        detail=f"job recorded ({path})",
        meta={"prompt_path": job.get("prompt_path")},
    )
