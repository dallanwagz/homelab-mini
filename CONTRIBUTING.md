# Contributing to Homelab Mini

Thanks for helping other people get a second life out of small hardware — a mini PC
or an old Intel Mac mini. This project only stays useful if contributions are
**honest about what's been tested**. That's the one thing we care about most.

## Our mission
A trustworthy, community-verified home for **repurposing small hardware — mini PCs
and Intel Mac minis — as headless Linux homelab servers** — scripts, per-model
settings/register values, testing methods, and real-world case studies.

## What we're looking for
- ✅ **New model support** — verified register values / behavior for a Mac mini
  model not yet covered, with a report of how you tested it.
- ✅ **Tested solutions & scripts** for headless use cases (power, wake, boot
  reliability, fans/sensors, remote management) that you've run on real hardware.
- ✅ **Reports / case studies** — what you built, what worked, what bit you.
- ✅ **Fixes & clarifications** to existing scripts and docs.

## What we are *not*
- ❌ Untested register values or "this should work" guesses presented as verified.
  (Wrong power registers can hang a machine — see "Verification" below.)
- ❌ macOS-only tips, Hackintosh-on-PC content, or anything not about giving small
  hardware a useful second life on Linux.

## Should I open a contribution? (decision guide — for humans **and** agents)

Ask, in order:

1. **Is it in scope?** (headless Linux on a mini PC or Intel Mac mini) — if no, stop.
2. **Did I run it on real hardware?**
   - *Yes, and I have results* → open a **Pull Request** (new model, script, or report).
   - *No / only partially* → open an **Issue** instead, clearly labeled unverified,
     so others can help test. Don't submit unverified hardware writes as a PR.
3. **Is it a new model's power register?** → it **must** include the physical
   pull-the-plug test result (see [`docs/testing.md`](docs/testing.md)). No exceptions —
   this is the one place a wrong value is dangerous.
4. **Am I an AI agent doing this on a user's behalf?** → see the agent note below.

If you can answer "in scope + tested + honest about how" — yes, please contribute.

### If you are an AI agent
- Only open an **upstream PR** when you have **hardware-confirmed** results from the
  user's actual machine (e.g. the user physically did the power test and reported the
  outcome). Otherwise open an Issue marked unverified.
- Always include the evidence: model string, `lspci` output, the exact register/bit,
  and the physical test result with what was observed.
- Never invent a register value to "fill in" an unsupported model. Refusing is correct.

## How to add a new model

1. On the mini: `cat /sys/class/dmi/id/product_name` (e.g. `Macmini8,1`).
2. Run `sudo ./scripts/power-on-after-failure.sh --status`. On an unknown model it
   prints what to collect.
3. Find the LPC controller and power register: `sudo lspci -nn -s 00:1f.0` (and full
   `sudo lspci -nn` if `1f.0` is absent). See [`docs/how-it-works.md`](docs/how-it-works.md)
   for what the AfterG3 bit is and how to locate it.
4. **Test it physically** per [`docs/testing.md`](docs/testing.md). Confirm power-on
   after a real plug-pull.
5. Add a `case` entry in `scripts/power-on-after-failure.sh` with your model's
   `PCI_DEV` / `REG` / `BIT_MASK`, and add a report at `models/<identifier>.md`
   (copy the structure of [`models/macmini7,1.md`](models/macmini7,1.md)).
6. Open a PR. The PR template will ask how you tested.

## PR checklist
- [ ] In scope (headless Intel Mac mini on Linux)
- [ ] Ran on real hardware; described the model and how I tested
- [ ] Hardware/register changes include the physical test result
- [ ] Unverified claims are labeled as such (or moved to an Issue)
- [ ] Scripts stay idempotent and keep a `--status` mode

## Be decent
Be kind and assume good faith. We're all just trying to keep good hardware out of
landfills.
