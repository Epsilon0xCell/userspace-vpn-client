#!/usr/bin/env bash
# run.sh - launch the userspace OpenVPN client built by build.sh.
#
# Usage:
#   run.sh <profile.ovpn> <target-ip> <target-port> <local-port> [gateway] [netmask]
#   run.sh --stop
#
# The tunnel is the patched OpenVPN using a pipe device into tunsocks:
#   openvpn --config <profile> --script-security 2 \
#     --dev "|<tunsocks> -L 127.0.0.1:<local-port>:<target-ip>:<target-port> \
#            -D 127.0.0.1:1081 -n <netmask> -G <gateway>"
# tunsocks receives the other end of the pipe socketpair in VPNFD.
#
# Gateway and netmask come from the server PUSH reply (see the OpenVPN
# log after the first run). Defaults are the HackTheBox Starting Point
# values from the reference run: gateway 10.10.16.1, netmask
# 255.255.254.0.
#
# State: ./run/openvpn.log (client log), ./run/openvpn.pid (daemon PID).
# The profile is never printed, copied, or logged by this script.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIST_DIR="$REPO_DIR/dist"
RUN_DIR="$REPO_DIR/run"
PID_FILE="$RUN_DIR/openvpn.pid"
LOG_FILE="$RUN_DIR/openvpn.log"
SOCKS_ADDR="127.0.0.1:1081"

usage() {
    echo "usage: $0 <profile.ovpn> <target-ip> <target-port> <local-port> [gateway] [netmask]" >&2
    echo "       $0 --stop" >&2
    exit 2
}

if [ "${1:-}" = "--stop" ]; then
    if [ -f "$PID_FILE" ]; then
        pid="$(cat "$PID_FILE")"
        if kill "$pid" 2>/dev/null; then
            echo "run.sh: stopped openvpn (pid $pid)"
        else
            echo "run.sh: pid $pid not running, cleaning up pid file"
        fi
        rm -f "$PID_FILE"
    else
        echo "run.sh: no pid file at $PID_FILE, nothing to stop"
    fi
    exit 0
fi

[ $# -ge 4 ] && [ $# -le 6 ] || usage

PROFILE="$1"
TARGET_IP="$2"
TARGET_PORT="$3"
LOCAL_PORT="$4"
GATEWAY="${5:-10.10.16.1}"
NETMASK="${6:-255.255.254.0}"

[ -f "$PROFILE" ] || { echo "run.sh: profile not found: $PROFILE" >&2; exit 1; }

# Refuse placeholder profiles: a template is documentation, not a config.
# This also stops anyone launching the bundled example by accident.
if grep -qiE 'placeholder|replace[-_ ]with|example-vpn|your[-_ ]server' "$PROFILE"; then
    echo "run.sh: refusing to run: $PROFILE looks like a placeholder template, not a real profile" >&2
    exit 1
fi

# Light shape validation without printing any profile contents.
grep -q '^remote ' "$PROFILE" || { echo "run.sh: profile has no remote line, not an OpenVPN client profile" >&2; exit 1; }

[ -x "$DIST_DIR/openvpn" ] || { echo "run.sh: $DIST_DIR/openvpn missing, run ./build.sh first" >&2; exit 1; }
[ -x "$DIST_DIR/tunsocks" ] || { echo "run.sh: $DIST_DIR/tunsocks missing, run ./build.sh first" >&2; exit 1; }

case "$TARGET_PORT:$LOCAL_PORT" in
    *[!0-9:]*)
        echo "run.sh: ports must be numeric" >&2
        exit 1
        ;;
esac

if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    echo "run.sh: already running (pid $(cat "$PID_FILE")), stop it first: $0 --stop" >&2
    exit 1
fi

mkdir -p "$RUN_DIR"

PIPE_DEVICE="|$DIST_DIR/tunsocks -L 127.0.0.1:$LOCAL_PORT:$TARGET_IP:$TARGET_PORT -D $SOCKS_ADDR -n $NETMASK -G $GATEWAY"

echo "run.sh: starting tunnel, forward 127.0.0.1:$LOCAL_PORT -> $TARGET_IP:$TARGET_PORT, SOCKS5 on $SOCKS_ADDR"
"$DIST_DIR/openvpn" \
    --config "$PROFILE" \
    --script-security 2 \
    --dev "$PIPE_DEVICE" \
    --daemon \
    --log-append "$LOG_FILE" \
    --writepid "$PID_FILE" \
    --status "$RUN_DIR/status.txt" 10

sleep 2
if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    echo "run.sh: openvpn running (pid $(cat "$PID_FILE"))"
    echo "run.sh: log: $LOG_FILE"
    echo "run.sh: watch for 'Initialization Sequence Completed', then connect to 127.0.0.1:$LOCAL_PORT"
    echo "run.sh: stop with: $0 --stop"
else
    echo "run.sh: openvpn exited early, last log lines:" >&2
    tail -n 20 "$LOG_FILE" >&2 || true
    exit 1
fi
