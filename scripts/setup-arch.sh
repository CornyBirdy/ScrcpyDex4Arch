#!/usr/bin/env bash
# ==============================================================================
# ScrcpyDeX - Arch Linux Setup (Arch, EndeavourOS, Manjaro, CachyOS)
# Installs runtime dependencies and the udev rule needed for USB access.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if ! command -v pacman >/dev/null 2>&1; then
    echo "[ERROR] pacman not found. This script targets Arch-based distributions." >&2
    exit 1
fi

if [ "$EUID" -eq 0 ]; then
    SUDO=""
else
    SUDO="sudo"
fi

echo "[1/4] Installing packages (adb, scrcpy, VA-API tools, runtime libraries)..."
$SUDO pacman -S --needed --noconfirm \
    android-tools scrcpy libva-utils mesa intel-media-driver \
    fontconfig libx11 libice libsm dotnet-sdk-8.0

echo "[2/4] Installing udev rule (uses 'uaccess'; no plugdev group on Arch)..."
$SUDO install -Dm644 "$REPO_ROOT/packaging/arch/69-scrcpydex.rules" /etc/udev/rules.d/69-scrcpydex.rules
$SUDO udevadm control --reload-rules
$SUDO udevadm trigger --subsystem-match=usb

echo "[3/4] Verifying scrcpy version (>= 2.4 required)..."
SCRCPY_VER="$(scrcpy --version 2>&1 | head -n 1 | awk '{print $2}')"
MIN="2.4"
if [ "$(printf '%s\n' "$MIN" "$SCRCPY_VER" | sort -V | head -n1)" = "$MIN" ]; then
    echo "      scrcpy $SCRCPY_VER OK"
else
    echo "      [WARN] scrcpy $SCRCPY_VER is older than $MIN" >&2
fi

echo "[4/4] Checking connected devices..."
adb start-server >/dev/null 2>&1 || true
adb devices || true

echo ""
echo "Setup finished. Reconnect your phone if it was already plugged in."
echo "Run the app with:  ./scripts/run-linux.sh"
echo "Run diagnostics:   dotnet run --project src/ScrcpyDex.Cli -- doctor"
