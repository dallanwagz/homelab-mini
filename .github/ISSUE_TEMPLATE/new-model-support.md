---
name: New model support
about: Help us add (or verify) a Mac mini model
title: "[model] Macmini?,? — power-on support"
labels: ["new-model"]
---

## Model
- Identifier (`cat /sys/class/dmi/id/product_name`):
- CPU / chipset generation:
- macOS-era name (e.g. "Mac mini 2018"):

## LPC controller
<!-- paste output -->
```
sudo lspci -nn -s 00:1f.0
```

## Power-on (AfterG3) findings — if you've investigated
- Register / bit you think controls it:
- `setpci -s 0:1f.0 0xa4.b` current value:
- Tried clearing the bit? value after:

## Did you physically test it?  (see docs/testing.md)
- [ ] Yes — pulled AC, reconnected, and it **powered on by itself**
- [ ] Yes — but it did **not** power on
- [ ] Not yet (this is an unverified report — that's fine, just say so)

## Anything else
<!-- Wake-on-LAN behavior, quirks, etc. -->
