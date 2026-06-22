# Your VPC, in your closet 💸

> A cloud provider will happily rent you an always-on VM with a few cores, a few
> gigs of RAM, and an SSD for **$X–$Y a month, forever**. Or… you put an Intel Mac
> mini you already own in the closet and pay **about the price of a coffee per
> *year*** in electricity. Same always-on box. You own it. No bill, no egress
> fees, no one else's hands on your data. Call it your **VPC — Virtual Private
> Cloud — except it's in your closet.**

This page tracks the *real, measured* cost so the pitch isn't hand-waving.

## Measured running cost  *(placeholder — real data coming)*

We're putting a Mac mini on a metering smart plug to capture actual draw over time.
Until then, these are estimates to be replaced with measured values.

| Metric | Value | Source |
|--------|-------|--------|
| Idle power draw | _____ W | _(to measure)_ |
| Avg power draw (light server load) | _____ W | _(to measure)_ |
| kWh / month | _____ | _(to measure)_ |
| **Cost / month** | **$_____** | _(measured × your $/kWh)_ |
| **Cost / year** | **$_____** | |
| Electricity rate used | $_____ / kWh | _(your local rate)_ |
| Model under test | `Macmini7,1` (Late 2014) | |

> Ballpark before measurement: an Intel Mac mini idles around **6–12 W**, which at
> ~$0.17/kWh is **roughly $1–2 a month**. We'll replace this with the metered
> number.

## Cloud comparison  *(fill in current prices)*

| Option | Specs | Monthly | Yearly |
|--------|-------|---------|--------|
| Cloud VM (provider A) | ~2 vCPU / 4 GB / SSD | $_____ | $_____ |
| Cloud VM (provider B) | ~4 vCPU / 8 GB / SSD | $_____ | $_____ |
| **Mac mini in the closet** | the whole machine | **$_____** | **$_____** |

## How we measure
1. Put the mini on a metering smart plug (Tasmota / Kasa / eWeLink / a Kill-A-Watt).
2. Log idle draw and draw under your real workload for a representative period.
3. `kWh/month = avg_watts × 24 × 30 / 1000`; `cost = kWh × your $/kWh`.
4. Update the tables above and send a PR — bonus points for a screenshot of the
   plug's energy graph.
