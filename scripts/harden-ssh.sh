#!/usr/bin/env bash
# Disable SSH password authentication. Only run this AFTER you have a working
# SSH key on the server — otherwise you will lock yourself out.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

require_root

cat <<'EOF'
============================================================
 WARNING: this will DISABLE SSH password authentication.

 Before continuing, confirm that:
   1. Your SSH public key is in ~/.ssh/authorized_keys for at
      least one user that can log in.
   2. You can open a SECOND SSH session right now with that key
      and keep it open while we test.

 Type the word YES (uppercase) to continue, anything else to abort.
============================================================
EOF
read -r -p "> " answer
[[ "$answer" == "YES" ]] || err "Aborted."

DROPIN=/etc/ssh/sshd_config.d/99-hardening.conf
log "Writing $DROPIN"
cat >"$DROPIN" <<'EOF'
PasswordAuthentication no
PermitRootLogin prohibit-password
KbdInteractiveAuthentication no
EOF

log "Validating sshd config"
sshd -t

log "Reloading sshd"
systemctl reload ssh

log "Done. Test a NEW ssh session before closing this one."
