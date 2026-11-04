#!/usr/bin/env bash
# build.sh - fetch and build the two upstream components of the userspace
# OpenVPN client, at pinned commits, and stage the binaries in ./dist/.
#
# Build dependencies (Debian/Ubuntu package names):
#   git, build-essential (gcc, make), autoconf, automake, libtool,
#   pkg-config, libssl-dev, liblzo2-dev, liblz4-dev, libpam0g-dev,
#   libevent-dev
# On a restricted VM where a full apt update is impractical, install the
# same list through whatever narrow package route the machine allows.
#
# Layout:
#   src/openvpn-tunpipe   ValdikSS/openvpn-tunpipe, branch tun_pipe
#   src/tunsocks          russdill/tunsocks, master, with submodules
#   dist/openvpn          built patched OpenVPN binary
#   dist/tunsocks         built tunsocks binary
#
# Idempotent: existing clones at the right commits are reused, make is
# incremental. All temp state lives under the repo or /var/tmp, never
# /tmp (on the reference machine /tmp is a tiny, full tmpfs).
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$REPO_DIR/src"
DIST_DIR="$REPO_DIR/dist"

TUNPIPE_URL="https://github.com/ValdikSS/openvpn-tunpipe.git"
TUNPIPE_BRANCH="tun_pipe"
TUNPIPE_COMMIT="bf90fcd141996c7f6ca10f74ebebf1160f8db5fc"

TUNSOCKS_URL="https://github.com/russdill/tunsocks.git"
TUNSOCKS_COMMIT="4e4ff8682053412145930b8daf2c55d357cf1e44"

export TMPDIR="${TMPDIR:-/var/tmp}"
mkdir -p "$SRC_DIR" "$DIST_DIR" "$TMPDIR"

clone_pinned() {
    # $1 = dest dir, $2 = repo url, $3 = commit, $4 = branch (optional)
    local dest="$1" url="$2" commit="$3" branch="${4:-}"
    if [ -d "$dest/.git" ] && [ "$(git -C "$dest" rev-parse HEAD)" = "$commit" ]; then
        echo "build.sh: reusing $dest at $commit"
        return 0
    fi
    rm -rf "$dest"
    if [ -n "$branch" ]; then
        git clone --branch "$branch" "$url" "$dest"
    else
        git clone "$url" "$dest"
    fi
    git -C "$dest" checkout "$commit"
}

echo "build.sh: fetching openvpn-tunpipe ($TUNPIPE_COMMIT)"
clone_pinned "$SRC_DIR/openvpn-tunpipe" "$TUNPIPE_URL" "$TUNPIPE_COMMIT" "$TUNPIPE_BRANCH"

echo "build.sh: fetching tunsocks ($TUNSOCKS_COMMIT)"
clone_pinned "$SRC_DIR/tunsocks" "$TUNSOCKS_URL" "$TUNSOCKS_COMMIT"
git -C "$SRC_DIR/tunsocks" submodule update --init --recursive

echo "build.sh: building openvpn-tunpipe"
cd "$SRC_DIR/openvpn-tunpipe"
if [ ! -f configure ]; then
    autoreconf -i
fi
if [ ! -f Makefile ]; then
    ./configure --disable-dco --disable-unit-tests
fi
make -j"$(nproc)"
cp src/openvpn/openvpn "$DIST_DIR/openvpn"

echo "build.sh: building tunsocks"
cd "$SRC_DIR/tunsocks"
if [ ! -f configure ]; then
    ./autogen.sh
fi
if [ ! -f Makefile ]; then
    ./configure
fi
make
cp tunsocks "$DIST_DIR/tunsocks"

echo "build.sh: done"
"$DIST_DIR/openvpn" --version | head -n 1
ls -l "$DIST_DIR"
