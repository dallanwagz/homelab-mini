# Mac mini (Late 2014) — `Macmini7,1`

Status: ✅ **verified on hardware** (auto power-on confirmed by physical plug-pull).

## Hardware
- **CPU:** Intel "Haswell" (e.g. Core i5-4260U on the base config)
- **PCH / LPC controller:** `00:1f.0` — Intel 8-Series LPC Controller
- **RAM:** soldered (not upgradeable) — base config is 4 GB
- **Notes:** no T2 chip; Internet Recovery / Linux install both straightforward

## Power-on after power loss
- **Register:** `0xa4` (GEN_PMCON_3), **bit 0 = AfterG3_En**
- **Device:** PCI `0:1f.0`
- **Shipped value:** `0x09` (bit0 = 1 → stays OFF)
- **Set to:** `0x08` (bit0 = 0 → powers ON when AC returns)
- **Command:** `setpci -s 0:1f.0 0xa4.b=0:1`
- **Persistence:** systemd one-shot re-applies on every boot
  (installed by [`../scripts/power-on-after-failure.sh`](../scripts/power-on-after-failure.sh))

### Test result
Physical plug-pull test (running → pull AC → wait → reconnect): **PASS** — the mini
powered on by itself and booted unattended; back on the network in ~60–120 s. The
boot log confirmed an unclean (power-loss) boot, not a graceful one.

## Wake-on-LAN
NIC: Broadcom **BCM57766** (`tg3`). Supports magic packet (`ethtool wol g`); PCI PME
includes **`D3cold+`**; `power/wakeup` is `enabled`. Configured/persisted via
[`../scripts/wake-on-lan.sh`](../scripts/wake-on-lan.sh).

**Works from S1–S4, but NOT from S5 (soft-off).** Fully tested 2026-06-22:
- ✅ **S3 (suspend): WoL works** — woke ~20 s after a magic packet.
- ❌ **S5 (`poweroff`): does NOT wake** — even with the packet sent from a Raspberry Pi
  *one switch port away* (same broadcast domain). So it is **not** an L2 / VLAN /
  switch-chain / sender / arming problem — every one of those was eliminated.

**Root cause (firmware, not fixable from Linux):** `cat /proc/acpi/wakeup` lists the
NIC's ACPI device `GIGE` with S-state **`S4`** — the Mac's ACPI `_PRW` declares the
Ethernet can wake the system only up to S4, not S5.

**Implications:**
- **Always-on server:** irrelevant — it stays on; power-loss recovery is the AfterG3
  setting above.
- **Remote-wake a mostly-off box:** use **hibernate (S4)** or **suspend (S3)** instead
  of `poweroff`, then WoL works. (S4 ≈ off-level draw but needs hibernate/resume set
  up; S3 wakes instantly but keeps RAM powered.)
- **A full `poweroff` (S5) can't be woken** here — for that, use a smart plug + the
  AfterG3 auto-power-on (cut/restore AC → boots).

## Remote-wake via hibernate (S4) — ✅ VERIFIED, the cost-saver
Since S4 *is* wakeable here, hibernate gives a near-off-power, remotely-wakeable state
with a **true resume** (session restored). Set up with
[`../scripts/hibernate-wol-setup.sh`](../scripts/hibernate-wol-setup.sh). On this unit:
- Swap target `/swapfile2` (4 GB > 3.7 GB RAM); `resume=UUID=<root-fs> resume_offset=2981888`
  on the kernel cmdline + `/etc/initramfs-tools/conf.d/resume`.
- Hibernate disk mode must be **`[platform]`** (S4) — *not* `shutdown` (that's S5-like,
  unwakeable).
- WoL re-armed after each wake by `/usr/lib/systemd/system-sleep/rearm-wol`.
- **Test (2026-06-22):** `systemctl hibernate` → down in ~10 s → magic packet from a
  same-switch Pi → **woke + RESUMED in ~30 s** (marker in `/run` survived, uptime
  continuous = not a fresh boot). ✅

Usage: `sudo systemctl hibernate` to park it; `wakeonlan aa:bb:cc:dd:ee:ff` from a host
on the same LAN segment to bring it back.

## Headless notes
- `pmset autorestart` (macOS) does **not** survive on a Linux-only mini — use the
  chipset method above. (This is the model we learned that on.)
- Graceful `poweroff` lands in S5 and stays off (no auto-power-on) — expected, and
  handy for clean Wake-on-LAN testing.
- `headless-harden.sh` applies cleanly (sleep masked, GRUB recordfail, SSH on boot).
