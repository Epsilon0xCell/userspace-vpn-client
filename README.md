# Userspace OpenVPN Client for TUN-Less Environments

An OpenVPN client setup that works where OpenVPN normally cannot: machines with no usable `/dev/net/tun`, no `CAP_NET_ADMIN`, blocked UDP, and no permission to create kernel network devices. Sandboxed agent VMs, locked-down containers, CI runners, restricted lab cells.

It is not a reimplementation. It runs the real OpenVPN protocol code and replaces exactly one thing: the kernel tunnel device.

## The problem

Stock OpenVPN assumes three things a restricted environment often does not have:

1. A usable tunnel device. Creating one calls `ioctl(TUNSETIFF)` on `/dev/net/tun`, which needs `CAP_NET_ADMIN`. Without it the client completes the full TLS handshake, receives its pushed routes, and then dies: `ERROR: Cannot ioctl TUNSETIFF tun: Operation not permitted`.
2. UDP transport. Many sandboxes and egress policies block or intercept UDP entirely, so the first packet never leaves.
3. Root-level network configuration. Even past the tunnel device, `ifconfig` and route installation need privileges the cell may not grant.

The session itself is never the problem. The plumbing after the handshake is.

## How it works

Two upstream projects, pinned to exact commits, do the heavy lifting. This repo is the glue: build script, launcher, docs.

```
  OpenVPN server (TCP profile)
        |
        |  TLS control channel + data channel, over TCP
        |
  openvpn-tunpipe (patched stock OpenVPN 2.6)
        |
        |  --dev "|tunsocks ..." : the device is a pipe, not a kernel tun.
        |  openvpn creates a socketpair, hands one end to the child
        |  process in the VPNFD environment variable, and skips all
        |  kernel ifconfig and route commands.
        |
  tunsocks (lwIP TCP/IP stack in userspace)
        |
        |  Raw IP packets in and out over VPNFD.
        |  lwIP terminates TCP in userspace, no kernel stack involved.
        |
        +-- -L 127.0.0.1:<local>:<target-ip>:<target-port>
        |     Local port forward into the VPN.
        |
        +-- -D 127.0.0.1:1081
              SOCKS5 proxy reaching any address on the VPN.
```

Because the protocol code is stock OpenVPN, everything the server throws at it works: tls-crypt, dynamic tls-crypt keying, legacy CBC data channels, pushed routes, the lot. A clean-room client has to reimplement every one of those details, and one missed detail is a silent data channel (see Alternatives Considered).

## Quickstart

```sh
./build.sh
./run.sh /path/to/profile.ovpn 10.129.58.140 23 2323
# in another terminal:
telnet 127.0.0.1 2323
./run.sh --stop
```

`build.sh` clones the two upstream repos at their pinned commits, builds both, and drops the binaries in `./dist/`. Build dependencies are listed in the header of `build.sh` (Debian/Ubuntu package names). Nothing is installed system-wide by the scripts, and no upstream code is vendored into this repo.

`run.sh` takes `<profile.ovpn> <target-ip> <target-port> <local-port> [gateway] [netmask]`. The gateway and netmask come from the server's PUSH reply (watch the OpenVPN log on your first run). The defaults are the values HackTheBox Starting Point pushed in the reference run below: gateway `10.10.16.1`, netmask `255.255.254.0`. Your profile stays yours: `run.sh` never prints it, and `.gitignore` excludes `*.ovpn` on purpose.

## Usage examples

Single port forward to a lab box (the Meow pattern):

```sh
./run.sh ~/profiles/lab.ovpn 10.129.58.140 23 2323
telnet 127.0.0.1 2323
```

A different service, same shape:

```sh
./run.sh ~/profiles/lab.ovpn 10.129.58.141 21 2121
ftp 127.0.0.1 2121
```

SOCKS mode for wider work: every `run.sh` launch also starts a SOCKS5 proxy at `127.0.0.1:1081` riding the same tunnel, so tools that speak SOCKS can reach anything on the VPN:

```sh
curl --socks5-hostname 127.0.0.1:1081 http://10.129.58.140/
nmap --proxy socks5://127.0.0.1:1081 ...   # where supported
```

## Field note: telnet and IAC negotiation

This one cost real debugging time, so it is written down. Some telnet servers send only telnet IAC negotiation bytes on connect (12 bytes in the observed case: IAC DO for terminal type, window size, speed, display location) and then wait for the client's negotiation replies before printing any login prompt.

Drive a forwarded telnet port with a real telnet client, or a library that negotiates (Python `telnetlib`, for example). A raw socket script that just reads will see those 12 bytes and then silence, and the silence looks exactly like a dead tunnel. It is not the tunnel. Packet counters and a packet tap proved the data channel was flowing in both directions while raw scripts sat there seeing nothing.

## Evidence

Proven end to end on HackTheBox Starting Point, 2026-11-04, from a VM with no usable kernel tunnel device and blocked UDP, against the official HTB TCP profile with zero profile edits:

- OpenVPN log: `Initialization Sequence Completed`
- Tunnel address assigned: `10.10.16.148`, gateway `10.10.16.1`, data channel `AES-256-CBC`
- Port forward live: `127.0.0.1:2323` to the Meow instance at `10.129.58.140:23`
- Telnet session: logged in as `root` with no password prompt, read files on the box, clean logout
- Data channel byte counters grew in both directions (the control channel alone cannot do that)

No profile contents or key material appears in this repo. The full engagement writeup draft lives in `docs/meow-writeup.md`, and it does include the flag value read on the Meow box in that run, because the draft is staged for the private writeups repo.

## Limitations

- Use a TCP transport profile in restricted cells. The whole point is surviving environments where UDP is blocked; a UDP profile may still work elsewhere, but TCP is the tested path.
- Performance is lab-grade. A userspace lwIP stack behind a pipe will not win throughput contests against a kernel tunnel. It is built for access, not bandwidth.
- One profile, one tunnel at a time. `run.sh` keeps a single PID file, a single log, and a fixed SOCKS port (1081), and it refuses to start while an instance is already running. Stop the tunnel with `./run.sh --stop` before starting a different profile. Other hosts on the same VPN are reachable through the SOCKS proxy without a second tunnel.
- The launcher writes its PID file and logs under `./run/`. Stop it with `./run.sh --stop`.

## Alternatives considered

A pure Go OpenVPN client (n0madic/go-openvpn, with its openvpn2socks SOCKS bridge) was built and tested first. It is an elegant design: no CGo, no tunnel device, control channel fully working, session up, AES-256-GCM negotiated, SOCKS listening. Against the HTB server its data channel was a black hole: zero inbound data packets ever arrived, not even the server's keepalive pings, and sessions force-reconnected on a stuck-data watchdog every 21 seconds. The likely cause is a protocol feature the library deliberately does not implement (dynamic tls-crypt keying appears in the stock client's session flags and not in that client's). That failure is exactly why this repo builds on the stock protocol code instead of a reimplementation. Details in `docs/meow-writeup.md`.

## License and attribution

The glue in this repo (scripts and documentation) is MIT licensed, see `LICENSE`. The upstream projects it builds are separately licensed and are not distributed here: `build.sh` fetches them at install time. Full attribution, pinned commits, and license details are in `NOTICE.md`. Summary: OpenVPN is GPLv2 with an OpenSSL linking exception, and that license covers the patched client binary you build; tunsocks is licensed under the lwIP license, a BSD-style 3-clause license.
