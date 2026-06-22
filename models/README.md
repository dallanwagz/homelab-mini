# Model registry

Per-model, hardware-verified details for repurposing small/old hardware as
headless Linux servers. The most important field is **power-on-after-failure**.

There are two ways a machine gets there:
- **BIOS toggle** — a normal PC BIOS exposes "State After G3 / Restore AC Power
  Loss." Easy: just set it. (Most non-Apple mini PCs.)
- **Register write (`setpci`)** — the firmware *hides* the setting, so we flip the
  chipset's AfterG3 bit directly from Linux. (Mac minis.) This is what
  [`../scripts/power-on-after-failure.sh`](../scripts/power-on-after-failure.sh) does,
  and why it's model-gated.

| Model | Identifier | Method | Status | Report |
|-------|-----------|--------|--------|--------|
| Mac mini (Late 2014) | `Macmini7,1` | `setpci` — `00:1f.0` `0xa4` bit0 | ✅ verified | [macmini7,1.md](macmini7,1.md) |
| Beelink Mini S12 Pro | Intel N100 (AZW) | BIOS — *State After G3 → S0* | ✅ verified | [beelink-mini-s12-pro.md](beelink-mini-s12-pro.md) |

Legend: ✅ verified (physical plug-test passed) · 🟡 reported but unverified · ❔ unknown.

## Add your model
1. Find your identifier: `cat /sys/class/dmi/id/product_name`.
2. Locate the AfterG3 bit (see [`../docs/how-it-works.md`](../docs/how-it-works.md)).
3. **Physically test it** (see [`../docs/testing.md`](../docs/testing.md)).
4. Add a `case` to [`../scripts/power-on-after-failure.sh`](../scripts/power-on-after-failure.sh)
   and a report here (copy `macmini7,1.md`).
5. Open a PR — see [`../CONTRIBUTING.md`](../CONTRIBUTING.md).

We'd especially love coverage of the **Mac mini 2018 (`Macmini8,1`)** — a 6-core
box that makes a genuinely capable little server.
