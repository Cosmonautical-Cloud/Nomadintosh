# nfs_mounts

Mounts the NAS's NFS exports persistently via a LaunchDaemon, alongside (not replacing) the existing SMB mounts each job manages itself.

## What it does

1. Renders a small shell script (`nfs-mount-watchdog.sh`) that checks each share in `nfs_mounts_shares` and mounts it if it isn't already.
2. Installs a `LaunchDaemon` (`cloud.cosmonautical.nfs-mount-watchdog`) that runs that script on boot (`RunAtLoad`) and every `nfs_mounts_watchdog_interval` seconds thereafter (`StartInterval`) — it's re-spawned fresh each interval, not a single long-running process.
3. Each mount uses `deadtimeout={{ nfs_mounts_deadtimeout }}`: if the NAS becomes unresponsive for that long, the kernel force-unmounts it. The next watchdog run notices it's missing and remounts it — unattended recovery in roughly `deadtimeout + one interval`, no manual intervention. (Mounting NFS requires root on macOS — there's no user-mount sysctl equivalent on this OS version — which is why this is a system LaunchDaemon rather than something a Nomad task can do itself.)

## Why the mount point matches the old SMB path

Each share mounts at the same path its SMB counterpart used to (`/Volumes/<name>`, e.g. `/Volumes/Cosmonautical`) — this only works on a host once nothing there still mounts that share over SMB at the same path, since two different filesystems can't occupy one mount point at once. Hosts adopt this one at a time: drain, reboot (clears any lingering SMB mount cleanly), then this LaunchDaemon mounts NFS fresh at the same path on boot, and jobs that used to SMB-mount it themselves are updated to just wait for the NFS mount instead.

## Configuration

`nas_host` / `nas_user` live in [`playbooks/group_vars/all.yml`](../../playbooks/group_vars/all.yml) (shared with the Nomad variable `cosmonautical/nas`, which job templates read via `nomadVar` — Ansible has no bridge into Nomad's variable store, so it's duplicated rather than hardcoded per-role).

`nfs_mounts_shares` (a list of `{name, export, mount_point?}`) is deliberately opt-in per host — the role default is `[]`, no shares. `mount_point` is optional on each entry: when omitted, it defaults to `nfs_mounts_default_dir` (`/Volumes`) + `/<name>`, so an inventory source (e.g. a Semaphore variable group) can list a share as just `{name, export}`:

```yaml
nfs_mounts_shares:
  - name: Cosmonautical         # explicit mount_point
    export: /var/nfs/shared/Cosmonautical
    mount_point: /Volumes/Cosmonautical
  - name: Jellify                # defaults to /Volumes/Jellify
    export: /var/nfs/shared/Jellify
```
