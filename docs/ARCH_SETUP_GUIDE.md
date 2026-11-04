# Arch Linux Setup Guide (Arch, EndeavourOS, Manjaro, CachyOS)

**Status:** Packaging and diagnostics were added for Arch-based systems. They have not been run on a real Arch or EndeavourOS installation, and no .NET build or `makepkg` run was done while preparing the change. Please report results through the compatibility report template.

**Target:** EndeavourOS (XFCE, X11) and other x86_64 Arch-based distributions.

---

## 1. One-step install

```bash
./install-arch.sh
```

The script installs `base-devel`, builds the package, installs it with `makepkg -si`, and runs `scrcpydex-cli doctor`. It must be run as a normal user. Like the rest of this port, it has not been run on a real Arch system.

## 1b. Install manually with makepkg

```bash
sudo pacman -S --needed base-devel git
git clone https://github.com/CornyBirdy/ScrcpyDex4Arch.git
cd ScrcpyDex4Arch/packaging/arch
makepkg -si
```

The PKGBUILD builds the checked-out repository, so no tarball download is needed. It installs:

| Path | Content |
|---|---|
| `/usr/bin/scrcpydex` | Avalonia GUI (self-contained .NET 8) |
| `/usr/bin/scrcpydex-cli` | CLI (`doctor`, `devices`, `start`, `stop`, ...) |
| `/usr/share/scrcpydex/server/scrcpydex-server.jar` | DeX activation server |
| `/usr/lib/udev/rules.d/69-scrcpydex.rules` | USB access rule for Samsung (`04e8`) and generic ADB (`18d1`) |

Dependencies are resolved by pacman: `android-tools` (adb), `scrcpy` (the Arch repository version is above the required 2.4), `mesa`, `fontconfig`, `libx11`, `libice`, `libsm`. Build-time only: `dotnet-sdk-8.0`.

## 2. Run from source instead

```bash
./scripts/setup-arch.sh      # installs packages and the udev rule
./scripts/run-linux.sh       # GUI (add --cli for the CLI)
```

`scripts/setup-linux.sh` forwards to `setup-arch.sh` when `pacman` is present and `apt-get` is not.

## 3. USB permissions on Arch

Arch has no `plugdev` group. The udev rule in `packaging/arch/69-scrcpydex.rules` uses the `uaccess` tag, which lets `systemd-logind` grant the active local session access to the device. No group change is needed for a normal desktop login. If `adb devices` reports `no permissions`:

1. Confirm the rule is loaded: `udevadm control --reload-rules && udevadm trigger`, then replug the phone.
2. As an alternative, install `android-udev` and add your user to `adbusers`: `sudo usermod -aG adbusers $USER`, then log out and in.

## 4. XFCE / X11 notes

- XFCE on EndeavourOS runs on X11 by default, which is the configuration the upstream project tested (on Linux Mint). `scrcpy` uses SDL and works directly on X11.
- Pressing `Left Alt` releases mouse capture back to the window manager.
- Hardware decoding: install `libva-utils` and the driver for your GPU, then check with `vainfo`.
  - Intel: `intel-media-driver`
  - AMD: current `mesa` includes VA-API; older releases need `libva-mesa-driver`
  - NVIDIA: scrcpy falls back to software decoding unless a VA-API bridge is configured.

## 5. Verify

```bash
scrcpydex-cli doctor
```

The diagnostics detect Arch-based systems through `/etc/os-release` and print `pacman` remediation commands. On Arch the missing `plugdev` group is reported as informational, not a warning.

## 6. Known limitations

- Samsung DeX behaviour depends on the phone firmware, not on the host distro. See the compatibility matrix in the README.
- The PKGBUILD downloads NuGet packages at build time and needs network access.
