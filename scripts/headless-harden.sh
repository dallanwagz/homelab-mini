#!/usr/bin/env bash
#
# headless-harden.sh  --  Homelab Mini
# ---------------------------------------------------------------------------
# Make a Linux box behave like a proper unattended headless server:
#   1. never auto-sleep / suspend / hibernate
#   2. GRUB never hangs at the menu after an unclean shutdown (recordfail)
#   3. SSH is enabled at boot
# Model-agnostic. Idempotent. Safe to re-run.
#
# USAGE:  sudo ./headless-harden.sh            apply
#         sudo ./headless-harden.sh --status   report only
# ---------------------------------------------------------------------------
set -euo pipefail
MODE="${1:-apply}"

[[ $EUID -ne 0 ]] && exec sudo -- "$0" "$@"

if [[ "$MODE" == "--status" ]]; then
  echo "sleep.target:   $(systemctl is-enabled sleep.target 2>&1)"
  echo "suspend.target: $(systemctl is-enabled suspend.target 2>&1)"
  echo "ssh:            $(systemctl is-enabled ssh 2>&1)  (socket: $(systemctl is-enabled ssh.socket 2>&1))"
  grep -E '^GRUB_RECORDFAIL_TIMEOUT=' /etc/default/grub 2>/dev/null || echo "GRUB_RECORDFAIL_TIMEOUT: not set"
  exit 0
fi

echo "1) Masking sleep/suspend/hibernate targets..."
systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
echo "   sleep.target -> $(systemctl is-enabled sleep.target 2>&1)"

echo "2) Ensuring GRUB never hangs after an unclean shutdown..."
if [[ -f /etc/default/grub ]]; then
  if grep -q '^GRUB_RECORDFAIL_TIMEOUT=' /etc/default/grub; then
    sed -i 's/^GRUB_RECORDFAIL_TIMEOUT=.*/GRUB_RECORDFAIL_TIMEOUT=5/' /etc/default/grub
  else
    echo 'GRUB_RECORDFAIL_TIMEOUT=5' >> /etc/default/grub
  fi
  if command -v update-grub >/dev/null 2>&1; then update-grub >/dev/null 2>&1; else update-grub2 >/dev/null 2>&1 || true; fi
  echo "   GRUB_RECORDFAIL_TIMEOUT=5 applied"
else
  echo "   (no /etc/default/grub -- skipping; not a GRUB system?)"
fi

echo "3) Enabling SSH at boot..."
systemctl enable ssh >/dev/null 2>&1 || systemctl enable ssh.socket >/dev/null 2>&1 || true
echo "   ssh: $(systemctl is-enabled ssh 2>&1) / ssh.socket: $(systemctl is-enabled ssh.socket 2>&1)"

echo
echo "DONE. The box will boot unattended and won't doze off."
