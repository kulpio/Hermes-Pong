# Hermes_Pairing

macOS app that pairs **Hermes** and **Claude Code** in Terminal via tmux.

Two terminals. One bridge.

## What it does

| Action | Meaning |
|--------|---------|
| **New pair** | Create a fresh Hermes + Claude setup |
| **Link two open Terminals** | Wire two Terminal windows you already opened |
| **Rejoin pair** | Bring an existing pair to the front (creates nothing) |

## Requirements

- macOS 12+
- Python 3.9+ with a local venv (see setup)
- [tmux](https://github.com/tmux/tmux) (`brew install tmux`)
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI (`claude`)
- Hermes (your agent workflow)

## Setup (dev)

```bash
cd Hermes_Pairing   # or this repo root
python3 -m venv venv
venv/bin/pip install -U pip
venv/bin/pip install 'pyobjc-core==10.3.2' 'pyobjc-framework-Cocoa==10.3.2'

bash scripts/build-app.sh
bash scripts/install.sh --login   # optional: open at login
```

App installs to `/Applications/Hermes_Pairing.app`.

## Day to day

```bash
# After code changes: rebuild, reinstall, commit + push
bash scripts/push-update.sh "Describe the change"
```

Or step by step:

```bash
bash scripts/build-app.sh
bash scripts/install.sh
git add -A && git commit -m "…" && git push
```

## Signing

- **Ad-hoc** (free, local): `codesign -s - --force --deep dist/Hermes_Pairing.app`  
  (already run by `build-app.sh`)
- **Developer ID** (ship to others): Apple Developer Program + `codesign` with your cert + notarize

## Permissions

Grant when macOS asks:

- **Accessibility** — pick Terminal windows
- **Automation** — control Terminal / tmux

## Bridge (optional)

`~/bin/claude-delegate.py` can send a task into the Claude tmux pane. The main app focuses on pairing windows.

## License

MIT (or your choice once published).
