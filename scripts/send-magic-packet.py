#!/usr/bin/env python3
"""
send-magic-packet.py  --  homelab-mini

Send a Wake-on-LAN magic packet. No external dependencies; runs on macOS & Linux.
WoL is layer-2, so run this from a host on the SAME broadcast domain as the target.

Usage:
  ./send-magic-packet.py <MAC> [--broadcast 192.168.1.255] [--source 192.168.1.50]

  <MAC>          target NIC, e.g. aa:bb:cc:dd:ee:ff
  --broadcast    target subnet's broadcast (default 255.255.255.255). Prefer the
                 target subnet broadcast (e.g. 192.168.1.255) for reliability.
  --source       local source IP to bind to -- forces egress out the right NIC.
                 IMPORTANT on macOS: bind to your WIRED IP that's on the target's
                 subnet, or the packet may leave via Wi-Fi/Tailscale and never
                 reach the target's segment (a classic false "WoL doesn't work").
  --ports        comma list (default 9,7).  --repeat  bursts per dst/port (default 3).

Verify it worked by pinging the target until it answers, e.g.:
  while ! ping -c1 -t2 <ip>; do sleep 5; done; echo UP
"""
import argparse, socket


def main():
    ap = argparse.ArgumentParser(description="Send a Wake-on-LAN magic packet.")
    ap.add_argument("mac", help="target MAC, e.g. aa:bb:cc:dd:ee:ff")
    ap.add_argument("--broadcast", default="255.255.255.255")
    ap.add_argument("--source", help="local source IP to bind (forces egress NIC)")
    ap.add_argument("--ports", default="9,7")
    ap.add_argument("--repeat", type=int, default=3)
    a = ap.parse_args()

    mb = bytes.fromhex(a.mac.replace(":", "").replace("-", ""))
    if len(mb) != 6:
        raise SystemExit(f"bad MAC: {a.mac}")
    pkt = b"\xff" * 6 + mb * 16  # magic packet: 6x FF + 16x MAC

    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
    if a.source:
        try:
            s.bind((a.source, 0))
        except OSError as e:
            print(f"warn: could not bind to {a.source}: {e} (packet may egress the wrong NIC)")

    dsts = list(dict.fromkeys([a.broadcast, "255.255.255.255"]))
    ports = [int(p) for p in a.ports.split(",")]
    n = 0
    for dst in dsts:
        for port in ports:
            for _ in range(a.repeat):
                s.sendto(pkt, (dst, port)); n += 1
    print(f"sent {n} magic packets to {', '.join(dsts)} ports {a.ports} "
          f"via {a.source or 'default route'}")


if __name__ == "__main__":
    main()
