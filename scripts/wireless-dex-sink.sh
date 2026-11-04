#!/usr/bin/env bash
# ==============================================================================
# ScrcpyDeX - Wireless DeX receiver experiment (Miracast sink via MiracleCast)
#
# EXPERIMENTAL / UNVERIFIED. Turns this PC into a Wi-Fi Direct Miracast receiver
# so the phone's "Wireless DeX" / "Smart View" button can find it. Whether
# Samsung's DeX mode (not just screen mirroring) is accepted is unknown.
#
# WARNING: your Wi-Fi adapter is taken away from NetworkManager while this runs,
# so your internet connection on that adapter drops. It is restored when the
# script exits (Ctrl+C, error, or normal end). Use a wired connection if you can.
#
# Requires: miraclecast-git (AUR), networkmanager, iw. Run as a normal user;
# sudo is used where root is needed.
#
# Usage:  ./wireless-dex-sink.sh [--iface wlan0] [--name ScrcpyDeX-PC] [--audio] [--dry-run]
#         (audio is off by default because the sink runs as root; --audio enables it)
# Log:    ./wireless-dex-sink.log   (contains MAC/IP data: redact before sharing)
# ==============================================================================
set -uo pipefail

IFACE=""
NAME="ScrcpyDeX-PC"
DRY=0
LOG="./wireless-dex-sink.log"
AUDIO=0
WIFID_PID=""
NM_CHANGED=0

while [ $# -gt 0 ]; do
    case "$1" in
        --iface) IFACE="${2:-}"; shift 2 ;;
        --name)  NAME="${2:-}"; shift 2 ;;
        --audio) AUDIO=1; shift ;;
        --dry-run) DRY=1; shift ;;
        -h|--help) sed -n '2,21p' "$0"; exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

say()  { printf '[wireless-dex] %s\n' "$*"; }
die()  { printf '[wireless-dex][ERROR] %s\n' "$*" >&2; exit 1; }
run()  { if [ "$DRY" -eq 1 ]; then echo "  (dry-run) $*"; else "$@"; fi; }
have() { command -v "$1" >/dev/null 2>&1; }

[ "$EUID" -ne 0 ] || die "Run as a normal user, not root (the video player needs your desktop session)."

for bin in miracle-wifid miracle-wifictl miracle-sinkctl nmcli iw; do
    have "$bin" || die "'$bin' not found. Install: yay -S miraclecast-git   and   sudo pacman -S networkmanager iw"
done

# --- Pick the Wi-Fi interface --------------------------------------------------
if [ -z "$IFACE" ]; then
    IFACE="$(iw dev | awk '$1=="Interface"{print $2; exit}')"
fi
[ -n "$IFACE" ] || die "No Wi-Fi interface found. Pass one with --iface <name>."
say "Using Wi-Fi interface: $IFACE"

# --- Restore everything on exit ------------------------------------------------
cleanup() {
    trap - EXIT INT TERM
    say "Cleaning up and restoring Wi-Fi..."
    if [ -n "$WIFID_PID" ]; then
        sudo kill "$WIFID_PID" 2>/dev/null || true
    fi
    sudo pkill -x miracle-wifid 2>/dev/null || true
    if [ "$NM_CHANGED" -eq 1 ]; then
        nmcli device set "$IFACE" managed yes 2>/dev/null || true
        sleep 2
        nmcli device connect "$IFACE" >/dev/null 2>&1 || true
        nmcli radio wifi on >/dev/null 2>&1 || true
    fi
    say "Done. If Wi-Fi does not come back, run: sudo systemctl restart NetworkManager"
}
trap cleanup EXIT INT TERM

# --- Give the adapter to MiracleCast ------------------------------------------
say "Wi-Fi on $IFACE will drop now. Releasing it from NetworkManager..."
if [ "$DRY" -eq 0 ]; then NM_CHANGED=1; fi
run nmcli device set "$IFACE" managed no
run sleep 1

say "Starting miracle-wifid (log: $LOG)..."
if [ "$DRY" -eq 1 ]; then
    echo "  (dry-run) sudo miracle-wifid > $LOG 2>&1 &"
else
    : > "$LOG"
    sudo sh -c "exec miracle-wifid >> '$LOG' 2>&1" &
    WIFID_PID=$!
    sleep 3
    if ! pgrep -x miracle-wifid >/dev/null 2>&1; then
        say "miracle-wifid did not stay running. Last log lines:"
        tail -n 15 "$LOG" >&2
        die "Could not start miracle-wifid."
    fi
fi

# --- Find the MiracleCast link id ---------------------------------------------
LINK_ID=""
if [ "$DRY" -eq 0 ]; then
    LIST_OUT="$(sudo miracle-wifictl list 2>&1 || true)"
    echo "$LIST_OUT"
    # Try to find the row mentioning our interface and take its numeric id.
    LINK_ID="$(echo "$LIST_OUT" | awk -v i="$IFACE" '$0 ~ i { for (n=1;n<=NF;n++) if ($n ~ /^[0-9]+$/) { print $n; exit } }')"
    if [ -z "$LINK_ID" ]; then
        printf '[wireless-dex] Could not detect the link id automatically. Enter the link number from the list above: '
        read -r LINK_ID
    fi
    [ -n "$LINK_ID" ] || die "No link id given."
else
    LINK_ID="<LINK_ID>"
fi
say "Using link id: $LINK_ID"

# The control tools need root. Friendly-name failures are non-fatal; the rest are.
run sudo miracle-wifictl set-friendly-name "$LINK_ID" "$NAME" || say "Could not set Wi-Fi friendly name (continuing)."
run sudo miracle-sinkctl set-friendly-name "$LINK_ID" "$NAME" || say "Could not set sink friendly name (continuing)."
run sudo miracle-sinkctl set-managed "$LINK_ID" yes || die "miracle-sinkctl set-managed failed. See messages above and $LOG."

cat <<MSG

[wireless-dex] Starting receiver "$NAME" (discovery not yet confirmed).
  On the phone: open the quick panel and tap "Wireless DeX" (or Smart View),
  then pick "$NAME" from the list. Keep this window open.
  Press Ctrl+C here to stop and restore Wi-Fi.

MSG

# Foreground: runs the sink on the link until you press Ctrl+C.
# Root is required; keep the desktop session variables so the video window can open.
run sudo --preserve-env=DISPLAY,XAUTHORITY,XDG_RUNTIME_DIR,WAYLAND_DISPLAY \
    miracle-sinkctl --audio "$AUDIO" run "$LINK_ID"
RC=$?
if [ "$RC" -ne 0 ]; then
    say "miracle-sinkctl exited with code $RC. Last miracle-wifid log lines:"
    tail -n 15 "$LOG" >&2 || true
fi
