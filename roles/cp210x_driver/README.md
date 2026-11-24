# cp210x_driver

Installs Silicon Labs' [CP210x USB to UART Bridge VCP driver](https://www.silabs.com/developer-tools/usb-to-uart-bridge-vcp-drivers) (6.0.3), a DriverKit system extension. USB Zigbee and Z-Wave coordinators built on a CP210x bridge need it for a `/dev/cu.*` serial device. macOS's built-in Silicon Labs driver doesn't match all of them. The Nortek HUSBZB-1 (`10c4:8a2a`) is one it misses.

The deploy playbook runs this role for hosts in the [`iot`](../../README.md#magic-groups) group. There's nothing to set. Within that group it only installs the driver where it's needed: a host with a supported stick plugged in that has no serial port for it yet. A stick that macOS's own driver already handles, such as a Sonoff ZBDongle-P (`10c4:ea60`), is left alone.

## What it does

1. Runs `files/detect_devices.py` on the host. It walks `ioreg`'s USB devices for any whose vendor:product ID is in `cp210x_driver_usb_ids`, and checks whether each one already has a serial port (an `IOSerialBSDClient` under it).
2. Carries on only if one of them has no serial port, or the driver app is already installed. A host that has the driver keeps it updated and active even with the stick unplugged. Otherwise it says why it skipped and stops.
3. Copies `files/SiLabsUSBDriverDisk.dmg` to the host and checks it against `cp210x_driver_dmg_sha256`.
4. Mounts it and copies `CP210xVCPDriver.app`, the extension's host app, into `/Applications`. This is all the DMG's own installer app does on macOS 10.15 and later. The role skips this step when that version is already installed.
5. If `systemextensionsctl list` doesn't show `com.silabs.cp210x` at that version as `[activated enabled]`, it launches the app in `ansible_user`'s GUI session (`launchctl asuser`) with an `install` argument, the way the DMG's installer does. That's what asks macOS to activate the extension. Launched without it, the app just idles.
6. Warns while the extension still needs approval, and lists the host's serial devices.

## Approving the extension

Without MDM, macOS activates a third-party driver extension only after someone approves it on the Mac's own screen. After the first run:

1. Log in to the GUI as `ansible_user`. The app can't launch without a GUI session.
2. Approve **CP210xVCPDriver** in System Settings → General → Login Items & Extensions → Driver Extensions. On macOS 14 and earlier it's Privacy & Security → Allow. macOS can also ask, on the desktop, to enable the app's extension. Allow that too (seen on macOS 15.8).
3. Re-run with `--tags cp210x_driver`. The warning should be gone and the device should be listed.

If nothing is waiting for approval, run `open -n /Applications/CP210xVCPDriver.app --args install` on the Mac and check again. Opening it from Finder doesn't pass `install`.

The extension names each port after its device. A HUSBZB-1 shows up as `/dev/cu.GoControl_zigbee` and `/dev/cu.GoControl_zwave`, with no serial-number suffix.

## Variables

| Variable | Default | Description |
|---|---|---|
| `cp210x_driver_version` | `6.0.3` | Version of the app inside the DMG. Used to skip the install and to find the extension in `systemextensionsctl list` |
| `cp210x_driver_usb_ids` | _(210 IDs, `defaults/main/usb_ids.yml`)_ | USB `vendor:product` IDs (hex) the driver supports. Generated from the driver extension's `IOKitPersonalities` |
| `cp210x_driver_dmg` | `SiLabsUSBDriverDisk.dmg` | DMG under `files/` |
| `cp210x_driver_dmg_sha256` | _(the shipped DMG's)_ | Expected sha256 of the DMG |
| `cp210x_driver_app` | `/Applications/CP210xVCPDriver.app` | Where the host app goes. It has to be in `/Applications` |
| `cp210x_driver_extension_id` | `com.silabs.cp210x` | Bundle ID of the driver extension |
| `cp210x_driver_staging_dir` | `~/Library/Caches/cloud.cosmonautical.cp210x_driver` | Where the DMG is copied on the host |

## Why the DMG is in the repo

silabs.com returns HTTP 403 to scripted downloads, so a role can't fetch it at deploy time. Homebrew's `silicon-labs-vcp-driver` cask fails the same way. To update, download `Mac_OSX_VCP_Driver.zip` in a browser and replace `files/SiLabsUSBDriverDisk.dmg` with the DMG inside it. Then update `cp210x_driver_version` (the `CFBundleShortVersionString` of `Install CP210x VCP Driver.app/Contents/Resources/CP210xVCPDriver.app`) and `cp210x_driver_dmg_sha256`, and regenerate `defaults/main/usb_ids.yml` from the new driver extension, with the DMG mounted at `$M`:

```zsh
plutil -convert json -o - "$M/Install CP210x VCP Driver.app/Contents/Resources/CP210xVCPDriver.app/Contents/Library/SystemExtensions/com.silabs.cp210x.dext/Info.plist" \
  | jq -r '[.IOKitPersonalities[] | "\(.idVendor) \(.idProduct)"] | unique | .[]' \
  | while read v p; do printf '  - "%04x:%04x"\n' $v $p; done | sort -u
```

## Removing it

Run `uninstaller.sh` from the DMG, or delete `/Applications/CP210xVCPDriver.app` from Finder. macOS deactivates the extension when its host app goes to the Trash.
