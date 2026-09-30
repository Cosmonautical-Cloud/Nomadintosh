# nfs_mounts

Mounts the NAS's NFS exports persistently via a LaunchDaemon, alongside (not replacing) the existing SMB mounts each job manages itself.

## What it does

1. Renders a small shell script (`nfs-mount-watchdog.sh`) that checks each share in `nfs_mounts_shares` and mounts it if it isn't already.
2. Installs a `LaunchDaemon` (`cloud.cosmonautical.nfs-mount-watchdog`) that runs that script on boot (`RunAtLoad`) and every `nfs_mounts_watchdog_interval` seconds thereafter (`StartInterval`) — it's re-spawned fresh each interval, not a single long-running process.
3. Each mount uses `deadtimeout={{ nfs_mounts_deadtimeout }}`: if the NAS becomes unresponsive for that long, the kernel force-unmounts it. The next watchdog run notices it's missing and remounts it — unattended recovery in roughly `deadtimeout + one interval`, no manual intervention. (Mounting NFS requires root on macOS — there's no user-mount sysctl equivalent on this OS version — which is why this is a system LaunchDaemon rather than something a Nomad task can do itself.)

## Why separate mount points

Each share mounts under `/Volumes/NFS/<name>` (e.g. `/Volumes/NFS/Cosmonautical`), not `/Volumes/<name>`. Other jobs still mount the same shares over SMB at the plain path via their own `mount_share()` logic — colliding would break their `mount | grep smbfs` checks. The share name itself still matches its SMB counterpart exactly; only the parent directory differs. Jobs migrate to the NFS path individually (Lidarr first, for the per-file latency win over SMB) rather than all switching at once.

## Configuration

`nas_host` / `nas_user` live in [`playbooks/group_vars/all.yml`](../../playbooks/group_vars/all.yml) (shared with the Nomad variable `cosmonautical/nas`, which job templates read via `nomadVar` — Ansible has no bridge into Nomad's variable store, so it's duplicated rather than hardcoded per-role).

Override `nfs_mounts_shares` (a list of `{name, export, mount_point}`) to add/remove shares. Defaults to Cosmonautical, Books, ROMs, and Music, each pointed at `/var/nfs/shared/<name>` on the NAS.
