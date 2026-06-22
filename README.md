# Homelab Mini

**Turn a cheap mini PC — or an old Intel Mac mini — into a bulletproof, always-on headless homelab server.**

Mini PCs (Beelink, Intel N100 boxes, NUCs) and out-of-support Intel Mac minis make
near-perfect homelab servers: small, silent, power-sipping (~6–12 W idle), with a
real SSD and gigabit Ethernet. But running one *headless* on Linux surfaces
genuinely non-obvious quirks — starting with the most important one: **does it come
back on by itself after a power cut?** This repo collects the **scripts, reports,
and tested per-model fixes** to make any little box behave like a proper server.

> The flagship example: **automatically powering back on after a power outage.** On
> a normal PC BIOS that's one menu toggle — but a Mac mini *hides* the setting, so
> you have to flip a chipset register from Linux. We figured both out, tested them on
> real hardware, and wrote them up. See [`docs/how-it-works.md`](docs/how-it-works.md).

---

## 💸 Your VPC, in your closet

A cloud provider will happily rent you an always-on VM with a few cores, a few gigs
of RAM, and an SSD for **$X–$Y a month, forever**. Or… you put an Intel Mac mini you
*already own* in the closet and pay **about the price of a coffee per *year*** in
electricity. Same always-on box. You own it. No monthly bill, no egress fees, nobody
else's hands on your data. Call it your **VPC — Virtual Private Cloud — except it's
in your closet.**

> 📏 **Measured cost: `$_____ /month`** *(placeholder — we're putting a mini on a
> metering smart plug to get the real number).* Ballpark: an Intel Mac mini idles
> around **6–12 W** ≈ **~$1–2/month**. Live tracker + cloud price comparison:
> [`reports/closet-vpc-cost.md`](reports/closet-vpc-cost.md).

---

## Two ways to use this

### 🧙 Guided (recommended): open this repo in [Claude Code](https://claude.com/claude-code)
There's an agent wizard baked into [`CLAUDE.md`](CLAUDE.md). Open the repo and
say *"set up my headless Mac mini."* The agent will detect your model, run the
right scripts over SSH, explain each step, and walk you through the **physical
tests** that prove it actually works. It will refuse to touch hardware registers
on a model that hasn't been verified.

### 🛠️ Manual: run the scripts yourself
On the mini (running Ubuntu/Debian), as a user with sudo:

```bash
git clone https://github.com/dallanwagz/homelab-mini.git
cd homelab-mini

sudo ./scripts/power-on-after-failure.sh    # auto power-on after power loss
sudo ./scripts/wake-on-lan.sh               # configure + persist Wake-on-LAN
sudo ./scripts/headless-harden.sh           # never-sleep, no GRUB hang, SSH on boot
sudo ./scripts/hibernate-wol-setup.sh       # hibernate (S4) + WoL = near-off, wakeable
```

Each script is **model-aware where it needs to be, idempotent, and has a
`--status` mode** to just report current state without changing anything.

---

## What's here

| Path | What |
|------|------|
| [`scripts/`](scripts/) | The tools: power-on-after-failure, Wake-on-LAN, headless hardening, hibernate+WoL |
| [`docs/how-it-works.md`](docs/how-it-works.md) | The technical deep-dive: ACPI power states, the AfterG3 bit, why `pmset` fails on Linux |
| [`docs/testing.md`](docs/testing.md) | **How to actually test this** — the physical pull-the-plug test, and using graceful shutdown to cleanly test Wake-on-LAN |
| [`models/`](models/) | Per-model registry of verified register values + reports |
| [`reports/`](reports/) | Community case studies — what people built with their revived minis |
| [`CONTRIBUTING.md`](CONTRIBUTING.md) | What we want, and how to know if your contribution fits |

## Tested models

| Model | Identifier | Method | Status | Report |
|-------|-----------|--------|--------|--------|
| Mac mini (Late 2014) | `Macmini7,1` | `setpci` register write | ✅ verified | [report](models/macmini7,1.md) |
| Beelink Mini S12 Pro | Intel N100 (AZW) | BIOS toggle | ✅ verified | [report](models/beelink-mini-s12-pro.md) |
| *yours?* | | | | [add it →](CONTRIBUTING.md) |

> **Not just Mac minis.** The goal — *power back on after an outage* — applies to any
> small headless box. Machines with a normal PC BIOS (like the Beelink) just flip a
> menu setting; Mac minis hide it, so we patch the chipset bit from Linux. Both are
> documented here.

If your Mac model isn't listed, the power-on script will **stop and tell you** rather
than guess at a register that could hang your machine — and point you here to
contribute the values once you've found and tested them.

## Ethos

What this project believes, and what makes a contribution fit:

1. **Tested on real hardware, or it doesn't ship.** The whole value here is trust. A
   wrong power register can hang someone's machine — so verified findings are gold, and
   unverified ones must say so plainly. Honesty about *how you know* beats being clever.
2. **Keep good hardware out of landfills.** Apple (and everyone) drops support long
   before the silicon stops being useful. Give it a second life instead.
3. **You should own your compute.** A box in your closet beats renting one forever — no
   monthly bill, no egress fees, nobody else's hands on your data.
4. **Document the gotchas, not just the happy path.** The non-obvious firmware quirks
   (power-after-outage, WoL S-states, boot hangs) are the entire point — write them down.
5. **Friendly to humans *and* agents.** Setup is a guided wizard; contribution rules are
   explicit enough that an AI agent can tell whether something belongs and how to prove it.

If your idea is in scope, you ran it on real hardware, and you're honest about what you
verified — it fits. See [`CONTRIBUTING.md`](CONTRIBUTING.md).

## Scope

**In scope:** repurposing small/cheap/old hardware — mini PCs *and* Intel Mac minis
— as headless Linux homelab servers: power behavior, wake, boot reliability,
sensors/fans, running cost, and write-ups of what works.

**Out of scope:** running macOS, Hackintosh on non-Apple hardware, or anything that
isn't about giving small hardware a useful second life on Linux.

## ⚠️ Disclaimer

Some scripts here write low-level chipset/PCI registers. They are conservative
(masked writes, model gating, sanity checks) and tested on the models listed, but
firmware is firmware: **use at your own risk.** Always read what a script does and
run the physical tests in [`docs/testing.md`](docs/testing.md) to confirm behavior
on *your* machine.

## License

[MIT](LICENSE).
