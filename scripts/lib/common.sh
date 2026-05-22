#!/usr/bin/env bash
# Shared helpers. Source this file from other scripts.

set -euo pipefail

log()  { printf '\e[1;34m[+]\e[0m %s\n' "$*"; }
warn() { printf '\e[1;33m[!]\e[0m %s\n' "$*" >&2; }
err()  { printf '\e[1;31m[x]\e[0m %s\n' "$*" >&2; exit 1; }

require_root() {
  [[ $EUID -eq 0 ]] || err "Run as root (sudo)."
}

rand_str() {
  local n="${1:-24}"
  LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c "$n"
}

detect_ubuntu() {
  [[ -r /etc/os-release ]] || err "/etc/os-release missing — unsupported OS."
  # shellcheck disable=SC1091
  . /etc/os-release
  [[ "${ID:-}" == "ubuntu" ]] || err "Ubuntu only (detected: ${ID:-unknown})."
  case "${VERSION_ID:-}" in
    22.04|24.04) ;;
    *) warn "Untested Ubuntu version: ${VERSION_ID:-unknown}";;
  esac
}

# Load .env from the given path (defaults to repo root .env) into the current shell.
load_env() {
  local env_file="${1:-$REPO_ROOT/.env}"
  [[ -f "$env_file" ]] || err "Missing $env_file. Run setup-3xui.sh or copy .env.example to .env."
  set -a
  # shellcheck disable=SC1090
  . "$env_file"
  set +a
}
