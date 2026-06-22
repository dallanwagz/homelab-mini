#!/usr/bin/env bash
#
# hibernate-wol-setup.sh  --  homelab-mini
# ---------------------------------------------------------------------------
# Park a headless box in a near-off, REMOTELY-WAKEABLE state: configure
# hibernate (ACPI S4) + Wake-on-LAN. After this + one reboot:
#     sudo systemctl hibernate          # powers down to S4 (near-off draw)
#     wakeonlan <mac>                    # from a host on the same LAN segment -> resumes
# Your session is restored (true resume), not a fresh boot.
#
# WHY: a full `poweroff` (S5) often can't be woken by WoL (firmware caps the NIC's
# wake S-state at S4 — see docs/how-it-works.md). Hibernate (S4) gets ~off-level
# power draw AND stays wakeable. Great for cutting idle cost on an always-plugged box.
#
# REQUIREMENTS: systemd; swap (file or partition) >= RAM; a NIC that supports WoL
# from S4 (check `/proc/acpi/wakeup` — the NIC's S-state column must be >= 4).
# Model-agnostic. Idempotent.
#
# USAGE:  sudo ./hibernate-wol-setup.sh            apply (then REBOOT)
#         sudo ./hibernate-wol-setup.sh --status   report only
# ---------------------------------------------------------------------------
set -euo pipefail
MODE="${1:-apply}"
die(){ echo "ERROR: $*" >&2; exit 1; }
[[ $EUID -ne 0 ]] && exec sudo -- "$0" "$@"

IFACE="$(ip -o route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1);exit}}')"
[[ -z "${IFACE:-}" ]] && IFACE="$(ip -o link show up 2>/dev/null | awk -F': ' '$2!="lo"{print $2;exit}')"

if [[ "$MODE" == "--status" ]]; then
  echo "iface:                    ${IFACE:-?}  (mac $( [ -n "${IFACE:-}" ] && cat /sys/class/net/$IFACE/address 2>/dev/null))"
  echo "resume on cmdline:        $(grep -oE 'resume=[^ ]*( resume_offset=[^ ]*)?' /proc/cmdline || echo none)"
  echo "/sys/power/resume_offset: $(cat /sys/power/resume_offset 2>/dev/null)"
  echo "hibernate.target:         $(systemctl is-enabled hibernate.target 2>&1)"
  echo "hibernate disk mode:      $(cat /sys/power/disk 2>/dev/null)   (want [platform] = S4)"
  echo "WoL boot service:         $(systemctl is-enabled wake-on-lan.service 2>&1)"
  echo "WoL resume re-arm hook:   $([ -x /usr/lib/systemd/system-sleep/rearm-wol ] && echo installed || echo MISSING)"
  [ -n "${IFACE:-}" ] && echo "WoL armed now:            $(ethtool "$IFACE" 2>/dev/null | awk '/^[[:space:]]*Wake-on:/{print $2}')"
  echo "NIC max wake S-state:     $(grep -iE 'GIGE|LAN|GBE|ETH' /proc/acpi/wakeup 2>/dev/null | awk '{print $1" -> "$2}' | tr '\n' ' ')"
  exit 0
fi

[[ -z "${IFACE:-}" ]] && die "could not determine a network interface."
command -v ethtool  >/dev/null || { apt-get update -qq && apt-get install -y -qq ethtool; }
command -v filefrag >/dev/null || { apt-get update -qq && apt-get install -y -qq e2fsprogs; }

# --- pick the largest active swap; warn if < RAM ---
RAM_B=$(( $(awk '/MemTotal/{print $2}' /proc/meminfo) * 1024 ))
BEST=""; BESTSZ=0; BESTTYPE=""
while read -r name type size used prio; do
  [ "$name" = "NAME" ] && continue
  b=$(numfmt --from=iec "$size" 2>/dev/null || echo 0)
  if [ "${b:-0}" -gt "$BESTSZ" ]; then BEST="$name"; BESTSZ="$b"; BESTTYPE="$type"; fi
done < <(swapon --show 2>/dev/null)
[ -z "$BEST" ] && die "no active swap. Create swap >= RAM first (fallocate + mkswap + swapon + fstab)."
[ "$BESTSZ" -lt "$RAM_B" ] && echo "WARNING: largest swap ($BEST) < RAM — hibernation image may not fit."
echo "Using swap: $BEST ($BESTTYPE)"

# --- build resume args (swapfile needs an offset; partition/LV does not) ---
if [ "$BESTTYPE" = "file" ]; then
  FSUUID=$(findmnt -no UUID --target "$BEST")
  OFFSET=$(filefrag -v "$BEST" | awk '/^[[:space:]]*0:/{v=$4; gsub(/[^0-9]/,"",v); print v; exit}')
  [ -z "$OFFSET" ] && die "could not compute resume_offset for $BEST"
  RESUME_ARGS="resume=UUID=$FSUUID resume_offset=$OFFSET"
  echo "RESUME=UUID=$FSUUID resume_offset=$OFFSET" > /etc/initramfs-tools/conf.d/resume
else
  SWUUID=$(blkid -s UUID -o value "$BEST")
  RESUME_ARGS="resume=UUID=$SWUUID"
  echo "RESUME=UUID=$SWUUID" > /etc/initramfs-tools/conf.d/resume
fi
echo "resume args: $RESUME_ARGS"

# --- kernel cmdline (replace any existing resume args) ---
if grep -q '^GRUB_CMDLINE_LINUX_DEFAULT=' /etc/default/grub; then
  cur=$(sed -nE 's/^GRUB_CMDLINE_LINUX_DEFAULT="?(.*)"?$/\1/p' /etc/default/grub \
        | sed -E 's/resume=[^ ]*//g; s/resume_offset=[^ ]*//g; s/  +/ /g; s/^ //; s/ $//')
  sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"${cur:+$cur }$RESUME_ARGS\"|" /etc/default/grub
else
  echo "GRUB_CMDLINE_LINUX_DEFAULT=\"$RESUME_ARGS\"" >> /etc/default/grub
fi
grep '^GRUB_CMDLINE_LINUX_DEFAULT=' /etc/default/grub

# --- allow hibernate (in case the always-on profile masked it) ---
systemctl unmask sleep.target hibernate.target >/dev/null 2>&1 || true

# --- WoL: arm now, persist at boot, and re-arm after every resume ---
ethtool -s "$IFACE" wol g || true
cat > /etc/systemd/system/wake-on-lan.service <<EOF
[Unit]
Description=Enable Wake-on-LAN on $IFACE
After=network-online.target
Wants=network-online.target
[Service]
Type=oneshot
ExecStart=$(command -v ethtool) -s $IFACE wol g
[Install]
WantedBy=multi-user.target
EOF
cat > /usr/lib/systemd/system-sleep/rearm-wol <<EOF
#!/bin/sh
case "\$1" in post) $(command -v ethtool) -s $IFACE wol g 2>/dev/null ;; esac
exit 0
EOF
chmod 0755 /usr/lib/systemd/system-sleep/rearm-wol
systemctl daemon-reload; systemctl enable wake-on-lan.service >/dev/null 2>&1 || true

update-initramfs -u 2>&1 | tail -1
update-grub 2>&1 | tail -1

echo
echo "DONE. REBOOT once to load the resume config, then:"
echo "  sudo systemctl hibernate                     # park to S4"
echo "  wakeonlan $(cat /sys/class/net/$IFACE/address)   # wake (same LAN segment)"
echo "Verify '/sys/power/disk' shows [platform] (S4). 'shutdown' mode is NOT WoL-wakeable."
echo "Confirm your NIC's S-state in /proc/acpi/wakeup is >= 4."
