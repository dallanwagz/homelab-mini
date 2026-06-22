# How it works: power, wake, and the AfterG3 bit

A headless server has one non-negotiable job: **come back on its own after a power
blip.** On an Intel Mac mini running Linux, that's surprisingly fiddly. Here's the
why behind the scripts.

## ACPI power states (the vocabulary)
- **S0** — on and running.
- **S3** — sleep (RAM powered, everything else mostly off).
- **S5** — "soft off." The OS shut down, but AC is still connected and the board
  has standby power.
- **G3** — "mechanical off." No power at all (unplugged, or mains cut).

The key distinction for our purposes: **a graceful `poweroff` lands in S5** (AC
still present). **Pulling the plug / a real outage goes to G3** (power gone).

## Why the macOS setting fails on Linux
macOS exposes "Start up automatically after a power failure" (a.k.a.
`pmset autorestart`). On a Mac mini that is **only ever true while macOS manages
it**:
- It is **re-armed by macOS on each boot**. Boot Linux instead, and it isn't re-armed.
- A **graceful shutdown clears it.**
- Setting it from **macOS Recovery doesn't persist** (a known Intel-Mac quirk).

So on a Linux-only mini, `pmset` is a dead end. (We learned this the hard way —
set it in Recovery, watched the plug-pull test fail anyway.)

## The real lever: the chipset "AfterG3" bit
Intel platform controller hubs (PCHs) have a register — **GEN_PMCON** — with a bit
called **AfterG3_En** that decides what happens when power returns from **G3**:

| AfterG3_En | On AC restore from G3 |
|------------|------------------------|
| `0` | transition to **S0** (power **ON**) |
| `1` | stay in **S5** (power **OFF**) |

This is firmware/hardware behavior, **independent of which OS is installed**, and
it persists. That's exactly what a headless box wants. We set it directly from
Linux with `setpci`.

### On the Mac mini Late 2014 (`Macmini7,1`)
- LPC controller: `00:1f.0` (Intel 8-Series "Haswell").
- Register `0xa4` (GEN_PMCON_3), **bit 0 = AfterG3_En**.
- Found shipped at `0x09` (bit0 = 1 → stay off). Set to `0x08` (bit0 = 0 → power on).
- Command (safe masked write, only touches bit 0): `setpci -s 0:1f.0 0xa4.b=0:1`
- Persisted with a systemd one-shot that re-applies it every boot, so each recovery
  re-arms it for the next outage.

> ⚠️ **The device/register/bit vary by chipset.** Writing the wrong PCI register
> can hang the machine. That's why `power-on-after-failure.sh` only acts on models
> in its verified map and refuses otherwise. To add a model, see
> [`../CONTRIBUTING.md`](../CONTRIBUTING.md).

### Finding the bit on a new model
1. Identify the LPC controller: `sudo lspci -nn -s 00:1f.0` (Intel ISA/LPC bridge).
2. The GEN_PMCON / AfterG3 location is usually documented in that PCH's datasheet
   (often `0xa4` bit0 on many Intel generations, but **verify**).
3. Read it: `sudo setpci -s 0:1f.0 0xa4.b`. Try clearing bit0, then **physically
   test** (next doc). Don't trust it until a real plug-pull confirms it.

## Why graceful shutdown is your friend for Wake-on-LAN testing
Because a graceful `poweroff` lands in **S5** (not G3), the AfterG3 bit doesn't
fire — the machine simply **stays off**. That gives you a clean, repeatable "off"
state with no auto-power-on confounding things, which is perfect for testing
**Wake-on-LAN**: if the box comes up after a magic packet, that was WoL and nothing
else. See [`testing.md`](testing.md).

(WoL from S5 vs only from S3 is hardware-dependent — the test reveals which your
NIC supports.)

## Diagnosing WoL: which sleep states can actually wake?
If WoL fails, work down this chain *before* blaming the network:

1. **NIC supports + is armed:** `ethtool <iface>` → `Supports Wake-on: g` and
   `Wake-on: g`. Persist with `ethtool -s <iface> wol g`.
2. **Kernel will arm PME on the way down:** `cat /sys/class/net/<iface>/device/power/wakeup`
   must be `enabled` (else the kernel won't set PME-Enable at suspend/shutdown).
3. **Hardware can wake from a deep state:** `lspci -vv -s <bus>` → look for `D3cold+`
   in the `PME(...)` flags.
4. **The decisive one — what S-state does firmware allow?** `cat /proc/acpi/wakeup`
   shows each wake device and the **deepest S-state** it may wake from. Example:
   ```
   GIGE   S4   *enabled   pci:0000:03:00.0
   ```
   `S4` means the NIC can wake the system from **S1–S4 but NOT S5**. This is set by
   the firmware's ACPI `_PRW` and generally **can't be changed from Linux**.

**Key consequence:** if your box shows the NIC capped at `S4` (common on Macs), a full
`poweroff` (**S5**) will never wake — but **suspend (S3)** or **hibernate (S4)** will.
For an always-on server it's moot; for a "mostly off, wake-on-demand" box, hibernate +
WoL is the trick (and a smart plug + power-on-after-failure covers the true-off case).

**Rule out the network cleanly:** send the magic packet from a host on the **same
switch / broadcast domain** as the target. If a same-segment sender still can't wake a
powered-off box but *can* wake it from S3, the limitation is the firmware's S-state cap,
not your switches.
