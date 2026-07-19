#!/usr/bin/env python3
"""pong — Agent mission control CLI."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

# Allow running from repo without install
_ROOT = Path(__file__).resolve().parents[2]
if str(_ROOT) not in sys.path:
    sys.path.insert(0, str(_ROOT))


def _cmd_status(args: argparse.Namespace) -> int:
    from pong.paths import state_dir
    from pong.state import (
        detect_bound_session,
        format_team_roster,
        gate_text,
        load_session_state,
        write_bind_card,
    )

    sess = detect_bound_session(args.session)
    state = load_session_state(sess)
    g, _ = gate_text(sess)
    print(f"state_dir: {state_dir()}")
    print(f"bound_session: {sess or '(none)'}")
    print(f"gate: {g}")
    if state:
        print(f"roster: {format_team_roster(state)}")
        print(f"transport_default: {state.get('transport_default')}")
        print(f"project_root: {state.get('project_root') or '(unset)'}")
        c = state.get("conductor") or {}
        print(f"conductor: {c.get('label')} ({c.get('type')}) cmd={c.get('cmd')}")
        if sess:
            p = write_bind_card(str(sess))
            print(f"bind_card: {p}")
    return 0


def _cmd_gate(args: argparse.Namespace) -> int:
    from pong.ledger import summary
    from pong.state import (
        detect_bound_session,
        format_team_roster,
        gate_text,
        load_session_state,
    )

    sess = detect_bound_session(args.session)
    state = load_session_state(sess)
    line, code = gate_text(sess)
    print(line)
    if state and workers_ok(state):
        print(f"TEAM: {format_team_roster(state)}", file=sys.stderr)
        try:
            s = summary()
            print(
                f"LEDGER: rounds={s['rounds']} accept_rate={s['accept_rate']:.0%} "
                f"reject_streak={s['reject_streak']}",
                file=sys.stderr,
            )
            if s.get("patterns"):
                print("PATTERNS: (see ~/.pong/ledger/patterns.md)", file=sys.stderr)
        except Exception:
            pass
    return code


def workers_ok(state: dict) -> bool:
    from pong.state import workers_from_state

    return bool(workers_from_state(state))


def _cmd_job_create(args: argparse.Namespace) -> int:
    from pong.jobs import create_job
    from pong.transports.dispatch import dispatch_job, parse_transport_plan

    task = args.task
    if args.file:
        task = Path(args.file).read_text(encoding="utf-8")
    if not task or not str(task).strip():
        print("error: empty task", file=sys.stderr)
        return 2
    try:
        job = create_job(
            session=args.session,
            worker_key=args.worker,
            task=task.strip(),
            require_claim=not args.no_claim,
            round_n=args.round,
        )
    except Exception as e:
        print(f"error: {e}", file=sys.stderr)
        return 2
    plan = parse_transport_plan(
        str(job["_state"].get("transport_default") or "job+paste"),
        no_paste=args.no_paste,
        headless_only=args.headless,
        paste_only=args.paste_only,
    )
    results = dispatch_job(job, job["_worker"], job["_state"], plan=plan)
    print(f"job_id={job['id']}")
    print(f"session={job['session']} worker={job['worker']} status={job['status']}")
    print(f"prompt={job.get('prompt_path')}")
    for r in results:
        flag = "ok" if r.ok else "FAIL"
        print(f"  transport[{flag}] {r.name}: {r.detail}")
    return 0 if job["status"] in ("queued", "notified", "done") else 1


def _cmd_job_list(args: argparse.Namespace) -> int:
    from pong.jobs import list_jobs
    from pong.state import detect_bound_session

    sess = detect_bound_session(args.session)
    if not sess:
        print("error: no session", file=sys.stderr)
        return 2
    for j in list_jobs(sess, status=args.status):
        print(
            f"{j.get('id')}\t{j.get('status')}\t{j.get('worker')}\t"
            f"{(j.get('task') or '')[:60].replace(chr(10), ' ')}"
        )
    return 0


def _cmd_job_show(args: argparse.Namespace) -> int:
    from pong.jobs import load_job
    from pong.state import detect_bound_session

    sess = detect_bound_session(args.session)
    if not sess:
        print("error: no session", file=sys.stderr)
        return 2
    j = load_job(sess, args.job_id)
    if not j:
        print("error: not found", file=sys.stderr)
        return 2
    print(json.dumps(j, indent=2))
    return 0


def _cmd_job_status(args: argparse.Namespace) -> int:
    from pong.jobs import set_status
    from pong.state import detect_bound_session

    sess = detect_bound_session(args.session)
    if not sess:
        print("error: no session", file=sys.stderr)
        return 2
    try:
        j = set_status(sess, args.job_id, args.status)
    except Exception as e:
        print(f"error: {e}", file=sys.stderr)
        return 2
    print(f"{j['id']} → {j['status']}")
    return 0


def _cmd_job_claim(args: argparse.Namespace) -> int:
    from pong.jobs import record_claim
    from pong.state import detect_bound_session

    sess = detect_bound_session(args.session)
    if not sess:
        print("error: no session", file=sys.stderr)
        return 2
    files = [x.strip() for x in (args.files or "").split(",") if x.strip()]
    try:
        j = record_claim(
            sess,
            args.job_id,
            files=files,
            commands=args.commands or "",
            summary=args.summary or "",
            raw=args.raw,
        )
    except Exception as e:
        print(f"error: {e}", file=sys.stderr)
        return 2
    print(f"claimed {j['id']} status={j['status']}")
    return 0


def _cmd_delegate(args: argparse.Namespace) -> int:
    """Compat: create job + transports (like old pong-delegate)."""
    ns = argparse.Namespace(
        session=args.session,
        worker=args.worker,
        task=" ".join(args.prompt) if args.prompt else "",
        file=args.criteria,
        no_claim=False,
        round=1,
        no_paste=args.no_paste,
        headless=args.headless,
        paste_only=args.paste_only,
    )
    if args.dry_run:
        from pong.state import (
            detect_bound_session,
            format_team_roster,
            load_session_state,
            resolve_worker,
        )

        sess = detect_bound_session(args.session)
        state = load_session_state(sess)
        try:
            w = resolve_worker(state, args.worker)
        except Exception as e:
            print(f"[delegate] {e}", file=sys.stderr)
            return 2
        print(f"bound_session={sess}")
        print(f"roster={format_team_roster(state)}")
        print(f"worker={w.get('id')}={w.get('label')}")
        print("DRY-RUN (no job created)")
        return 0
    if not ns.task and not ns.file:
        print("Usage: pong delegate [--worker w1] 'task…'", file=sys.stderr)
        return 2
    # If criteria file, prepend task
    if args.criteria and ns.task:
        body = Path(args.criteria).read_text(encoding="utf-8")
        ns.task = ns.task + "\n\n" + body
        ns.file = None
    return _cmd_job_create(ns)


def _cmd_ledger(args: argparse.Namespace) -> int:
    from pong import ledger

    if args.ledger_cmd == "record":
        try:
            row = ledger.record(
                task_id=args.task_id,
                round_n=args.round,
                verdict=args.verdict,
                evidence=args.evidence or "",
                session=args.session,
                worker=args.worker,
            )
        except Exception as e:
            print(f"error: {e}", file=sys.stderr)
            return 2
        print(json.dumps(row))
        return 0
    if args.ledger_cmd == "summary":
        print(json.dumps(ledger.summary(), indent=2))
        return 0
    if args.ledger_cmd == "distill":
        print(ledger.distill())
        return 0
    return 2


def _cmd_migrate(args: argparse.Namespace) -> int:
    from pong.paths import migrate_legacy_to_primary, state_dir

    p = migrate_legacy_to_primary(force=args.force)
    print(f"state_dir={p} (was preferring legacy if present)")
    print(f"active={state_dir()}")
    return 0


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="pong", description="Pong — agent mission control")
    p.add_argument("-s", "--session", default=None, help="bound team session")
    sub = p.add_subparsers(dest="cmd", required=True)

    s = sub.add_parser("status", help="bound session + roster")
    s.set_defaults(func=_cmd_status)

    g = sub.add_parser("gate", help="BRIDGE_ON / BRIDGE_OFF")
    g.set_defaults(func=_cmd_gate)

    j = sub.add_parser("job", help="job control plane")
    jsub = j.add_subparsers(dest="job_cmd", required=True)

    jc = jsub.add_parser("create", help="create job + dispatch transports")
    jc.add_argument("--worker", "-w", default=None)
    jc.add_argument("--task", "-t", default="")
    jc.add_argument("--file", "-f", default=None, help="task body from file")
    jc.add_argument("--no-paste", action="store_true", help="job file only")
    jc.add_argument("--headless", action="store_true", help="job + headless CLI")
    jc.add_argument("--paste-only", action="store_true")
    jc.add_argument("--no-claim", action="store_true")
    jc.add_argument("--round", type=int, default=1)
    jc.set_defaults(func=_cmd_job_create)

    jl = jsub.add_parser("list")
    jl.add_argument("--status", default=None)
    jl.set_defaults(func=_cmd_job_list)

    js = jsub.add_parser("show")
    js.add_argument("job_id")
    js.set_defaults(func=_cmd_job_show)

    jst = jsub.add_parser("status")
    jst.add_argument("job_id")
    jst.add_argument(
        "status",
        choices=[
            "queued",
            "notified",
            "running",
            "done",
            "failed",
            "rejected",
            "human_takeover",
            "cancelled",
        ],
    )
    jst.set_defaults(func=_cmd_job_status)

    jcl = jsub.add_parser("claim")
    jcl.add_argument("job_id")
    jcl.add_argument("--files", default="")
    jcl.add_argument("--commands", default="")
    jcl.add_argument("--summary", default="")
    jcl.add_argument("--raw", default=None)
    jcl.set_defaults(func=_cmd_job_claim)

    d = sub.add_parser("delegate", help="compat: job create + notify")
    d.add_argument("prompt", nargs="*")
    d.add_argument("--worker", "-w", default=None)
    d.add_argument("--no-wait", action="store_true", help="ignored (async by default)")
    d.add_argument("--dry-run", action="store_true")
    d.add_argument("--no-paste", action="store_true")
    d.add_argument("--headless", action="store_true")
    d.add_argument("--paste-only", action="store_true")
    d.add_argument("--criteria", default=None)
    d.set_defaults(func=_cmd_delegate)

    led = sub.add_parser("ledger")
    lsub = led.add_subparsers(dest="ledger_cmd", required=True)
    lr = lsub.add_parser("record")
    lr.add_argument("--task-id", required=True)
    lr.add_argument("--round", type=int, required=True)
    lr.add_argument("--verdict", required=True, choices=["accept", "reject", "escalate"])
    lr.add_argument("--evidence", default="")
    lr.add_argument("--worker", default=None)
    lr.set_defaults(func=_cmd_ledger)
    ls = lsub.add_parser("summary")
    ls.set_defaults(func=_cmd_ledger)
    ld = lsub.add_parser("distill")
    ld.set_defaults(func=_cmd_ledger)

    m = sub.add_parser("migrate", help="copy ~/.hermes-pong → ~/.pong")
    m.add_argument("--force", action="store_true")
    m.set_defaults(func=_cmd_migrate)

    return p


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    # propagate top-level session into subcommands
    return int(args.func(args) or 0)


if __name__ == "__main__":
    raise SystemExit(main())
