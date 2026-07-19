#!/usr/bin/env python3
"""Unit tests for pong control plane (no tmux required)."""

from __future__ import annotations

import json
import os
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "python"))


class PongCoreTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        os.environ["PONG_HOME"] = self.tmp.name
        # fresh import side effects
        from pong.paths import ensure_layout
        from pong.jsonutil import write_json
        from pong.paths import pairs_path, active_path

        ensure_layout()
        pair = {
            "schema_version": 2,
            "conductor": {
                "id": "c1",
                "type": "grok",
                "label": "Grok Build",
                "cmd": "grok",
                "mode": "tmux",
                "tmux_index": 0,
            },
            "workers": [
                {
                    "id": "w1",
                    "type": "claude",
                    "label": "Claude",
                    "cmd": "claude",
                    "mode": "tmux",
                    "tmux_index": 1,
                    "done_marker": "##CLAUDE_DONE##",
                },
                {
                    "id": "w2",
                    "type": "codex",
                    "label": "Codex",
                    "cmd": "codex",
                    "mode": "tmux",
                    "tmux_index": 2,
                },
            ],
            "transport_default": "job",
            "project_root": "/tmp/proj",
            "team_brief": "Ship auth",
            "autonomy_level": "full",
        }
        write_json(pairs_path(), {"pong-team": pair})
        active = dict(pair)
        active["session"] = "pong-team"
        write_json(active_path(), active)
        os.environ["PONG_SESSION"] = "pong-team"

    def tearDown(self) -> None:
        self.tmp.cleanup()
        os.environ.pop("PONG_HOME", None)
        os.environ.pop("PONG_SESSION", None)

    def test_normalize_legacy_hermes(self) -> None:
        from pong.state import normalize_pair_state

        legacy = {
            "hermes_window_id": "1",
            "claude_window_id": "2",
            "worker_type": "claude",
            "worker_label": "Claude Code",
            "worker_cmd": "claude",
            "claude_mode": "window",
        }
        s = normalize_pair_state(legacy)
        self.assertEqual(s["conductor"]["type"], "hermes")
        self.assertEqual(s["workers"][0]["id"], "w1")

    def test_resolve_worker(self) -> None:
        from pong.state import load_session_state, resolve_worker, WorkerResolveError

        st = load_session_state("pong-team")
        w = resolve_worker(st, "w2")
        self.assertEqual(w["type"], "codex")
        with self.assertRaises(WorkerResolveError):
            resolve_worker(st, "nope")

    def test_create_job_file_only(self) -> None:
        from pong.jobs import create_job, load_job
        from pong.transports.dispatch import dispatch_job, parse_transport_plan

        job = create_job(
            session="pong-team",
            worker_key="w1",
            task="Add login button",
        )
        self.assertTrue(job["id"].startswith("job_"))
        plan = parse_transport_plan("job", no_paste=True)
        results = dispatch_job(job, job["_worker"], job["_state"], plan=plan)
        self.assertTrue(any(r.name == "job_file" and r.ok for r in results))
        reloaded = load_job("pong-team", job["id"])
        self.assertEqual(reloaded["status"], "queued")
        self.assertIn("auth", (reloaded.get("team_brief") or "").lower() or "Ship auth")

    def test_gate_on(self) -> None:
        from pong.state import gate_text

        line, code = gate_text("pong-team")
        self.assertEqual(code, 0)
        self.assertIn("BRIDGE_ON", line)
        self.assertIn("conductor=grok", line)


if __name__ == "__main__":
    unittest.main()
