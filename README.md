# Pong (Agent-Pong)

**Local agent mission control.** Multi-CLI teams, conductor-agnostic orchestration, human-in-the-loop terminals, and a **job control plane**.

> Private foundation rework of [Hermes-Pong](https://github.com/kulpio/Hermes-Pong).  
> Public Hermes-Pong stays as-is; this repo is the v2 architecture.

| | |
|--|--|
| **Recommended conductor** | **Grok Build** |
| **Also supported** | Hermes Agent, Claude Code, custom CLI |
| **Workers** | Claude, Grok, Codex, Kimi, OpenCode, custom |
| **Handoff truth** | `~/.pong/jobs/<session>/<job_id>.json` |
| **TUI paste** | Optional (`job+paste`) — not required for progress |

## Why this exists

Single-agent TUIs (Claude Code, Grok Build, Hermes) each own one session.  
**Pong** owns the **team**: layout, isolation, jobs, claims, verdicts, and the ability for a human to jump into any window.

## Architecture (short)

```text
YOU ──type mission──►  CONDUCTOR (Grok / Hermes / …)
                            │
                            │  pong job create  (file always)
                            │  + optional paste / headless
                            ▼
                       WORKERS (real TUIs — intervene anytime)
                            │
                            ▼
                       claim + acceptance + ledger
```

Full design: [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)

## Install

```bash
git clone git@github.com:kulpio/Agent-Pong.git   # private
cd Agent-Pong
bash scripts/setup.sh --with-skills
```

CLIs land in `~/bin` (`pong`, `pong-gate.py`, `pong-delegate.py`, …).  
App (if built): `/Applications/Pong.app`

Migrate old Hermes Pong state:

```bash
pong migrate
```

## Quick CLI

```bash
pong status
pong gate                          # BRIDGE_ON / OFF
pong job create --worker w1 --task 'Implement login. Tests must pass.'
pong job create --worker w1 --task '…' --no-paste    # robust: file only
pong job list
pong job show job_…
pong ledger record --task-id T1 --round 1 --verdict accept --evidence 'npm test ok'
```

Compat aliases: `pong-delegate.py`, `claude-delegate.py`, `pong-gate.py`.

## New team (app)

1. **New pair / New team**
2. Pick **conductor** (Grok recommended; Hermes if you don’t want Grok)
3. Staff **workers** (Claude, Team, …)
4. Type missions in the **conductor** terminal
5. Intervene in any **worker** terminal anytime

Env on team panes: `PONG_SESSION` (+ legacy `HERMES_PONG_SESSION`).

## Skills

```bash
bash scripts/install-skills.sh          # Grok + Hermes
bash scripts/install-skills.sh grok
bash scripts/install-skills.sh hermes
```

| Skill | Role |
|-------|------|
| `pong-bridge` | Generic conductor protocol |
| `grok-pong-bridge` | Grok as conductor |
| `hermes-pong-bridge` | Hermes as conductor |

## State

Primary: `~/.pong/`  
Legacy read: `~/.hermes-pong/`

## Version

**2.0.0-alpha** — control plane + conductor picker + job transports.  
Mission dashboard UI and further app polish continue on this foundation.

## License / privacy

Local-only teams, jobs, and ledger. No vendor API keys stored by Pong.
