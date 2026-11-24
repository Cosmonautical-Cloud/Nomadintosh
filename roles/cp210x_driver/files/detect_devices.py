"""List plugged-in USB devices that the CP210x driver supports.

Usage: detect_devices.py <vid:pid>[,<vid:pid>...]   (hex, e.g. 10c4:8a2a)

Prints a JSON list with one entry per matching device: its name, its
vendor:product ID, and whether macOS already gives it a serial port (an
IOSerialBSDClient anywhere under it, from this driver or Apple's own).
"""
import json
import plistlib
import subprocess
import sys


def has_serial_port(entry):
    if entry.get("IOObjectClass") == "IOSerialBSDClient":
        return True
    return any(has_serial_port(child) for child in entry.get("IORegistryEntryChildren", []))


def main():
    supported = {usb_id.lower() for usb_id in sys.argv[1].split(",") if usb_id}
    out = subprocess.run(
        ["/usr/sbin/ioreg", "-a", "-r", "-c", "IOUSBHostDevice", "-l"],
        check=True,
        capture_output=True,
    ).stdout
    devices = plistlib.loads(out) if out.strip() else []

    found = []
    for device in devices:
        vendor, product = device.get("idVendor"), device.get("idProduct")
        if vendor is None or product is None:
            continue
        usb_id = "%04x:%04x" % (vendor, product)
        if usb_id in supported:
            found.append({
                "id": usb_id,
                "name": device.get("USB Product Name") or device.get("IORegistryEntryName", ""),
                "serial": has_serial_port(device),
            })
    json.dump(found, sys.stdout)


if __name__ == "__main__":
    main()
