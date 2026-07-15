#!/bin/bash
# Build Hermes_Pairing.app
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Hermes_Pairing"
APP="$ROOT/dist/${APP_NAME}.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
RES="$CONTENTS/Resources"
VENV="$ROOT/venv"
SRC="$ROOT/src/hermes_pairing.py"

if [[ ! -x "$VENV/bin/python" ]]; then
  echo "Missing venv. Run: python3 -m venv venv && venv/bin/pip install 'pyobjc-core==10.3.2' 'pyobjc-framework-Cocoa==10.3.2'"
  exit 1
fi

rm -rf "$APP"
mkdir -p "$MACOS" "$RES"

cp "$ROOT/resources/menubar-template.png" "$RES/" 2>/dev/null || true
cp "$ROOT/resources/menubar-template@2x.png" "$RES/" 2>/dev/null || true
cp "$ROOT/resources/AppIcon.icns" "$RES/" 2>/dev/null || true
cp "$ROOT/resources/AppIcon-1024.png" "$RES/" 2>/dev/null || true
cp "$ROOT/resources/pair-illustration.png" "$RES/" 2>/dev/null || true
cp "$SRC" "$RES/hermes_pairing.py"

cat > "$MACOS/$APP_NAME" <<'LAUNCH'
#!/bin/bash
DIR="$(cd "$(dirname "$0")" && pwd)"
CONTENTS="$(cd "$DIR/.." && pwd)"
MARKER="$CONTENTS/Resources/project_root"
VENV_PY=""
if [[ -f "$MARKER" ]]; then
  PROJECT_ROOT="$(cat "$MARKER")"
  VENV_PY="$PROJECT_ROOT/venv/bin/python"
fi
if [[ -z "$VENV_PY" || ! -x "$VENV_PY" ]]; then
  # fallback: sibling of dist when running from repo
  APP_ROOT="$(cd "$CONTENTS/../.." && pwd)"
  VENV_PY="$APP_ROOT/venv/bin/python"
fi
export PYTHONUNBUFFERED=1
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
exec -a Hermes_Pairing "$VENV_PY" "$CONTENTS/Resources/hermes_pairing.py"
LAUNCH
chmod +x "$MACOS/$APP_NAME"

echo "$ROOT" > "$RES/project_root"

cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>
  <string>Hermes_Pairing</string>
  <key>CFBundleDisplayName</key>
  <string>Hermes_Pairing</string>
  <key>CFBundleIdentifier</key>
  <string>com.kulpio.hermes-pairing</string>
  <key>CFBundleVersion</key>
  <string>1.0.0</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0.0</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleExecutable</key>
  <string>Hermes_Pairing</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>LSMinimumSystemVersion</key>
  <string>12.0</string>
  <key>LSUIElement</key>
  <false/>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSAppleEventsUsageDescription</key>
  <string>Hermes_Pairing controls Terminal to pair Hermes and Claude Code sessions.</string>
</dict>
</plist>
PLIST

echo -n "APPL????" > "$CONTENTS/PkgInfo"

# Ad-hoc sign (free). Replace with Developer ID when available.
codesign -s - --force --deep "$APP" 2>/dev/null || true

echo "Built: $APP"
