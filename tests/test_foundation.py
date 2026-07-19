#!/usr/bin/env python3
"""Foundation tests: transitions, snapshot contract, isolation, events."""

from __future__ import annotations

import json
import os
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "python"))


class FoundationTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        os.environ["PONG_HOME"] = self.tmp.name
        os.environ["PONG_SESSION"] = "pong-team"
        from pong.paths import ensure_layout, pairs_path, active_path
        from pong.jsonutil import write_json

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
        }
        other = {
            "schema_version": 2,
            "conductor": {"id": "c1", "type": "hermes", "label": "Hermes", "cmd": "hermes chat"},
            "workers": [
                {
                    "id": "w1",
                    "type": "claude",
                    "label": "Other Claude",
                    "cmd": "claude",
                    "tmux_index": 1,
                }
            ],
            "transport_default": "job",
        }
        write_json(pairs_path(), {"pong-team": pair, "pong-team-1": other})
        active = dict(pair)
        active["session"] = "pong-team"
        write_json(active_path(), active)

    def tearDown(self) -> None:
        self.tmp.cleanup()
        os.environ.pop("PONG_HOME", None)
        os.environ.pop("PONG_SESSION", None)

    def test_illegal_transition(self) -> None:
        from pong.jobs import create_job, set_status
        from pong.schema import SchemaError
        from pong.transports.dispatch import dispatch_job, parse_transport_plan

        job = create_job(session="pong-team", worker_key="w1", task="x")
        dispatch_job(job, job["_worker"], job["_state"], plan=parse_transport_plan("job"))
        set_status("pong-team", job["id"], "done")
        with self.assertRaises(SchemaError):
            # done is terminal — cannot go back to notified
            set_status("pong-team", job["id"], "notified")

    def test_happy_path_status_claim(self) -> None:
        from pong.jobs import create_job, set_status, record_claim, load_job
        from pong.transports.dispatch import dispatch_job, parse_transport_plan

        job = create_job(session="pong-team", worker_key="w1", task="Add button")
        dispatch_job(job, job["_worker"], job["_state"], plan=parse_transport_plan("job"))
        j = load_job("pong-team", job["id"])
        self.assertEqual(j["status"], "queued")
        set_status("pong-team", job["id"], "notified")
        set_status("pong-team", job["id"], "running")
        record_claim(
            "pong-team",
            job["id"],
            files=["a.swift"],
            summary="done",
        )
        j = load_job("pong-team", job["id"])
        self.assertEqual(j["status"], "done")
        self.assertEqual(j["claim"]["files"], ["a.swift"])

    def test_worker_isolation(self) -> None:
        from pong.state import load_session_state, resolve_worker, WorkerResolveError

        st = load_session_state("pong-team")
        w = resolve_worker(st, "w1")
        self.assertEqual(w["label"], "Claude")
        # same id on other team must not be used when bound to pong-team
        self.assertEqual(w["label"], "Claude")
        st2 = load_session_state("pong-team-1")
        w2 = resolve_worker(st2, "w1")
        self.assertEqual(w2["label"], "Other Claude")

    def test_snapshot_contract(self) -> None:
        from pong.jobs import create_job
        from pong.snapshot import build_snapshot, write_snapshot
        from pong.schema import CONTRACT_VERSION, SCHEMA_VERSION
        from pong.transports.dispatch import dispatch_job, parse_transport_plan

        job = create_job(session="pong-team", worker_key="w2", task="Write tests")
        dispatch_job(job, job["_worker"], job["_state"], plan=parse_transport_plan("job"))
        snap = build_snapshot()
        self.assertEqual(snap["contract_version"], CONTRACT_VERSION)
        self.assertEqual(snap["schema_version"], SCHEMA_VERSION)
        self.assertIn("teams", snap)
        self.assertIn("ledger", snap)
        self.assertIn("events_tail", snap)
        self.assertTrue(any(t["session"] == "pong-team" for t in snap["teams"]))
        team = next(t for t in snap["teams"] if t["session"] == "pong-team")
        self.assertEqual(team["conductor"]["type"], "grok")
        self.assertEqual(len(team["workers"]), 2)
        self.assertIn("open", team["jobs"])
        self.assertGreaterEqual(team["jobs"]["counts"]["open"], 1)
        path = write_snapshot(snap)
        data = json.loads(path.read_text())
        self.assertEqual(data["contract_version"], CONTRACT_VERSION)

    def test_events_emitted(self) -> None:
        from pong.jobs import create_job
        from pong import events
        from pong.transports.dispatch import dispatch_job, parse_transport_plan

        job = create_job(session="pong-team", worker_key="w1", task="evt")
        dispatch_job(job, job["_worker"], job["_state"], plan=parse_transport_plan("job"))
        rows = events.tail(20, session="pong-team")
        types = {r["type"] for r in rows}
        self.assertIn("job.created", types)
        self.assertIn("job.dispatch", types)

    def test_atomic_write_readable(self) -> None:
        from pong.jsonutil import write_json, read_json
        from pong.paths import state_dir

        p = state_dir() / "atomic-test.json"
        write_json(p, {"ok": True, "n": 1})
        self.assertEqual(read_json(p)["ok"], True)

    def test_human_takeover_transition(self) -> None:
        from pong.jobs import create_job, set_status, load_job
        from pong.transports.dispatch import dispatch_job, parse_transport_plan

        job = create_job(session="pong-team", worker_key="w1", task="ht")
        dispatch_job(job, job["_worker"], job["_state"], plan=parse_transport_plan("job"))
        set_status("pong-team", job["id"], "notified")
        set_status("pong-team", job["id"], "human_takeover")
        j = load_job("pong-team", job["id"])
        self.assertTrue(j["human_takeover"])
        set_status("pong-team", job["id"], "running")
        set_status("pong-team", job["id"], "done")


if __name__ == "__main__":
    unittest.main()
