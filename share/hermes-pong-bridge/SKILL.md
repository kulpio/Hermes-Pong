---
name: hermes-pong-bridge
description: >
  Load when Hermes is the Pong conductor (Hermes-first users). Same job control
  plane as Grok; route all implementation through pong jobs while BRIDGE_ON.
---

# Hermes as Pong conductor

You are the **orchestrator**, not the implementer, while a Pong team is active.

```bash
pong gate
pong job create --worker w1 --task '…'
pong ledger record --task-id <id> --round 1 --verdict accept --evidence '…'
```

Legacy aliases still work: `pong-gate.py`, `pong-delegate.py`, `claude-delegate.py`.

## Hard rules

- BRIDGE_ON → no product coding with local tools; jobs only.
- Bound to one session (`PONG_SESSION` / `HERMES_PONG_SESSION` / tmux).
- Verdict loop always on; three rejects → escalate to the human.
- Photon / cron remain Hermes strengths — use `hermes send` for delivery, not as the coding prompt box when Grok is conductor.

Full protocol: skill **pong-bridge**.
