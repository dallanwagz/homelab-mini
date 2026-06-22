#!/usr/bin/env bash
#
# power-on-after-failure.sh  --  Homelab Mini
# ---------------------------------------------------------------------------
# Make an Intel Mac mini running Linux AUTOMATICALLY POWER BACK ON after a power
# loss (AC removed, then restored) -- with NO macOS involved.
#
# WHY: The macOS "Start up automatically after a power failure" flag
# (pmset autorestart) is unreliable on a Linux-only Mac mini -- it is re-armed
# only by macOS at each boot, cleared by a graceful shutdown, and does not persist
# when set from Recovery. The durable fix is to clear the Intel PCH "AfterG3_En"
# bit in the GEN_PMCON register directly from Linux, and re-apply it on every boot.
#
#   AfterG3_En = 0  -> on AC restore from full power-off (G3), the board powers ON
#   AfterG3_En = 1  -> the board stays OFF
#
# See docs/how-it-works.md for the full explanation, and docs/testing.md for how
# to verify it (you must physically pull the plug).
#
# MODEL AWARENESS: the controlling PCI device / register / bit varies by chipset,
# and writing the wrong register can hang the machine. This script only touches
# hardware on models it has been VERIFIED on. On any other model it refuses and
# tells you how to contribute the values (see CONTRIBUTING.md).
#
# USAGE:  sudo ./power-on-after-failure.sh            apply + verify + persist
#         sudo ./power-on-after-failure.sh --status   report only (no changes)
#
# Idempotent. Safe to re-run.
# ---------------------------------------------------------------------------
set -euo pipefail

SERVICE_PATH=/etc/systemd/system/poweron-after-failure.service
MODE="${1:-apply}"
die() { echo "ERROR: $*" >&2; exit 1; }

[[ $EUID -ne 0 ]] && exec sudo -- "$0" "$@"

MODEL="$(cat /sys/class/dmi/id/product_name 2>/dev/null || true)"
[[ -z "$MODEL" ]] && MODEL="$(command -v dmidecode >/dev/null 2>&1 && dmidecode -s system-product-name 2>/dev/null || true)"
[[ -z "$MODEL" ]] && die "Could not determine system model (is this a Mac running Linux?)."
echo "Detected model: $MODEL"

# ---------------------------------------------------------------------------
# PER-MODEL REGISTER MAP  (add a verified model here -- see CONTRIBUTING.md)
#   PCI_DEV     : LPC controller, usually 0:1f.0
#   REG         : GEN_PMCON register holding AfterG3_En
#   BIT_MASK    : hex mask of the AfterG3_En bit (no 0x prefix)
#   EXPECT_LPC  : substring that `lspci` should show for that device (sanity gate)
# ---------------------------------------------------------------------------
case "$MODEL" in
  "Macmini7,1")   # Mac mini, Late 2014 -- Intel 8-Series "Haswell" LPC. VERIFIED.
    PCI_DEV="0:1f.0"; REG="0xa4"; BIT_MASK="1"; EXPECT_LPC="8 Series" ;;
  *)
    cat >&2 <<EOF

UNSUPPORTED MODEL: '$MODEL'

This script has only been verified on the models listed in its register map.
The register that controls "power on after power loss" varies by chipset, and
guessing it could hang the machine -- so this script will NOT proceed.

If this is a normal PC mini (most non-Apple boxes), you probably DON'T need this
script: the setting is right in your BIOS. Reboot, enter setup, and look for
  Chipset -> 'State After G3' = S0 State   (or 'Restore AC Power Loss' = Power On)
See models/ for examples (e.g. beelink-mini-s12-pro.md). Macs hide it; PCs don't.

Otherwise, help us add your Mac model (see CONTRIBUTING.md). Please collect:
  * the model string above: $MODEL
  * output of:  sudo lspci -nn -s 00:1f.0   (and full 'sudo lspci -nn' if 1f.0 is absent)
  * your CPU / chipset generation
...then find + physically test the AfterG3 bit (docs/how-it-works.md, docs/testing.md)
and open a pull request.

EOF
    exit 2 ;;
esac

command -v setpci >/dev/null 2>&1 || { echo "Installing pciutils..."; apt-get update -qq && apt-get install -y -qq pciutils; }
SETPCI="$(command -v setpci)"

DESC="$(lspci -s "$PCI_DEV" 2>/dev/null || true)"
[[ -z "$DESC" ]] && die "Expected LPC controller not found at $PCI_DEV."
echo "  $PCI_DEV: $DESC"
[[ -n "${EXPECT_LPC:-}" && "$DESC" != *"$EXPECT_LPC"* ]] && \
  die "Device at $PCI_DEV doesn't look like the expected '$EXPECT_LPC' controller. Aborting to be safe."

read_reg() { "$SETPCI" -s "$PCI_DEV" "${REG}.b"; }
bit_set()  { (( (0x$(read_reg) & 0x${BIT_MASK}) != 0 )); }   # true => AfterG3_En set => stays OFF

if [[ "$MODE" == "--status" ]]; then
  CUR="$(read_reg)"
  if bit_set; then echo "  ${REG}=0x${CUR}: AfterG3_En SET -> stays OFF after power loss (auto power-on DISABLED)"
  else             echo "  ${REG}=0x${CUR}: AfterG3_En CLEAR -> powers ON after power loss (auto power-on ENABLED)"; fi
  systemctl is-enabled poweron-after-failure.service >/dev/null 2>&1 \
    && echo "  persistence service: enabled" || echo "  persistence service: NOT installed"
  exit 0
fi

echo "  ${REG} before = 0x$(read_reg)"
"$SETPCI" -s "$PCI_DEV" "${REG}.b=0:${BIT_MASK}"      # clear the bit (safe masked write)
echo "  ${REG} after  = 0x$(read_reg)"
bit_set && die "AfterG3 bit still set after write -- register did not take."
echo "  -> AfterG3_En cleared: the board will power ON when AC is restored."

cat > "$SERVICE_PATH" <<EOF
[Unit]
Description=Power on Mac mini after power loss (clear PCH AfterG3 bit)
After=multi-user.target

[Service]
Type=oneshot
ExecStart=${SETPCI} -s ${PCI_DEV} ${REG}.b=0:${BIT_MASK}

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable poweron-after-failure.service >/dev/null
echo "  installed + enabled $SERVICE_PATH (re-applies on every boot)"
echo
echo "DONE. Now TEST it (docs/testing.md): with the mini running, physically pull AC,"
echo "wait ~10s, reconnect. It should power on by itself (network back in ~60-120s)."
