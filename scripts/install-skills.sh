#!/usr/bin/env bash
# Install conductor skills for Grok Build and/or Hermes Agent.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

install_hermes() {
  local dest="${HOME}/.hermes/skills/workflow"
  mkdir -p "$dest"
  for skill in pong-bridge hermes-pong-bridge; do
    rm -rf "${dest}/${skill}"
    cp -R "${ROOT}/share/${skill}" "${dest}/${skill}"
    echo "→ Hermes skill: ${dest}/${skill}"
  done
}

install_grok() {
  # Grok discovers ~/.grok/skills and project .grok/skills
  local dest="${HOME}/.grok/skills"
  mkdir -p "$dest"
  for skill in pong-bridge grok-pong-bridge; do
    rm -rf "${dest}/${skill}"
    cp -R "${ROOT}/share/${skill}" "${dest}/${skill}"
    echo "→ Grok skill: ${dest}/${skill}"
  done
}

case "${1:-all}" in
  hermes) install_hermes ;;
  grok) install_grok ;;
  all)
    install_hermes
    install_grok
    ;;
  *)
    echo "Usage: $0 [all|grok|hermes]"
    exit 2
    ;;
esac

echo "Done. Restart Grok / Hermes sessions to pick up skills."
