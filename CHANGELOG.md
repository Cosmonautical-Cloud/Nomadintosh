# Changelog

All notable changes to this project are documented here. Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); this project follows [semantic versioning](https://semver.org/).

## [1.1.0] - 2026-09-29

### Added

- `seaweedfs` role: installs SeaweedFS and macFUSE via Homebrew, and creates a host's SeaweedFS volume directory when `seaweedfs.volume.enabled: true`. Wired into `playbooks/nomadintosh.yml` behind `seaweedfs.master.enabled` / `seaweedfs.volume.enabled`, and into the `nomad` role's `server.hcl.j2` template so an enabled volume registers a `seaweedfs-data` Nomad host volume.
- `sysctl` role: applies `kern.ipc.somaxconn = 1024` (macOS's default of 128 was observed causing connection refusals under concurrent load).
- `uid_normalize` role: normalizes `ansible_user`'s UID to a fixed value, opt-in only via `--tags uid_normalize` (tagged `never` so a plain run never touches it).
- `nfs_mounts` role reworked: renders a watchdog script + LaunchDaemon that mounts each host's `nfs_mounts_shares` under `/Volumes/<name>` on boot and remounts if a check finds it missing, so hosts can migrate off SMB shares one at a time. Mount options pin `nfsvers=3` (confirmed 2026-09-21 that the UNAS Pro only speaks NFSv3) and raise `rsize`/`wsize` to 65536 (the practical max macOS's `mount_nfs` will do for v3 — confirmed 2026-09-24 this doesn't help once the NAS's own disk I/O is the bottleneck under concurrent load, but it's a safe, cheap thing to raise regardless) and `timeo` to 100 tenths of a second, up from macOS's default of 10 (confirmed 2026-09-24/25 that a 1.0s timeout was aggressive enough under concurrent-load contention to trigger redundant retransmits onto an already-struggling NAS).
- CockroachDB role inclusion in `playbooks/nomadintosh.yml`, plus tags on every task so individual components can be run with `--tags`.
- Homebrew/sysctl/NFS mounts now also gate correctly for the `jellify` group (previously scoped to `cosmonautical` only).

### Changed

- `config_dir`, `working_dir`, `homebrew_dir`, `log_dir`, `nas_host`, and `nas_user` moved from `inventory/group_vars/all.yml` to `playbooks/group_vars/all.yml`. The latter loads regardless of what inventory source is used to run the playbook (unlike `inventory/group_vars`, which only loads relative to whatever inventory file is actually passed to `ansible-playbook`), so the repo no longer depends on `inventory/hosts.yml` existing — e.g. when Semaphore supplies its own inventory instead.
- Role READMEs (`consul`, `nomad`, `container`, `nfs_mounts`) updated to point at the new `playbooks/group_vars/all.yml` location.

### Fixed

- `seaweedfs.volume.enabled` is now guarded with `| default(false)` in the `seaweedfs` role, so a host with `seaweedfs.master.enabled: true` but no `volume` key doesn't fail with an undefined-variable error.

### Removed

- `minecraft` role.

### Docs

- Added `roles/seaweedfs/README.md` (previously undocumented).

## [1.0.6] and earlier

Not tracked in this changelog. See `git log`.
