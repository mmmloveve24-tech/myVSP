#!/usr/bin/env bash
# Bootstrap a fresh Ubuntu 22.04/24.04 VPS for myVSP.
# Idempotent — safe to re-run.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." &>/dev/null && pwd)"
# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

require_root
detect_ubuntu

# Load .env if present (for SSH_PORT, PANEL_PORT, etc.). Fall back to defaults.
if [[ -f "$REPO_ROOT/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  . "$REPO_ROOT/.env"
  set +a
fi

log "Updating apt index"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get -y -qq upgrade

log "Installing base packages"
BASE_PKGS=(curl ca-certificates gnupg lsb-release ufw fail2ban unattended-upgrades htop jq qrencode git)
MISSING=()
for p in "${BASE_PKGS[@]}"; do
  dpkg -s "$p" &>/dev/null || MISSING+=("$p")
done
if (( ${#MISSING[@]} )); then
  apt-get install -y -qq "${MISSING[@]}"
fi

log "Enabling unattended security upgrades"
echo 'unattended-upgrades unattended-upgrades/enable_auto_updates boolean true' \
  | debconf-set-selections
dpkg-reconfigure -f noninteractive unattended-upgrades >/dev/null

if ! command -v docker >/dev/null; then
  log "Installing Docker Engine (official repo)"
  install -m 0755 -d /etc/apt/keyrings
  if [[ ! -f /etc/apt/keyrings/docker.gpg ]]; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
      | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
  fi
  # shellcheck disable=SC1091
  . /etc/os-release
  cat >/etc/apt/sources.list.d/docker.list <<EOF
deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable
EOF
  apt-get update -qq
  apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  systemctl enable --now docker
else
  log "Docker already installed: $(docker --version)"
fi

log "Applying kernel tuning (BBR, ip_forward, file limits)"
install -m 0644 "$REPO_ROOT/sysctl/99-vpn-tuning.conf" /etc/sysctl.d/99-vpn-tuning.conf
lsmod | grep -q '^tcp_bbr' || modprobe tcp_bbr || warn "modprobe tcp_bbr failed (will rely on built-in)"
sysctl --system >/dev/null
CC="$(sysctl -n net.ipv4.tcp_congestion_control)"
[[ "$CC" == "bbr" ]] || warn "tcp_congestion_control is '$CC', expected 'bbr'"

log "Configuring UFW"
# Export tunables for the rules script.
export SSH_PORT="${SSH_PORT:-22}"
export PANEL_PORT="${PANEL_PORT:-2053}"
export REALITY_PORT="${REALITY_PORT:-443}"
export ALLOW_AMNEZIAWG="${ALLOW_AMNEZIAWG:-false}"
export AMNEZIAWG_PORT="${AMNEZIAWG_PORT:-51820}"
bash "$REPO_ROOT/ufw/rules.sh"

log "Installing fail2ban sshd jail"
install -m 0644 "$REPO_ROOT/fail2ban/jail.local" /etc/fail2ban/jail.local
systemctl enable --now fail2ban
systemctl restart fail2ban

log "Done."
cat <<EOF

Next step:
  sudo bash $SCRIPT_DIR/setup-3xui.sh

Optional:
  sudo bash $SCRIPT_DIR/harden-ssh.sh        # disable SSH password auth (key-only)
  cd $REPO_ROOT/amneziawg && sudo bash setup-awg.sh   # AmneziaWG fallback
EOF
