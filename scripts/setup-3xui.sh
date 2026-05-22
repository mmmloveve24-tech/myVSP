#!/usr/bin/env bash
# Generate panel secrets, start 3X-UI, configure admin via x-ui CLI, print creds once.
# Re-run safe. Pass --rotate to regenerate credentials.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." &>/dev/null && pwd)"
# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

require_root

ROTATE=false
[[ "${1:-}" == "--rotate" ]] && ROTATE=true

command -v docker >/dev/null || err "Docker not installed — run scripts/install.sh first."
docker compose version >/dev/null 2>&1 || err "docker compose plugin missing."

ENV_FILE="$REPO_ROOT/.env"

generate_env() {
  log "Generating fresh .env"
  cp "$REPO_ROOT/.env.example" "$ENV_FILE"
  local user pass path
  user="admin_$(rand_str 8)"
  pass="$(rand_str 24)"
  path="/$(rand_str 24)"
  sed -i "s|^PANEL_USER=.*|PANEL_USER=${user}|" "$ENV_FILE"
  sed -i "s|^PANEL_PASS=.*|PANEL_PASS=${pass}|" "$ENV_FILE"
  # Use | as sed delimiter because $path contains /
  sed -i "s|^PANEL_PATH=.*|PANEL_PATH=${path}|" "$ENV_FILE"
  chmod 600 "$ENV_FILE"
}

if [[ ! -f "$ENV_FILE" ]] || $ROTATE; then
  generate_env
else
  log ".env already exists — keeping existing credentials (pass --rotate to regenerate)"
fi

# Load env
set -a
# shellcheck disable=SC1090
. "$ENV_FILE"
set +a

# Refresh firewall to match current ports
log "Refreshing UFW rules"
export SSH_PORT PANEL_PORT REALITY_PORT ALLOW_AMNEZIAWG AMNEZIAWG_PORT
bash "$REPO_ROOT/ufw/rules.sh" >/dev/null

mkdir -p "$REPO_ROOT/db" "$REPO_ROOT/cert"

log "Pulling 3X-UI image (${XUI_IMAGE_TAG})"
( cd "$REPO_ROOT" && docker compose pull )

log "Starting 3X-UI"
( cd "$REPO_ROOT" && docker compose up -d )

log "Waiting for container to be ready"
for i in $(seq 1 30); do
  if docker exec 3x-ui /usr/bin/x-ui status >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

log "Configuring panel via x-ui CLI"
# Newer 3x-ui builds support combined `setting` flags. Try the combined call,
# fall back to separate calls if flags differ.
if ! docker exec 3x-ui x-ui setting \
       -username "$PANEL_USER" \
       -password "$PANEL_PASS" \
       -port "$PANEL_PORT" \
       -webBasePath "$PANEL_PATH" >/dev/null 2>&1; then
  warn "Combined 'x-ui setting' call failed — trying split calls"
  docker exec 3x-ui x-ui setting -username "$PANEL_USER" -password "$PANEL_PASS" || \
    warn "Could not set username/password automatically — set via panel UI after first login"
  docker exec 3x-ui x-ui setting -port "$PANEL_PORT" || true
  docker exec 3x-ui x-ui setting -webBasePath "$PANEL_PATH" || true
fi

log "Restarting container to apply settings"
docker restart 3x-ui >/dev/null

# Persist credentials locally (gitignored via db/)
CRED_FILE="$REPO_ROOT/db/CREDENTIALS.txt"
umask 077
cat >"$CRED_FILE" <<EOF
# 3X-UI panel credentials — keep this file secret.
PANEL_URL=http://$(hostname -I | awk '{print $1}'):${PANEL_PORT}${PANEL_PATH}/
PANEL_USER=${PANEL_USER}
PANEL_PASS=${PANEL_PASS}
EOF
chmod 600 "$CRED_FILE"

cat <<EOF

=========================================================
 3X-UI is up. Open the panel and change the password via UI:

   URL : http://$(hostname -I | awk '{print $1}'):${PANEL_PORT}${PANEL_PATH}/
   User: ${PANEL_USER}
   Pass: ${PANEL_PASS}

 Credentials also saved to: ${CRED_FILE}
=========================================================
EOF
