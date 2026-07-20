#!/bin/bash
# Install CyberPong — control plane CLIs + optional macOS app
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "→ Checking prerequisites…"
command -v tmux >/dev/null || { echo "Installing tmux…"; brew install tmux; }
command -v python3 >/dev/null || { echo "Need python3"; exit 1; }

echo "→ Installing control-plane package to ~/.pong/lib …"
mkdir -p "$HOME/bin" "$HOME/.pong/lib"
rm -rf "$HOME/.pong/lib/pong"
cp -R "$ROOT/python/pong" "$HOME/.pong/lib/pong"

echo "→ Installing CLIs to ~/bin …"
cat > "$HOME/bin/pong" <<'EOF'
#!/usr/bin/env bash
export PYTHONPATH="${HOME}/.pong/lib${PYTHONPATH:+:$PYTHONPATH}"
exec python3 -m pong.cli.main "$@"
EOF
chmod 755 "$HOME/bin/pong"

for pair in "pong-gate.py:gate" "pong-delegate.py:delegate" "claude-delegate.py:delegate" "pong-ledger.py:ledger"; do
  name="${pair%%:*}"
  sub="${pair##*:}"
  cat > "$HOME/bin/$name" <<EOF
#!/usr/bin/env bash
export PYTHONPATH="\${HOME}/.pong/lib\${PYTHONPATH:+:\$PYTHONPATH}"
exec python3 -m pong.cli.main $sub "\$@"
EOF
  chmod 755 "$HOME/bin/$name"
done

# hermes_pong.py status / session / write-bind (compat)
cp "$ROOT/scripts/hermes_pong.py" "$HOME/bin/hermes_pong.py"
# Ensure it finds the package when run from ~/bin
cat > "$HOME/bin/hermes_pong.py" <<'EOF'
#!/usr/bin/env python3
import sys
from pathlib import Path
sys.path.insert(0, str(Path.home() / ".pong" / "lib"))
from pong.state import (
    detect_bound_session, format_team_roster, gate_text,
    load_session_state, write_bind_card,
)
from pong.paths import state_dir
import argparse
ap = argparse.ArgumentParser()
ap.add_argument("cmd", choices=("status", "session", "write-bind"))
ap.add_argument("--session", "-s", default=None)
args = ap.parse_args()
sess = detect_bound_session(args.session)
if args.cmd == "session":
    print(sess or ""); raise SystemExit(0 if sess else 1)
if args.cmd == "write-bind":
    if not sess:
        print("no session", file=sys.stderr); raise SystemExit(2)
    print(write_bind_card(sess)); raise SystemExit(0)
st = load_session_state(sess)
g, _ = gate_text(sess)
print(f"state_dir={state_dir()}")
print(f"bound_session={sess or ''}")
print(f"gate={g}")
if st:
    print(f"roster={format_team_roster(st)}")
EOF
chmod 755 "$HOME/bin/hermes_pong.py"

echo "→ Migrate legacy state if needed…"
"$HOME/bin/pong" migrate 2>/dev/null || true

if command -v swiftc >/dev/null 2>&1; then
  echo "→ Building macOS app…"
  if bash "$ROOT/scripts/build-app.sh"; then
    if [[ -f "$ROOT/scripts/install.sh" ]]; then
      # install.sh may still reference HermesPong.app — copy Pong.app if present
      if [[ -d "$ROOT/dist/Pong.app" ]]; then
        rm -rf "/Applications/Pong.app"
        cp -R "$ROOT/dist/Pong.app" "/Applications/Pong.app"
        echo "→ Installed /Applications/Pong.app"
      fi
    fi
  else
    echo "  (app build failed — CLIs still installed)"
  fi
else
  echo "→ Skipping app build (no swiftc)"
fi

if [[ "${1:-}" == "--with-skills" || "${INSTALL_SKILLS:-}" == "1" ]]; then
  bash "$ROOT/scripts/install-skills.sh" all
fi

echo ""
echo "Done — Pong 2.0.0-alpha"
echo "  pong status | pong gate | pong job create --worker w1 --task '…'"
echo "  State: ~/.pong   Docs: docs/ARCHITECTURE.md"
echo "  Repo:  https://github.com/kulpio/hermes-pong"
