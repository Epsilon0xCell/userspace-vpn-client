#!/usr/bin/env bash
# bootstrap.sh - one-command setup for the userspace OpenVPN client.
#
#   ./bootstrap.sh           install build dependencies (Debian/Ubuntu, via apt)
#                            where possible, then build both components into ./dist/
#   ./bootstrap.sh --check   verify the checkout and the toolchain only; build nothing
#
# After it finishes:
#   ./run.sh /path/to/profile.ovpn <target-ip> <target-port> <local-port>
#
# Nothing is installed system-wide except the optional apt packages, and the
# build itself stays inside this repo (./src for sources, ./dist for binaries).
set -euo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_DIR"

DEPS_APT="git build-essential autoconf automake libtool pkg-config libssl-dev liblzo2-dev liblz4-dev libpam0g-dev libevent-dev"
TOOLS="git gcc make autoconf automake libtoolize pkg-config"

check_tools() {
  local missing=0 t
  for t in $TOOLS; do
    if ! command -v "$t" >/dev/null 2>&1; then echo "bootstrap: missing tool: $t"; missing=1; fi
  done
  return $missing
}

if [ "${1:-}" = "--check" ]; then
  for s in build.sh run.sh bootstrap.sh; do bash -n "$s" && echo "bootstrap: syntax ok: $s"; done
  [ -f examples/profile-template.ovpn ] && echo "bootstrap: example profile present"
  if check_tools; then echo "bootstrap: toolchain complete"; else
    echo "bootstrap: toolchain incomplete. On Debian/Ubuntu: sudo apt-get install -y $DEPS_APT"; exit 1; fi
  echo "bootstrap: check passed"
  exit 0
fi

if ! check_tools; then
  if command -v apt-get >/dev/null 2>&1; then
    SUDO=""; [ "$(id -u)" -ne 0 ] && SUDO="sudo"
    echo "bootstrap: installing build dependencies via apt"
    export DEBIAN_FRONTEND=noninteractive
    $SUDO apt-get update -qq
    $SUDO apt-get install -y -qq $DEPS_APT
  else
    echo "bootstrap: install the build dependencies for your system first (see build.sh header), then re-run" >&2
    exit 1
  fi
fi

# Restricted networks often block the git:// transport (port 9418), and one
# upstream submodule uses it. Rewrite that host to the project's official
# GitHub mirror over https, passed through the environment so it also
# reaches submodule clones and needs no writes to the user's git config.
export GIT_CONFIG_COUNT=1
export GIT_CONFIG_KEY_0="url.https://github.com/lwip-tcpip/lwip.git.insteadOf"
export GIT_CONFIG_VALUE_0="git://git.sv.gnu.org/lwip.git"

./build.sh

echo
echo "bootstrap: done. Binaries:"
ls -l dist/
echo
echo "Start a tunnel:"
echo "  ./run.sh /path/to/profile.ovpn <target-ip> <target-port> <local-port>"
echo "Every launch also opens a SOCKS5 proxy on 127.0.0.1:1081. Stop with: ./run.sh --stop"
