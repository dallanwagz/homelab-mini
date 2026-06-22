<!-- Thanks for contributing to Homelab Mini! -->

## What does this PR do?


## Type
- [ ] New model support (register values + report)
- [ ] New / improved script
- [ ] Report or case study
- [ ] Docs / fix

## How was it tested? (required for anything touching hardware)
<!-- Be specific and honest. "Read back correctly" is NOT a pass for power behavior. -->
- Model (`cat /sys/class/dmi/id/product_name`):
- For power-on changes — **physical plug-pull test result** (pulled AC, reconnected, did it power on?):
- For Wake-on-LAN — magic-packet result (from S5? from S3?):
- Other:

## Checklist
- [ ] In scope (headless Intel Mac mini on Linux)
- [ ] I ran this on real hardware
- [ ] Hardware/register changes include the physical test result above
- [ ] Anything unverified is clearly labeled as such
- [ ] Scripts stay idempotent and keep a `--status` mode
