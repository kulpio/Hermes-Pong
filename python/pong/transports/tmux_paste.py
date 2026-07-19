"""Optional: paste + Enter into a tmux pane (fragile; secondary)."""

from __future__ import annotations

import subprocess
import time
from typing import Any

from .base import TransportResult


def _run(cmd: list[str], input_text: str | None = None) -> bool:
    try:
        r = subprocess.run(
            cmd,
            input=input_text,
            text=True,
            capture_output=True,
            timeout=30,
        )
        return r.returncode == 0
    except Exception:
        return False


def send(job: dict[str, Any], worker: dict[str, Any], state: dict[str, Any]) -> TransportResult:
    session = str(job.get("session") or state.get("session") or "")
    idx = worker.get("tmux_index")
    if idx is None:
        idx = 1
    target = f"{session}:{idx}"
    prompt = job.get("_prompt") or ""
    if not session:
        return TransportResult("tmux_paste", False, "no session")
    if not _run(["tmux", "has-session", "-t", session]):
        return TransportResult("tmux_paste", False, f"tmux session {session!r} not running")
    _run(["tmux", "select-window", "-t", target])
    _run(["tmux", "display-message", "-t", target, "⚡ Pong: submitting job…"])
    time.sleep(0.05)
    if not _run(["tmux", "load-buffer", "-"], input_text=prompt):
        # chunked fallback
        for i in range(0, len(prompt), 400):
            _run(["tmux", "send-keys", "-t", target, "-l", prompt[i : i + 400]])
            time.sleep(0.02)
    else:
        _run(["tmux", "paste-buffer", "-t", target, "-d"])
    time.sleep(0.15)
    _run(["tmux", "send-keys", "-t", target, "Enter"])
    time.sleep(0.05)
    _run(["tmux", "send-keys", "-t", target, "C-m"])
    return TransportResult(
        "tmux_paste",
        True,
        f"pasted into {target} ({len(prompt)} chars)",
        meta={"target": target},
    )
