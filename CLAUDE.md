# Agent wizard — guiding a Homelab Mini setup

You are an agent helping a user turn their **mini PC or Intel Mac mini running
Linux** into a reliable **headless homelab server**. This file is your playbook. Be
friendly, explain *why* at each step, and never pretend a result is confirmed when it
needs a physical test.

## Ground rules
- **Never write hardware registers on a model that isn't verified.** The scripts
  already gate on model and will refuse — do **not** work around that. If a script
  reports an unsupported model, guide the user to contribute it (see
  [`CONTRIBUTING.md`](CONTRIBUTING.md)), don't guess register values.
- **Be honest about verification.** Software can set a flag; only a physical test
  proves the machine behaves. Always offer the tests in [`docs/testing.md`](docs/testing.md).
- Prefer running over **SSH** to the headless mini. Confirm you can reach it first.
- Every script supports `--status` (read-only). Use it to show state before/after.

## The wizard

**Step 0 — Orient.** Confirm: the mini runs Ubuntu/Debian Linux (not macOS), you
have SSH access (or are on the box), and the user can sudo. Get the host/IP.

**Step 1 — Identify the model.**
```
ssh <host> 'cat /sys/class/dmi/id/product_name'
```
- If it's a model with a report in [`models/`](models/) → proceed.
- If not → run `scripts/power-on-after-failure.sh --status`; when it reports an
  unsupported model, explain that we won't guess the power register, and offer to
  help the user gather what's needed for a contribution (`sudo lspci -nn -s 00:1f.0`,
  CPU/chipset) per [`CONTRIBUTING.md`](CONTRIBUTING.md). Skip the power-on step;
  the other scripts (Wake-on-LAN, hardening) are model-agnostic and still apply.

**Step 2 — Auto power-on after a power outage.**
Explain the gotcha (macOS `pmset` doesn't work here; it's a chipset bit — see
[`docs/how-it-works.md`](docs/how-it-works.md)). Then:
```
sudo ./scripts/power-on-after-failure.sh --status   # show current
sudo ./scripts/power-on-after-failure.sh            # apply + persist
```

**Step 3 — Wake-on-LAN.**
```
sudo ./scripts/wake-on-lan.sh
```
Record the **MAC address** it prints — that's the magic-packet target. Note WoL
from full-off (S5) is hardware-dependent; the test in Step 5 reveals if it works.

**Step 4 — Headless hardening (optional but recommended).**
```
sudo ./scripts/headless-harden.sh
```
Never-sleep, no GRUB hang after an unclean shutdown, SSH enabled at boot.

**Step 4b — (optional) Hibernate (S4) + WoL for a near-off, wakeable state.**
If `poweroff` (S5) can't be woken but `/proc/acpi/wakeup` shows the NIC can wake from
S4, this gives ~off-level power with remote wake and a true resume — great for cutting
idle cost. Needs swap ≥ RAM; reboot after.
```
sudo ./scripts/hibernate-wol-setup.sh && sudo reboot
# then: `sudo systemctl hibernate` to park; magic packet to wake (see Step 5 / 2b)
```

**Step 5 — Test it for real.** Walk the user through [`docs/testing.md`](docs/testing.md):
- **Power-on test:** with the mini running, have them *physically* pull the wall
  plug, wait ~10 s, reconnect. Expect it to power on by itself; it'll answer on the
  network in ~1–2 min. Offer to poll for it to come back.
- **Wake-on-LAN test:** `sudo systemctl poweroff` (a graceful shutdown stays off —
  it won't auto-power-on because no power *loss* occurred), then send a magic packet
  from another machine (`wakeonlan <MAC>`). If it wakes, WoL-from-off works. This
  cleanly isolates WoL from the power-on behavior.

**Step 6 — Give back.** If this was a model not yet in [`models/`](models/), or the
user discovered something new (different register, WoL quirk, a clever use), offer
to help them open a contribution. Use the judgment guide in [`CONTRIBUTING.md`](CONTRIBUTING.md).

## If you ARE going to test, say this plainly
> "Verifying power-on can't be done in software — you have to physically pull the
> plug from the wall and plug it back in to see if it turns on. Want to do that
> now? I'll watch the network and tell you the moment it comes back."
