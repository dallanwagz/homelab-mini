#!/usr/bin/env bash
#
# wake-on-lan.sh  --  Homelab Mini
# ---------------------------------------------------------------------------
# Enable + persist Wake-on-LAN on the primary wired interface, and print the MAC
# address to send magic packets to. Model-agnostic (works on any Linux box).
#
# Note: whether the machine wakes from FULL OFF (S5) vs only from SLEEP (S3) is
# hardware-dependent. The clean way to test it is in docs/testing.md -- do a
# graceful `systemctl poweroff` (which stays off, since no power LOSS occurred)
# then send a magic packet.
#
# USAGE:  sudo ./wake-on-lan.sh            enable + persist
#         sudo ./wake-on-lan.sh --status   report only
# Idempotent.
# ---------------------------------------------------------------------------
set -euo pipefail
MODE="${1:-apply}"
die() { echo "ERROR: $*" >&2; exit 1; }

[[ $EUID -ne 0 ]] && exec sudo -- "$0" "$@"

# primary interface = the one carrying the default route, else first non-loopback up link
IFACE="$(ip -o route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}')"
[[ -z "${IFACE:-}" ]] && IFACE="$(ip -o link show up 2>/dev/null | awk -F': ' '$2!="lo"{print $2; exit}')"
[[ -z "${IFACE:-}" ]] && die "Could not determine a network interface."

command -v ethtool >/dev/null 2>&1 || { echo "Installing ethtool..."; apt-get update -qq && apt-get install -y -qq ethtool; }
ETHTOOL="$(command -v ethtool)"

MAC="$(cat /sys/class/net/"$IFACE"/address 2>/dev/null || echo '??')"
SUPPORTED="$("$ETHTOOL" "$IFACE" 2>/dev/null | awk '/Supports Wake-on/{print $3}')"
CURRENT="$("$ETHTOOL" "$IFACE" 2>/dev/null | awk '/^[[:space:]]*Wake-on:/{print $2}')"

echo "Interface: $IFACE   MAC: $MAC"
echo "  Supports Wake-on: ${SUPPORTED:-unknown}   Current: ${CURRENT:-unknown}"

if [[ "$MODE" == "--status" ]]; then
  systemctl is-enabled wake-on-lan.service >/dev/null 2>&1 \
    && echo "  persistence service: enabled" || echo "  persistence service: NOT installed"
  exit 0
fi

[[ "$SUPPORTED" != *g* ]] && die "NIC '$IFACE' does not advertise magic-packet (g) Wake-on-LAN support."

"$ETHTOOL" -s "$IFACE" wol g
echo "  set Wake-on-LAN = g (magic packet) on $IFACE"

cat > /etc/systemd/system/wake-on-lan.service <<EOF
[Unit]
Description=Enable Wake-on-LAN on ${IFACE}
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=${ETHTOOL} -s ${IFACE} wol g

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable wake-on-lan.service >/dev/null
echo "  installed + enabled /etc/systemd/system/wake-on-lan.service (re-applies on boot)"
echo
echo "DONE. Wake it from another machine on the LAN with:   wakeonlan $MAC"
echo "Test method: see docs/testing.md (graceful poweroff, then send the packet)."
