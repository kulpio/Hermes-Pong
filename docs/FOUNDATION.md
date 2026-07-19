# Foundation readiness

The UI builds **only** after this checklist is green.

## Prove it

```bash
cd /path/to/Agent-Pong
python3 -m unittest tests.test_jobs_state tests.test_foundation -v
bash scripts/setup.sh   # refresh ~/.pong/lib
pong check              # OK foundation ready for UI consumers
pong snapshot | head    # contract_version: 1
```

## Layers (bottom → top)

| Layer | Status | Module / doc |
|-------|--------|----------------|
| Paths + atomic JSON | ✅ | `paths.py`, `jsonutil.py` |
| Schema + transitions | ✅ | `schema.py` |
| Pair bind + workers | ✅ | `state.py` |
| Jobs + claims | ✅ | `jobs.py` |
| Transports | ✅ | `transports/*` (file authoritative) |
| Events | ✅ | `events.py` → `events.jsonl` |
| Ledger | ✅ | `ledger.py` |
| Snapshot (UI API) | ✅ | `snapshot.py`, `pong snapshot` |
| UI contract | ✅ | `docs/UI-CONTRACT.md` |
| Unit tests | ✅ | 11 tests |
| Mission dashboard UI | ⏳ next | Swift reads snapshot only |
| Fancy plugins | ⏳ later | after dashboard |

## Rule

> If a panel feature needs data that is not in `pong snapshot` or pair layout fields (window ids, colors), **extend the snapshot** and tests first — don’t scrape tmux.
