#!/usr/bin/env bash
# Idempotent UFW configuration. Sourced/exec'd by install.sh and setup-3xui.sh.
# Expects SSH_PORT, PANEL_PORT, REALITY_PORT, ALLOW_AMNEZIAWG, AMNEZIAWG_PORT
# to be set via .env (or sane defaults below).

set -euo pipefail

: "${SSH_PORT:=22}"
: "${PANEL_PORT:=2053}"
: "${REALITY_PORT:=443}"
: "${ALLOW_AMNEZIAWG:=false}"
: "${AMNEZIAWG_PORT:=51820}"

ufw default deny incoming  >/dev/null
ufw default allow outgoing >/dev/null

# Allow SSH FIRST so enabling UFW can never lock us out.
ufw allow "${SSH_PORT}/tcp"     comment 'ssh' >/dev/null
ufw allow "${REALITY_PORT}/tcp" comment 'xray reality' >/dev/null
ufw allow "${PANEL_PORT}/tcp"   comment '3x-ui panel' >/dev/null

if [[ "${ALLOW_AMNEZIAWG}" == "true" ]]; then
  ufw allow "${AMNEZIAWG_PORT}/udp" comment 'amneziawg' >/dev/null
fi

ufw --force enable >/dev/null
ufw status verbose
