# nfs_mounts

Mounts the NAS's NFS exports persistently via a LaunchDaemon, alongside (not replacing) the existing SMB mounts each job manages itself.

## What it does

1. Renders a small shell script (`nfs-mount-watchdog.sh`) that checks each share in `nfs_mounts_shares` and mounts it if it isn't already.
2. Installs a `LaunchDaemon` (label `nfs_mounts_watchdog_label`, defaults to `cloud.cosmonautical.nfs-mount-watchdog`) into `launch_daemons_dir` (defaults to `/Library/LaunchDaemons`, defined in [`playbooks/group_vars/all.yml`](../../playbooks/group_vars/all.yml)) that runs that script on boot (`RunAtLoad`) and every `nfs_mounts_watchdog_interval` seconds thereafter (`StartInterval`) — it's re-spawned fresh each interval, not a single long-running process.
3. Each mount uses `deadtimeout={{ nfs_mounts_deadtimeout }}`: if the NAS becomes unresponsive for that long, the kernel force-unmounts it. The next watchdog run notices it's missing and remounts it — unattended recovery in roughly `deadtimeout + one interval`, no manual intervention. (Mounting NFS requires root on macOS — there's no user-mount sysctl equivalent on this OS version — which is why this is a system LaunchDaemon rather than something a Nomad task can do itself.)

## Why the mount point matches the old SMB path

Each share mounts at the same path its SMB counterpart used to (`/Volumes/<name>`, e.g. `/Volumes/Cosmonautical`) — this only works on a host once nothing there still mounts that share over SMB at the same path, since two different filesystems can't occupy one mount point at once. Hosts adopt this one at a time: drain, reboot (clears any lingering SMB mount cleanly), then this LaunchDaemon mounts NFS fresh at the same path on boot, and jobs that used to SMB-mount it themselves are updated to just wait for the NFS mount instead. Because of this, `volume_mount_path` isn't overridable per-share — every share on a host has to land under the same root, or this migration-in-place trick doesn't work.

`nfs_mounts_shares` is deliberately opt-in — the role default is `[]`, no shares — for the same reason: turning it on for a host before that host's SMB-using jobs have all migrated would try to mount NFS on top of a path still in use over SMB.

## Configuration

`nas_host` — the NFS server's address — has **no default** and must be set in your own inventory (`group_vars`/`host_vars`) or as an extra var (e.g. Semaphore variables). If a host has `nfs_mounts_shares` but no `nas_host`, the role fails before touching anything. `nas_user` defaults to `ansible_user` in [`playbooks/group_vars/all.yml`](../../playbooks/group_vars/all.yml).

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
| `nas_host` | _(none — required)_ | Site-specific; must come from your inventory or extra vars |
| `volume_mount_path` | `/Volumes` | Parent directory every share mounts under, matching the SMB paths these shares replace |
| `nfs_mounts_deadtimeout` | `30` | Seconds an unresponsive mount is tolerated before the kernel force-unmounts it; the watchdog then notices it's gone and remounts — worst-case unattended recovery is roughly this plus one `nfs_mounts_watchdog_interval` |
| `nfs_mounts_watchdog_interval` | `30` | Seconds between watchdog checks |
| `nfs_mounts_version` | `3` | Pinned rather than negotiated — the UNAS Pro only speaks NFSv3 (confirmed 2026-09-21) |
| `nfs_mounts_rsize` / `nfs_mounts_wsize` | `65536` | Practical max macOS's `mount_nfs` will do for NFSv3 (default negotiates down to 32768) — doesn't help once the NAS's own disk I/O is the bottleneck under concurrent load (confirmed 2026-09-24), but a safe, cheap thing to raise |
| `nfs_mounts_timeo` | `100` | RPC retransmit timeout in tenths of a second, up from macOS's default of 10 (1.0s) — too aggressive under concurrent-load contention (confirmed 2026-09-24/25), triggering redundant retransmits onto an already-struggling NAS; stays well under `nfs_mounts_deadtimeout` so a genuinely dead NAS is still detected promptly |
| `nfs_mounts_watchdog_label` | `cloud.cosmonautical.nfs-mount-watchdog` | LaunchDaemon label |
| `nfs_mounts_watchdog_script_name` | `nfs-mount-watchdog.sh` | Script filename under `config_dir` |
| `nfs_mounts_watchdog_log_file` | `nfs-mount-watchdog.log` | Log filename under `log_dir` |
