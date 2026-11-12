# Changelog

## v0.1.0, 2026-11-12

First tagged release.

- `bootstrap.sh`: one-command setup. Installs build dependencies on Debian/Ubuntu where possible, builds both components into `dist/`, and prints the exact run command. A `--check` mode verifies the checkout and toolchain without building.
- Docker option: a `Dockerfile` that builds the client in a Debian image and runs the tunnel as its entrypoint, with the port forwards published to the host.
- README reworked around the one-command quickstart, with the full mechanism, evidence, and limitations kept below it.
- The client itself is unchanged from the proven build: patched stock OpenVPN (pipe device) plus the tunsocks userspace TCP/IP stack, pinned upstream commits, SOCKS5 on 127.0.0.1:1081 alongside every port forward. Proven end to end on HackTheBox Starting Point (Meow) from a VM with no usable kernel tunnel device and blocked UDP.
