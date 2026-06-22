# Beelink Mini S12 Pro (Intel N100) — BIOS toggle

Status: ✅ **verified on hardware** (auto power-on confirmed after a real plug-pull).

Manufacturer reports as **AZW** (Beelink). Firmware: **AMI Aptio Setup**, observed
version **2.22.1292**.

> **Good news: no register hacking needed.** Unlike the Mac mini (whose firmware
> hides this setting, forcing a `setpci` write — see
> [`macmini7,1.md`](macmini7,1.md)), the Beelink exposes it as a normal BIOS menu
> option. The `power-on-after-failure.sh` script is **not** needed here; just flip
> the BIOS setting below. It's a firmware setting, so it works no matter which OS
> you install.

## How to set it (in case you forget)

1. Power on and **tap `Delete`** repeatedly during boot to enter **Aptio Setup**.
2. Arrow to the **`Chipset`** tab → **Enter**.
3. Open the submenu (name varies by BIOS build):
   - **`PCH-IO Configuration`**, **or**
   - **`South Cluster Configuration`**
4. Find the setting (name varies by build):
   - **`State After G3`** → set to **`S0 State`**, **or**
   - **`Restore AC Power Loss`** → set to **`Power On`**
5. **Save & exit:** press **`F4`** → confirm **Yes** (or **Save & Exit** tab →
   *Save Changes and Reset*).

### Option meanings
| Option | Behavior |
|--------|----------|
| **S0 State / Power On** ✅ | Always boots when power is applied — what you want |
| S5 State / Power Off | Stays off until the button is pressed (default) |
| Last State | Returns to whatever state it was in before the loss |

Use **S0 State / Power On** for deterministic "always turn on after power loss."

> Not under `Chipset`? Some builds put **`Restore AC Power Loss`** under
> **`Advanced → APM Configuration`** instead.

### Test result
Pulled AC, reconnected → the unit **powered on by itself** and booted. PASS.

## Wake-on-LAN
Most of these mini PCs support WoL; enable it in BIOS (look for **`Wake on LAN`** /
**`Power On by PCIE`** under `Advanced`/`APM`) and/or in the OS with
[`../scripts/wake-on-lan.sh`](../scripts/wake-on-lan.sh). Not yet documented in
detail here — PRs welcome.
