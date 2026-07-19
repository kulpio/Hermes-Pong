# UI contract (foundation)

The macOS panel (and any future dashboard) is a **read-mostly consumer** of the control plane.  
It must not invent job state, invent worker rosters, or use tmux paste as truth.

## Principle

```text
Control plane (Python / disk)  ──authoritative──►  UI (Swift)
UI  ──user intent only──►  CLI / control plane APIs
```

**Do:** call `pong snapshot`, read `~/.pong/…`, invoke `pong job …`  
**Don’t:** parse tmux panes for job status; write ad-hoc JSON shapes; dual-write pairs without schema_version

## Primary read API

### `pong snapshot [--session S] [--json]`

Returns one JSON document (also written to `~/.pong/snapshot.json` when session is active/all):

```json
{
  "schema_version": 2,
  "contract_version": 1,
  "generated_at": 0.0,
  "state_dir": "/Users/…/.pong",
  "bound_session": "pong-team",
  "bridge": "BRIDGE_ON session=… conductor=grok …",
  "bridge_on": true,
  "teams": [ { /* TeamSnapshot */ } ],
  "ledger": { "rounds": 0, "accept_rate": 0, "reject_streak": 0, "last": null },
  "events_tail": [ /* last N events */ ]
}
```

### TeamSnapshot

```json
{
  "session": "pong-team",
  "display_name": "Auth",
  "stowed": false,
  "schema_version": 2,
  "conductor": { "id": "c1", "type": "grok", "label": "Grok Build", "cmd": "grok", "window_id": "…", "mode": "tmux" },
  "workers": [ { "id": "w1", "type": "claude", "label": "…", "status_hint": "idle|busy|unknown", "open_jobs": 1 } ],
  "project_root": "",
  "team_brief": "",
  "transport_default": "job+paste",
  "jobs": {
    "open": [ /* JobSummary */ ],
    "recent": [ /* JobSummary, last 10 terminal states */ ]
  },
  "artifacts": {
    "last_sent": "…/sessions/pong-team/last-sent.txt",
    "last_reply": "…/sessions/pong-team/last-reply.txt",
    "bind_card": "…/binds/pong-team.md"
  }
}
```

### JobSummary

```json
{
  "id": "job_…",
  "worker": "w1",
  "status": "queued|notified|running|done|failed|rejected|human_takeover|cancelled",
  "round": 1,
  "task_preview": "first 80 chars…",
  "updated_at": 0.0,
  "human_takeover": false
}
```

Full job body remains at `jobs/<session>/<id>.json` — UI opens that on demand via `pong job show`.

## Write APIs the UI may invoke

| User action | Control-plane call |
|-------------|-------------------|
| Refresh panel | `pong snapshot` (or read `snapshot.json` if fresh) |
| Create task from panel (later) | `pong job create --worker w1 --task '…'` |
| Mark human takeover | `pong job status <id> human_takeover` |
| Cancel job | `pong job status <id> cancelled` |
| Record verdict | `pong ledger record …` |
| Save pair fields | write `pairs.json` **only** via validated `pong pair upsert` (or Swift using same schema_version 2 shape) |

Swift may still write `pairs.json` for window ids / stow / colors (layout concerns).  
It must preserve `schema_version`, `conductor`, `workers`, `transport_default`.

## Events log

Append-only: `~/.pong/events.jsonl`

```json
{"ts": 0, "type": "job.created", "session": "pong-team", "job_id": "…", "worker": "w1"}
{"ts": 0, "type": "job.status", "session": "…", "job_id": "…", "status": "notified", "from": "queued"}
{"ts": 0, "type": "job.claim", "session": "…", "job_id": "…"}
{"ts": 0, "type": "verdict", "session": "…", "task_id": "…", "verdict": "accept"}
{"ts": 0, "type": "pair.saved", "session": "…"}
```

UI can tail last N via snapshot `events_tail` — no need to parse jsonl itself.

## Status machine (jobs)

```text
queued ──► notified ──► running ──► done
                │            │         │
                │            ├──► failed
                │            ├──► rejected
                │            └──► human_takeover
                └──► cancelled
done|failed|rejected|cancelled|human_takeover are terminal
  (except rejected → new job round; not a transition on same id)
```

Illegal transitions raise; UI should not force them.

## Polling guidance

- Panel refresh: every 1–2s while visible, or on focus — call `pong snapshot --json`
- Do not run heavy headless transports from the UI event loop
- File watchers optional later; snapshot is enough for alpha

## Compatibility

| Env / path | Support |
|------------|---------|
| `PONG_SESSION` | Preferred bind |
| `HERMES_PONG_SESSION` | Legacy bind |
| `~/.hermes-pong` | Read until migrate |
| `hermes-pair*` sessions | Load + normalize to v2 |
| `pong-team*` | Preferred session names |

## Contract versioning

- `schema_version` — pair/job document shape (currently **2**)
- `contract_version` — snapshot envelope for UI (currently **1**)

Bump `contract_version` when snapshot fields break; keep generators backward-compatible for one minor when possible.

## Proven before UI features

Foundation is “proven” when:

1. Unit tests cover status transitions, snapshot shape, multi-team isolation  
2. `pong snapshot` works with zero teams, one team, legacy hermes-pair  
3. Job create → status → claim → ledger leaves consistent events  
4. UI only renders snapshot + pair layout fields (window ids, colors)

Mission dashboard UI should land **after** these hold — not before.
