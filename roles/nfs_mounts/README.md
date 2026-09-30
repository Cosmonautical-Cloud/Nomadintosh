# nfs_mounts

Mounts the NAS's NFS exports persistently via a LaunchDaemon, alongside (not replacing) the existing SMB mounts each job manages itself.

## What it does

1. Renders a small shell script (`nfs-mount-watchdog.sh`) that checks each share in `nfs_mounts_shares` and mounts it if it isn't already.
2. Installs a `LaunchDaemon` (`cloud.cosmonautical.nfs-mount-watchdog`) that runs that script on boot (`RunAtLoad`) and every `nfs_mounts_watchdog_interval` seconds thereafter (`StartInterval`) — it's re-spawned fresh each interval, not a single long-running process.
3. Each mount uses `deadtimeout={{ nfs_mounts_deadtimeout }}`: if the NAS becomes unresponsive for that long, the kernel force-unmounts it. The next watchdog run notices it's missing and remounts it — unattended recovery in roughly `deadtimeout + one interval`, no manual intervention. (Mounting NFS requires root on macOS — there's no user-mount sysctl equivalent on this OS version — which is why this is a system LaunchDaemon rather than something a Nomad task can do itself.)

## Why the mount point matches the old SMB path

Each share mounts at the same path its SMB counterpart used to (`/Volumes/<name>`, e.g. `/Volumes/Cosmonautical`) — this only works on a host once nothing there still mounts that share over SMB at the same path, since two different filesystems can't occupy one mount point at once. Hosts adopt this one at a time: drain, reboot (clears any lingering SMB mount cleanly), then this LaunchDaemon mounts NFS fresh at the same path on boot, and jobs that used to SMB-mount it themselves are updated to just wait for the NFS mount instead. Because of this, `volume_mount_path` isn't overridable per-share — every share on a host has to land under the same root, or this migration-in-place trick doesn't work.

`nfs_mounts_shares` is deliberately opt-in — the role default is `[]`, no shares — for the same reason: turning it on for a host before that host's SMB-using jobs have all migrated would try to mount NFS on top of a path still in use over SMB.

## Configuration

`nas_host` / `nas_user` live in [`playbooks/group_vars/all.yml`](../../playbooks/group_vars/all.yml) (shared with the Nomad variable `cosmonautical/nas`, which job templates read via `nomadVar` — Ansible has no bridge into Nomad's variable store, so it's duplicated rather than hardcoded per-role).

Each `nfs_mounts_shares` entry only needs `share_export_path`; the mount point is always `volume_mount_path` (`/Volumes`) + `/<name>`, with `<name>` being the final path component of `share_export_path`:

```yaml
nfs_mounts_shares:
  - share_export_path: /var/nfs/shared/Cosmonautical   # mounts at /Volumes/Cosmonautical
  - share_export_path: /var/nfs/shared/Jellify          # mounts at /Volumes/Jellify
```

## Defaults

| Variable | Default | Why |
|---|---|---|
| `nfs_mounts_shares` | `[]` | Opt-in per host/group — see above |
| `volume_mount_path` | `/Volumes` | Parent directory every share mounts under, matching the SMB paths these shares replace |
| `nfs_mounts_deadtimeout` | `30` | Seconds an unresponsive mount is tolerated before the kernel force-unmounts it; the watchdog then notices it's gone and remounts — worst-case unattended recovery is roughly this plus one `nfs_mounts_watchdog_interval` |
| `nfs_mounts_watchdog_interval` | `30` | Seconds between watchdog checks |
| `nfs_mounts_version` | `3` | Pinned rather than negotiated — the UNAS Pro only speaks NFSv3 (confirmed 2026-09-21) |
| `nfs_mounts_rsize` / `nfs_mounts_wsize` | `65536` | Practical max macOS's `mount_nfs` will do for NFSv3 (default negotiates down to 32768) — doesn't help once the NAS's own disk I/O is the bottleneck under concurrent load (confirmed 2026-09-24), but a safe, cheap thing to raise |
| `nfs_mounts_timeo` | `100` | RPC retransmit timeout in tenths of a second, up from macOS's default of 10 (1.0s) — too aggressive under concurrent-load contention (confirmed 2026-09-24/25), triggering redundant retransmits onto an already-struggling NAS; stays well under `nfs_mounts_deadtimeout` so a genuinely dead NAS is still detected promptly |
