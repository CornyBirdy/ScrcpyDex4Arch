# Wireless DeX Research Spike (Experimental)

**Goal:** Determine whether a Linux PC can act as a receiver for the phone's own Wireless DeX button (Miracast over Wi-Fi Direct). **Status: unproven.** Nothing here is known to work. This is a feasibility check, not a feature.

Plain Miracast mirroring and DeX mode are different things. Mirroring a phone screen to a Linux sink is plausible with open-source tools. Whether a Linux sink can be accepted by the phone as a *DeX-capable* display is unknown, because the DeX-specific negotiation is not publicly documented.

## Step 1: Hardware probe

```bash
./scripts/miracast-probe.sh
```

The script installs `iw`, `pciutils`, and `usbutils` via `pacman` if they are missing (pass `--no-install` to skip that), then runs the checks.

The script is read-only and redacts MAC addresses, IP addresses, and SSIDs. If it reports no `P2P-GO` support, a Wi-Fi Direct sink is unlikely on that adapter, and a P2P-capable USB adapter would be needed.

## Step 2: Try the receiver (one script)

Install MiracleCast first (AUR): `yay -S miraclecast-git`. Then run:

```bash
./scripts/wireless-dex-sink.sh
```

The script releases the Wi-Fi adapter from NetworkManager (**your Wi-Fi on that adapter drops**), starts `miracle-wifid`, sets the friendly name, and runs the sink. Press `Ctrl+C` to stop; it restores NetworkManager and reconnects Wi-Fi. Use `--dry-run` to preview the commands, `--iface <name>` to pick an interface, and `--name <text>` to change the advertised name. If automatic link detection fails, it shows the `miracle-wifictl list` output and asks for the link number. The log is `./wireless-dex-sink.log` and contains MAC/IP data: redact before sharing.

On the phone, tap Wireless DeX (or Smart View) and look for `ScrcpyDeX-PC`.

Record which of these works: discovery, connection, video shown, and whether the phone enters DeX or only mirrors. The script was written from the tools' `--help-commands` output and tested only with stub binaries in a dry run, so command order may need adjustment on real hardware.

## Step 3: Capture the negotiation (only if the phone connects)

Capture on the P2P interface with `tcpdump -i <P2P_INTERFACE> -w session.pcap` (RTSP typically on TCP 7236). Before sharing a capture or notes, replace MAC addresses, IP addresses, device serials, and device names with placeholders (`<MAC>`, `<HOST_IP>`, `<DEVICE_SERIAL>`).

Questions the capture should answer:
- Which RTSP/WFD parameters does the phone request when the user chose Wireless DeX versus Smart View?
- Does the phone enable a desktop session, or only mirror?
- How is input from the PC returned (UIBC or another channel)?

## Legal note

Analysis must stay within the interoperability scope described in `LEGAL_AND_LICENSING.md`. Only capture traffic from your own devices.

## Outcomes to report

Share the redacted probe report and the result of each step in Step 2. That determines whether further work is worthwhile.
