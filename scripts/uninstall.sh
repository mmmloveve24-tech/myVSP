#!/usr/bin/env bash
# Tear down 3X-UI. Prompts before removing data and firewall rules.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." &>/dev/null && pwd)"
# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

require_root

log "Stopping containers"
( cd "$REPO_ROOT" && docker compose down ) || warn "compose down failed"

if [[ -d "$REPO_ROOT/amneziawg" ]]; then
  ( cd "$REPO_ROOT/amneziawg" && docker compose down 2>/dev/null ) || true
fi

read -r -p "Remove panel database (db/) and certs (cert/)? [y/N] " ans
if [[ "$ans" =~ ^[Yy]$ ]]; then
  rm -rf "$REPO_ROOT/db" "$REPO_ROOT/cert"
  log "Removed db/ and cert/"
fi

read -r -p "Disable and reset UFW rules? [y/N] " ans
if [[ "$ans" =~ ^[Yy]$ ]]; then
  ufw --force reset
  log "UFW reset"
fi

log "Done."
