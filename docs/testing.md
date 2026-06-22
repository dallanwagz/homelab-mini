# Testing methodology

Software can *set* a flag; only a **physical test** proves your machine behaves.
Firmware lies, datasheets have errata, and "the register read back correctly"
is not the same as "it actually powered on." So we test for real.

There are two tests. They're quick, and they pair nicely.

---

## Test 1 — Auto power-on after a power loss

**What it proves:** the box powers itself back on after a real outage (the whole
point of `power-on-after-failure.sh`).

**Setup:** the mini is running and reachable. You've run
`sudo ./scripts/power-on-after-failure.sh` (check `--status` shows
*AfterG3_En CLEAR → ENABLED*).

**Steps:**
1. Confirm it's up (`ping` / `ssh`).
2. **Physically pull the power cable from the wall** (or flip the outlet/strip).
   The mini powers off immediately — expected.
3. Wait ~10 seconds.
4. **Plug it back in.** Do **not** touch the power button.

**Pass:** within a few seconds you hear/see it power on; it answers on the network
again in **~60–120 s** (POST → GRUB → boot). 
**Fail:** it stays dark. → the AfterG3 bit isn't taking on your model; do not mark
the model verified. Re-check `--status`, the register, and your model's datasheet.

> Tip: have a second machine poll for it: `while ! ping -c1 <ip>; do sleep 5; done; echo UP`.

---

## Test 2 — Wake-on-LAN (which sleep states actually wake?)

**The crucial insight:** WoL support is *per power state*. Many machines (esp. Macs)
wake from **S3/S4** (sleep/hibernate) but **not S5** (soft-off). Check the ceiling
first: `cat /proc/acpi/wakeup` — the NIC's row (e.g. `GIGE`) shows the deepest
wake S-state. `S4` ⇒ S5 will never wake (firmware), so don't test S5 and call WoL
"broken." (Full diagnostic chain in [`how-it-works.md`](how-it-works.md).)

**Sender — eliminate the network first.** WoL is layer-2, so send from a host on the
**same broadcast domain** as the target (ideally the same switch). Use the bundled
no-install tool and **bind to your wired source IP** (a classic false negative is the
packet leaving via Wi-Fi/Tailscale):
```
./scripts/send-magic-packet.py <MAC> --broadcast <subnet-bcast> --source <your-wired-ip>
```
If a *same-segment* sender can't wake a powered-off box but *can* wake it from S3,
the limit is the firmware S-state cap, not your switches/VLANs.

**Setup:** `sudo ./scripts/wake-on-lan.sh` (note the MAC). For hibernate, also run
`sudo ./scripts/hibernate-wol-setup.sh` and reboot.

### 2a. From S3 (suspend) — the quick check
1. `sudo systemctl suspend` (you may need to un-mask `suspend.target` first).
2. Confirm it's down; send the magic packet from the same-segment sender.
3. **Pass:** wakes in a few seconds. Recover anytime with the power button.

### 2b. From S4 (hibernate) — the cost-saver, with resume verification
A graceful `poweroff` (S5) won't auto-power-on (no G3 event) and on many boxes won't
WoL either. **Hibernate (S4)** gives near-off power *and* WoL — and should **resume**
your session. Prove it's a true resume (not a fresh boot) with a marker:
1. `touch /run/wol-test-marker && cat /proc/uptime` (note uptime).
2. `sudo systemctl hibernate` (ensure `/sys/power/disk` shows `[platform]`, i.e. S4 —
   `shutdown` mode is S5-like and won't WoL).
3. Confirm it powered down; send the magic packet from the same-segment sender.
4. **Pass:** it wakes **and** `/run/wol-test-marker` still exists with uptime
   continuing upward → true resume from S4. (Marker gone + uptime reset = it
   fresh-booted, i.e. resume failed — recheck `resume=`/`resume_offset`.)

**If nothing wakes from any state** (even a same-switch sender): WoL isn't usable
here — rely on auto-power-on + a smart plug for remote power cycling.

---

## Reporting your results
Add or update a file in [`../models/`](../models/) (copy
[`../models/macmini7,1.md`](../models/macmini7,1.md)) with what you observed, and
open a PR. If a hardware register was involved, the **Test 1 result is required** —
see [`../CONTRIBUTING.md`](../CONTRIBUTING.md).
