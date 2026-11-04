#!/usr/bin/env bash
# ==============================================================================
# ScrcpyDeX - One-step installer for Arch-based distros (EndeavourOS, Arch, ...)
#
#   Inside a clone:      ./install-arch.sh
#   From scratch:        bash <(curl -fsSL https://raw.githubusercontent.com/CornyBirdy/ScrcpyDex4Arch/main/install-arch.sh)
#
# Installs build tools, builds the pacman package from this repository,
# installs it (with the udev rule), then runs the built-in diagnostics.
# ==============================================================================
set -euo pipefail

REPO_URL="https://github.com/CornyBirdy/ScrcpyDex4Arch.git"

if [ "$EUID" -eq 0 ]; then
    echo "[ERROR] Run as a normal user, not root (makepkg refuses to run as root). sudo is used when needed." >&2
    exit 1
fi
if ! command -v pacman >/dev/null 2>&1; then
    echo "[ERROR] pacman not found. This installer is for Arch-based distributions." >&2
    exit 1
fi

# Locate the repository, or clone it if the script was piped/downloaded alone.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/packaging/arch/PKGBUILD" ]; then
    REPO_DIR="$SCRIPT_DIR"
else
    REPO_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/scrcpydex-src"
    echo "[1/4] Fetching source into $REPO_DIR ..."
    sudo pacman -S --needed --noconfirm git
    if [ -d "$REPO_DIR/.git" ]; then
        git -C "$REPO_DIR" pull --ff-only
    else
        git clone --depth 1 "$REPO_URL" "$REPO_DIR"
    fi
fi

echo "[2/4] Installing build tools..."
sudo pacman -S --needed --noconfirm base-devel

echo "[3/4] Building and installing the package (dependencies are installed by makepkg)..."
cd "$REPO_DIR/packaging/arch"
makepkg -si --noconfirm

echo "[4/4] Running diagnostics..."
adb start-server >/dev/null 2>&1 || true
scrcpydex-cli doctor || true

cat <<'MSG'

Done. Next steps:
  1. On the phone: enable Developer options > USB debugging.
  2. Plug the phone in (replug if it was already connected) and accept the debugging prompt.
  3. Launch "ScrcpyDeX" from the application menu, or run: scrcpydex
MSG
