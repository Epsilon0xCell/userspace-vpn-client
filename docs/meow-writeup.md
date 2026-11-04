# Meow (HackTheBox Starting Point, Tier 0): Writeup Draft

> Staging draft for the private writeups repo (Epsilon0xCell/HTB-WRITEUPS), path `StartingPoint/Tier0/Meow/README.md`. This copy is staged inside the userspace-vpn-client repo because the tunnel work below is the real story of this run. The root flag is included per the private-repo standard.

- Target: Meow, 10.129.58.140 (instance IP, ephemeral)
- Date: 2026-11-04
- Result: root shell, flag captured and verified twice live

## Recon

Standard Starting Point flow: connect to the lab VPN, ping the instance to confirm reachability, then a service scan.

```
nmap -sV 10.129.58.140
```

One service that matters:

```
23/tcp open  telnet
```

Telnet, in 2026, on an internet-era lab box. That is the whole attack surface and the whole vulnerability.

## Key insight

The box offers telnet login as `root` with no password at all. Not a weak password, not a default credential to guess: connect, type `root` at the login prompt, and the account lands directly on a root shell with no password prompt. Unauthenticated remote root, by configuration.

## The tunnel problem (the real story of this run)

This run was executed from a sandboxed VM with three hard constraints:

1. UDP egress blocked outright, so the standard UDP VPN profile could not send its first packet.
2. No usable kernel tunnel device: `/dev/net/tun` exists but `ioctl(TUNSETIFF)` returns `Operation not permitted`, and the process holds no `CAP_NET_ADMIN`. Stock OpenVPN with the official TCP profile completed the entire TLS handshake, verified the HTB certificates, received `PUSH_REPLY` (tunnel address 10.10.16.148, routes including 10.129.0.0/16), and then died at tunnel device creation.
3. No root-level network configuration available to fix either of the above.

The solution, now published as the companion repo this draft is staged in: run a patched stock OpenVPN (ValdikSS/openvpn-tunpipe, branch `tun_pipe`, commit `bf90fcd`) whose device is a pipe instead of a kernel tunnel, and hand the raw IP packets to a userspace TCP/IP stack (russdill/tunsocks, commit `4e4ff86`, lwIP based). tunsocks exposes a local port forward and a SOCKS5 proxy on loopback. No kernel device is ever created, no routes are installed, nothing needs `CAP_NET_ADMIN`.

```
./build.sh
./run.sh profile.ovpn 10.129.58.140 23 2323
```

The equivalent core invocation inside `run.sh`:

```
openvpn --config profile.ovpn --script-security 2 \
  --dev "|tunsocks -L 127.0.0.1:2323:10.129.58.140:23 -D 127.0.0.1:1081 -n 255.255.254.0 -G 10.10.16.1"
```

Log evidence: `Initialization Sequence Completed`, data channel `AES-256-CBC`, and OpenVPN status counters growing in both directions on the data channel. The official HTB TCP profile was used with zero edits.

## Exploitation, exact commands in order

```
telnet 127.0.0.1 2323
```

(127.0.0.1:2323 is the tunsocks forward to 10.129.58.140:23 through the tunnel. Driven with a negotiating telnet client; see Dead Ends for why that detail matters.)

```
Meow login: root
(no password prompt)
root@Meow:~# ls
flag.txt  snap
root@Meow:~# cat flag.txt
b40abdfe23665f766f9c61ecba8a4c19
root@Meow:~# exit
```

The MOTD confirmed the target on login: Ubuntu 20.04.2 LTS, eth0 address 10.129.58.140. The flag was read twice in the same session, identical both times: `b40abdfe23665f766f9c61ecba8a4c19`.

## Why it worked

Two independent failures composed. Operationally, telnet was left enabled and reachable, a plaintext, unauthenticated-by-design service. On the account side, `root` accepted login with no password, so the first reachable service was also a direct root shell. No exploit code, no race, no misconfiguration hunting: the intended login path is the vulnerability.

And on our side, the run only exists because the tunnel problem was solved without a kernel device. The box was never the hard part. Reaching it from a TUN-less cell was.

## Detection

- Alert on any successful telnet login, and on `root` telnet logins specifically (auth logs: a session opened for root over telnet with no preceding password authentication event is a high-signal anomaly worth paging on).
- Flag unauthenticated telnet in asset and configuration scans: any host with 23/tcp open should fail baseline. Vulnerability scanners have flagged this pattern for decades (for example, "Telnet Server Present" and blank-password account checks); an environment where it survives has a scanning or remediation gap, not a detection gap.
- Network side: telnet is plaintext. Any credential or session content crossing the wire in cleartext is observable by every on-path device, which is itself a detection and forensics gift when it happens.
- For lab and VPN environments specifically: log VPN-side connections to legacy management ports (23, 21, 513) per client tunnel address, so one compromised lab account cannot quietly sweep them.

## Fix

- Disable telnet entirely. There is no hardened telnet configuration worth running.
- Use SSH with key-only authentication (`PasswordAuthentication no`, `PermitRootLogin prohibit-password` or `no`), and manage access through named accounts plus sudo instead of a shared direct root login.
- If a legacy device genuinely cannot speak SSH, put it behind a jump host and restrict the legacy port to that host only.
- Audit for blank-password accounts as a standing control, not a one-time cleanup.

## MITRE ATT&CK mapping

- **T1078 Valid Accounts**: the primary technique. The `root` account is a valid account, and logging in with it through the service's intended path is use of a valid account, not exploitation of a software flaw. It maps cleanly and needs no stretching.
- **T1021 Remote Services**: the access vector. Telnet is a remote service used for interactive login and lateral-style access; ATT&CK lists Telnet under the remote services attackers abuse for exactly this pattern. T1021 is the closest fit for the "how we got in" step, T1078 for the "what we used" step.

## Dead ends, honestly

- **UDP profile**: dead on the first packet, egress UDP blocked in the cell. Switching to the official TCP profile fixed transport.
- **Stock OpenVPN on TCP**: full handshake, PUSH received, then `Cannot ioctl TUNSETIFF tun: Operation not permitted`. A direct Python TUNSETIFF test failed identically. The kernel path was never available.
- **Pure Go userspace client (n0madic/go-openvpn, openvpn2socks)**: session up, AES-256-GCM negotiated, SOCKS listening, and a data channel black hole: zero inbound data packets ever, keepalives included, reconnect every 21 seconds on a stuck-data watchdog. Prime suspect: dynamic tls-crypt keying, present in the stock client's session flags, deliberately not implemented by that library. Abandoned for the stock-code pipe approach, which worked.
- **Raw socket scripts through the working tunnel**: silence after connect, which looked like another dead data channel. A packet tap between OpenVPN and tunsocks proved otherwise: SYN out, SYN-ACK back, then exactly 12 bytes of telnet IAC negotiation (IAC DO terminal type, window size, speed, display location) and a server patiently waiting for negotiation replies a raw socket never sends. Switching to a negotiating telnet client (Python telnetlib) produced the login prompt immediately. Lesson recorded in the client repo's README: silence from a forwarded telnet port is a client bug until proven otherwise.
- **tunsocks `-p` flag**: one run died instantly because the pcap argument is compiled out without libpcap and falls through to usage. Dropping the flag fixed it. Not a profile or tunnel problem.

## Timeline

- 2026-11-04, afternoon CT: environment rebuilt, official TCP profile verified, handshake proven with stock client, TUN blocker confirmed twice.
- Userspace sprint 1: Go client, session up, data black hole, root cause narrowed to unimplemented dynamic tls-crypt keying.
- Userspace sprint 2: tunpipe plus tunsocks built, tunnel up with a live data channel, IAC silence diagnosed via packet tap, telnet session driven with a negotiating client, flag captured and verified twice, writeup and client repo staged.
