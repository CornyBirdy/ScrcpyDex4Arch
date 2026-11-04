#!/usr/bin/env bash
# ==============================================================================
# ScrcpyDeX - Wireless DeX / Miracast sink feasibility probe (read-only)
#
# Checks whether this machine can act as a Wi-Fi Direct (P2P) Miracast sink.
# Single entry point: installs the small diagnostic tools it needs (iw, pciutils,
# usbutils) on pacman systems if missing, then runs the checks. It changes no
# network settings. The report is redacted (MAC/IP/SSID).
# Output: ./miracast-probe-report.txt   (use --no-install to skip package install)
# ==============================================================================
set -uo pipefail

INSTALL=1
if [ "${1:-}" = "--no-install" ]; then INSTALL=0; shift; fi
OUT="${1:-./miracast-probe-report.txt}"

redact() {
    sed -E \
        -e 's/([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}/<MAC>/g' \
        -e 's/([0-9]{1,3}\.){3}[0-9]{1,3}/<IP>/g' \
        -e 's/(SSID|ssid)[: =]+.*/\1 <SSID>/'
}

ensure_tools() {
    [ "$INSTALL" -eq 1 ] || return 0
    command -v pacman >/dev/null 2>&1 || return 0
    local missing=()
    have iw || missing+=(iw)
    have lspci || missing+=(pciutils)
    have lsusb || missing+=(usbutils)
    if [ "${#missing[@]}" -gt 0 ]; then
        echo "Installing diagnostic tools: ${missing[*]}" >&2
        if [ "$EUID" -eq 0 ]; then
            pacman -S --needed --noconfirm "${missing[@]}" >&2 || true
        else
            sudo pacman -S --needed --noconfirm "${missing[@]}" >&2 || true
        fi
    fi
}

section() { printf '\n=== %s ===\n' "$1"; }
have() { command -v "$1" >/dev/null 2>&1; }

ensure_tools

{
    echo "ScrcpyDeX Miracast probe - $(date -u +%Y-%m-%dT%H:%M:%SZ)"

    section "Distro / kernel"
    grep -E '^(PRETTY_NAME|ID|ID_LIKE)=' /etc/os-release 2>/dev/null
    uname -r

    section "Wireless interfaces (iw dev)"
    if have iw; then iw dev 2>&1; else echo "iw not installed (sudo pacman -S iw)"; fi

    section "P2P support (iw list)"
    if have iw; then
        iw list 2>&1 | grep -E 'Wiphy|P2P-client|P2P-GO|P2P-device|Supported interface modes' -A12 \
            | grep -E 'Wiphy|P2P|interface modes' || echo "No P2P entries found"
    fi

    section "Wi-Fi driver / chipset"
    if have lspci; then lspci -nnk 2>/dev/null | grep -iA3 -E 'network|wireless'; fi
    if have lsusb; then lsusb 2>/dev/null | grep -iE 'wireless|wlan|802\.11|wi-?fi'; fi

    section "Network managers"
    for svc in NetworkManager iwd wpa_supplicant systemd-networkd; do
        printf '%s: ' "$svc"; systemctl is-active "$svc" 2>/dev/null || echo "not found"
    done
    if have wpa_supplicant; then wpa_supplicant -v 2>&1 | head -n 1; fi

    section "Miracast tooling"
    for bin in miracled miracle-wifid miracle-sinkctl gst-launch-1.0 ffplay vlc; do
        if have "$bin"; then echo "found: $bin"; else echo "missing: $bin"; fi
    done

    section "Firewall"
    if have nft; then echo "nftables present"; fi
    if have ufw; then echo "ufw present"; fi
    echo "Miracast/RTSP sink port typically 7236 (TCP) on the P2P interface."

    section "Result summary"
    if ! have iw; then
        echo "Inconclusive: 'iw' is not installed. Run: sudo pacman -S iw, then re-run this script."
    elif iw list 2>/dev/null | grep -q 'P2P-GO'; then
        echo "Driver reports P2P-GO: Wi-Fi Direct sink is plausible (not yet verified)."
    else
        echo "No P2P-GO reported: Wi-Fi Direct sink is unlikely on this adapter."
        echo "A USB adapter with P2P support may be needed."
    fi
} 2>&1 | redact | tee "$OUT"

echo ""
echo "Report written to: $OUT (MAC/IP/SSID redacted; review before sharing)."
