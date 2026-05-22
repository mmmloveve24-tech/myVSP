#!/usr/bin/env bash
# Opt-in AmneziaWG installer. Run AFTER scripts/install.sh and scripts/setup-3xui.sh.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." &>/dev/null && pwd)"
# shellcheck source=../scripts/lib/common.sh
. "$REPO_ROOT/scripts/lib/common.sh"

require_root
command -v docker >/dev/null || err "Docker not installed — run scripts/install.sh first."

ROOT_ENV="$REPO_ROOT/.env"
[[ -f "$ROOT_ENV" ]] || err "Repo .env missing — run scripts/setup-3xui.sh first."

# Flip ALLOW_AMNEZIAWG=true in the root .env, then refresh UFW
log "Enabling AmneziaWG in repo .env and refreshing UFW"
sed -i 's|^ALLOW_AMNEZIAWG=.*|ALLOW_AMNEZIAWG=true|' "$ROOT_ENV"
set -a
# shellcheck disable=SC1090
. "$ROOT_ENV"
set +a
export SSH_PORT PANEL_PORT REALITY_PORT ALLOW_AMNEZIAWG AMNEZIAWG_PORT
bash "$REPO_ROOT/ufw/rules.sh" >/dev/null

ENV_FILE="$SCRIPT_DIR/.env"
if [[ ! -f "$ENV_FILE" ]]; then
  log "Generating amneziawg/.env"
  cp "$SCRIPT_DIR/.env.example" "$ENV_FILE"
  ip_addr="$(hostname -I | awk '{print $1}')"
  pass="$(rand_str 24)"
  sed -i "s|^PASSWORD=.*|PASSWORD=${pass}|" "$ENV_FILE"
  sed -i "s|^WG_HOST=.*|WG_HOST=${ip_addr}|" "$ENV_FILE"
  sed -i "s|^WG_PORT=.*|WG_PORT=${AMNEZIAWG_PORT}|" "$ENV_FILE"
  chmod 600 "$ENV_FILE"
fi

mkdir -p "$SCRIPT_DIR/wg-data"

log "Pulling AmneziaWG image"
( cd "$SCRIPT_DIR" && docker compose pull )

log "Starting awg-easy"
( cd "$SCRIPT_DIR" && docker compose up -d )

set -a
# shellcheck disable=SC1090
. "$ENV_FILE"
set +a

cat <<EOF

=========================================================
 AmneziaWG (awg-easy) is up.

 The admin UI is bound to 127.0.0.1 only. Reach it via SSH tunnel:

   ssh -L ${WEB_PORT:-51821}:127.0.0.1:${WEB_PORT:-51821} <user>@${WG_HOST}

 Then open in your browser:  http://127.0.0.1:${WEB_PORT:-51821}/

   Password: ${PASSWORD}

 Public UDP endpoint for clients: ${WG_HOST}:${WG_PORT}/udp
=========================================================
EOF
