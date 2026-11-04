# Wireless DeX Research Spike (Experimental)

**Goal:** Determine whether a Linux PC can act as a receiver for the phone's own Wireless DeX button (Miracast over Wi-Fi Direct). **Status: unproven.** Nothing here is known to work. This is a feasibility check, not a feature.

Plain Miracast mirroring and DeX mode are different things. Mirroring a phone screen to a Linux sink is plausible with open-source tools. Whether a Linux sink can be accepted by the phone as a *DeX-capable* display is unknown, because the DeX-specific negotiation is not publicly documented.

## Step 1: Hardware probe

```bash
./scripts/miracast-probe.sh
```

The script installs `iw`, `pciutils`, and `usbutils` via `pacman` if they are missing (pass `--no-install` to skip that), then runs the checks.

The script is read-only and redacts MAC addresses, IP addresses, and SSIDs. If it reports no `P2P-GO` support, a Wi-Fi Direct sink is unlikely on that adapter, and a P2P-capable USB adapter would be needed.

## Step 2: Try an open-source Miracast sink

MiracleCast is available from the AUR (`miraclecast-git`). Its sink support is experimental and it needs `wpa_supplicant` to be controllable without NetworkManager managing the same adapter. Expect to stop NetworkManager or `iwd` for that interface while testing, which drops normal Wi-Fi on it.

1. Start `miracled` and `miracle-wifid`.
2. Use `miracle-sinkctl` to make the PC discoverable.
3. On the phone, open Smart View (or the Wireless DeX tile) and look for the PC.

Record which of these steps works: discovery, connection, video shown.

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
