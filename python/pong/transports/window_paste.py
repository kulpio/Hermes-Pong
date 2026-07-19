"""Optional: clipboard paste into a Terminal.app window id."""

from __future__ import annotations

import subprocess
import time
from typing import Any

from .base import TransportResult


def send(job: dict[str, Any], worker: dict[str, Any], state: dict[str, Any]) -> TransportResult:
    wid = str(worker.get("window_id") or state.get("claude_window_id") or "")
    if not wid.isdigit():
        return TransportResult("window_paste", False, "no numeric window_id")
    prompt = job.get("_prompt") or ""
    p = subprocess.run(["pbcopy"], input=prompt, text=True)
    if p.returncode != 0:
        return TransportResult("window_paste", False, "pbcopy failed")
    focus = f'''
tell application "Terminal"
  try
    set w to window id {wid}
    set index of w to 1
    set selected of w to true
    activate
  end try
end tell
'''
    subprocess.run(["osascript"], input=focus, text=True, capture_output=True)
    time.sleep(0.35)
    script = '''
tell application "System Events"
  tell process "Terminal"
    set frontmost to true
    delay 0.15
    keystroke "v" using {command down}
    delay 0.25
    key code 36
    delay 0.05
    key code 36
  end tell
end tell
'''
    r = subprocess.run(["osascript"], input=script, text=True, capture_output=True)
    ok = r.returncode == 0
    return TransportResult(
        "window_paste",
        ok,
        f"window {wid} paste rc={r.returncode}",
        meta={"window_id": wid},
    )
