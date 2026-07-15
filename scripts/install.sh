#!/bin/bash
# Install Hermes_Pairing.app into /Applications and optionally enable login item
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Hermes_Pairing.app"
SRC_APP="$ROOT/dist/$APP_NAME"
DEST="/Applications/$APP_NAME"

if [[ ! -d "$SRC_APP" ]]; then
  bash "$ROOT/scripts/build-app.sh"
fi

rm -rf "$DEST"
cp -R "$SRC_APP" "$DEST"
xattr -cr "$DEST" 2>/dev/null || true
codesign -s - --force --deep "$DEST" 2>/dev/null || true

echo "Installed: $DEST"

if [[ "${1:-}" == "--login" ]]; then
  osascript <<EOF
tell application "System Events"
  try
    delete login item "Hermes_Pairing"
  end try
  try
    delete login item "HermesClaude"
  end try
  make login item at end with properties {path:"$DEST", hidden:false}
end tell
EOF
  echo "Login item enabled."
fi

open "$DEST"
echo "Launched Hermes_Pairing."
