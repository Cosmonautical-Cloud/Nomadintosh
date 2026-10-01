# Changelog

All notable changes to this project are documented here. Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); this project follows [semantic versioning](https://semver.org/).

## [2.0.2] - 2026-10-01

### Docs

- Added a `## Playbooks` section to the README listing both `playbooks/nomadintosh.yml` and `playbooks/reboot.yml` with a one-line description each. Confirmed (by reading `galaxy_importer`'s `PlaybookLoader.load()`, which never sets a `description` on `schema.Content` the way `RoleLoader.load()` does from `meta/main.yml`) that Galaxy has no synopsis field for playbook content at all — unlike roles, there's no file or format that would make one show up in the Galaxy UI, so the README is the actual canonical place this gets documented. `playbooks/reboot.yml` in particular had no top-level README coverage before this (only `roles/reboot/README.md` mentioned it).

## [2.0.1] - 2026-10-01

### Fixed

- The `nomad`, `consul`, and `podman` LaunchAgent plist templates gained a trailing newline when their `Label`/`ProgramArguments`/path values were extracted into variables in 1.6.3 - the previously-deployed plists on every host end `</plist>` with no trailing newline, so this showed up as a spurious one-time `changed` on the LaunchAgent template task industry-wide (confirmed live via a Semaphore check-mode run against `galileo`/`hopper`). Templates now end byte-for-byte the same as before that refactor; re-rendered and confirmed identical to the already-deployed files.

## [2.0.0] - 2026-10-01

### Changed

- **Breaking:** Galaxy namespace moved from the personal `anultravioletaurora` to the now-approved `cosmonautical` namespace (same one `cosmonautical.notify` already publishes under). The collection's fully-qualified name is now `cosmonautical.nomadintosh` instead of `anultravioletaurora.nomadintosh` — anything installing or importing it (including the `Nomadable` playbook, bumped alongside this) needs its `collections/requirements.yml` pin and `import_playbook`/role references updated to match. The GitHub repo location (`Cosmonautical-Cloud/Nomadintosh`) is unchanged; this is purely the Galaxy identity. Previously published `anultravioletaurora.nomadintosh` versions are left in place on Galaxy, just no longer the publish target.

## [1.6.3] - 2026-10-01

### Changed

- LaunchAgent/LaunchDaemon plists for `nomad`, `consul`, `podman`, `container`, `sysctl`, and `nfs_mounts` no longer hardcode their `Label`, `ProgramArguments`, log paths, or working directory directly in the template — each is now a role-level default in that role's `defaults/main.yml`, set to the value the plist previously hardcoded. Overriding any of them (e.g. to add an agent flag, or rename a log file) no longer means editing the template itself. The task files for the same six roles were updated to reference those same variables too, instead of repeating the literal label/path a second or third time across `template:`/`stat:`/`launchctl` argv.
- Added `launch_agents_dir` (`/Users/{{ ansible_user }}/Library/LaunchAgents`) and `launch_daemons_dir` (`/Library/LaunchDaemons`) to `playbooks/group_vars/all.yml`, replacing the literal path that was repeated across all six roles above.

### Fixed

- `roles/nomad/templates/nomad.d/server.hcl.j2`: the `nomad-driver-container` plugin's `container_path` was hardcoded to `/opt/homebrew/bin/container` instead of using the existing `homebrew_dir` variable (the `nomad-driver-podman` block right next to it already did this correctly). Harmless so far since no host has relocated its Homebrew prefix, but inconsistent and now fixed.
- `roles/podman/templates/LaunchAgents/com.podman.machine.default.plist.j2`: `ProgramArguments`'s last argument was the literal string `podman-machine-default` instead of referencing the existing `podman_machine_name` variable, so a host overriding `podman_machine_name` would have gotten a LaunchAgent pointed at the wrong machine name.
- `roles/consul/templates/LaunchAgents/homebrew.mxcl.consul.plist.j2`: `-config-file` was hardcoded to `/etc/consul.d/server.hcl` instead of using the existing `consul_config_dir` variable, so a host overriding `config_dir` would have gotten a LaunchAgent pointed at the wrong config path.

All plist templates were re-rendered with representative values and parsed back through Python's `plistlib` to confirm byte-for-byte equivalent structure to the pre-refactor output (apart from the three fixes above, which only change behavior for a host that overrides the relevant variable from its default).

## [1.6.2] - 2026-10-01

### Fixed

- `roles/software_update/tasks/main.yml`: the "Install Command Line Tools for Xcode" task was reading `softwareupdate -l`'s *default* listing, which Apple hides `Command Line Tools for Xcode` from entirely unless an on-demand install flag file (`/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress`) exists first - the same signal `xcode-select --install` drops before it pops its GUI prompt. Without it, this task silently never saw CLT updates at all, not just around a new macOS release. Confirmed live on taurus: Apple had already published Command Line Tools for Xcode 27.0, invisible to `softwareupdate -l` until the flag file was set. The task now sets that flag, picks the newest available CLT label (`sort -V`, not just the first one listed), installs it headlessly, and clears the flag afterward - fully automated, no `xcode-select --install` GUI involved.

## [1.6.1] - 2026-10-01

### Changed

- `roles/consul/tasks/install.yml`, `roles/nomad/tasks/install.yml`: a failed Homebrew *upgrade* of Consul/Nomad is no longer fatal when a working install already exists on the host - it's logged as a warning and the current version keeps running. This is specifically for the window right after a new macOS release where Homebrew has no bottle yet and the installed Command Line Tools can't build the formula from source either (`Your Command Line Tools (CLT) does not support macOS X`); it resolves itself on a later run once a bottle ships, no code change needed. A host with no working install at all still fails hard - this only softens upgrade failures, not first installs. The Homebrew tap remains the only install path; no vendored/direct-download fallback was added.
- `roles/consul/templates/LaunchAgents/homebrew.mxcl.consul.plist.j2`: pointed `ProgramArguments` at `{{ homebrew_dir }}/bin/consul` instead of the Cellar `opt/consul` symlink, matching how the Nomad LaunchAgent already references its binary.

## [1.6.0] - 2026-10-01

### Removed

- `seaweedfs` role no longer installs macFUSE. It was only ever needed to mount SeaweedFS volumes as a local filesystem, and FUSE-mounted SeaweedFS has proven unreliable for latency/consistency-sensitive workloads (Postgres, SQLite) in this homelab - nothing here still depends on that mount path. Installing `seaweedfs` itself (the master/volume/filer/S3 processes) is unaffected. Doesn't uninstall macFUSE from hosts that already have it; that's a manual cleanup if wanted.

## [1.5.2] - 2026-10-01

### Fixed

- `roles/nomad/templates/nomad.d/server.hcl.j2`: pinning `bind_addr` to the literal private IPv4 in 1.5.1 also moved Nomad's HTTP API off `0.0.0.0` by default (Nomad has no separate `client_addr`-style knob - every listener inherits `bind_addr` unless overridden), so `nomad` CLI / anything hitting `localhost:4646` stopped working. Added an explicit `addresses { http = "0.0.0.0" }` block so only the actual cluster gossip/RPC ports (serf/rpc) stay pinned to the literal IP; the HTTP API goes back to listening on loopback + the LAN IP like before.

## [1.5.1] - 2026-10-01

### Fixed

- `roles/consul/templates/consul.d/server.hcl.j2` and `roles/nomad/templates/nomad.d/server.hcl.j2` both set `bind_addr = "0.0.0.0"`, which on macOS produced a dual-stack (IPv6-capable) listener for Consul's serf/raft ports (8300-8302) and Nomad's own bind port, even though `advertise_addr` was already a literal IPv4 address. When a host accumulates stale default IPv6 routes through dead `utunN` interfaces (observed: macOS keeps regenerating these even after manual `route delete`, so they're not a one-time cleanup), Consul's gossip/raft RPC traffic intermittently resolves through one of those dead routes and fails with `no route to host` - which cascaded into raft quorum loss and a Patroni-managed Postgres instance stuck unable to reach its Consul DCS. `bind_addr` is now pinned to the same literal private IPv4 address `advertise_addr` already uses (`ansible_facts['default_ipv4']['address']`), forcing a true IPv4-only socket so cluster gossip/raft no longer depends on IPv6 routing at all. Consul's `client_addr` (HTTP/DNS API, loopback-only traffic from Nomad/Patroni) is left at `0.0.0.0` - it wasn't implicated in the failure chain.

## [1.5.0] - 2026-10-01

### Added

- Restored the `cosmonautical.notify` dependency in `galaxy.yml` and `collections/requirements.yml` now that the `cosmonautical` namespace is approved and `cosmonautical.notify` 0.0.1 is published. Set `notify_enabled: true` in inventory to re-enable notifications - no code changes needed, per the note left in [1.4.2](#142---2026-09-30).

### Fixed

- `roles/nomad/tasks/container_driver.yml` failed under `--check --diff` with `Source ... not found`: the download/extract steps were silently simulated under check mode (nothing ever landed in `/tmp`), so the final `copy` task had no source to stat. Download, extract, and move now run for real under check mode (`check_mode: false`), same as the existing tmp-directory-creation task, while restart/config-diff stay simulated as before.
- The same tasks weren't idempotent across a `nomad_container_driver_version` bump: the extraction step's `creates:` guard pointed at a fixed, unversioned path, so once a version had been extracted once, a later version bump would re-download the new tarball but skip re-extracting it, leaving the old binary in place. The tmp directory is now version-scoped (`nomad_container_driver_tmp_dir`), so a version bump always re-extracts and redeploys.

## [1.4.2] - 2026-09-30

### Changed

- Removed the hard dependency on `cosmonautical.notify` (from `galaxy.yml` and `collections/requirements.yml`) while the `cosmonautical` Galaxy namespace is still pending approval and the collection isn't publishable yet — it was blocking `ansible-galaxy collection install` for anyone pulling this collection fresh. The two call sites (`roles/nomad/tasks/install.yml`, `roles/software_update/tasks/main.yml`) now `include_tasks` their notify logic from a sibling `notify.yml`, gated behind `notify_enabled` (new var, default `false`). Dynamic `include_tasks` means `cosmonautical.notify.discord` is never resolved unless `notify_enabled: true`, so the collection doesn't need to be installed at all by default. Once `cosmonautical.notify` is live on Galaxy: add it back to `galaxy.yml`/`collections/requirements.yml`, and set `notify_enabled: true` in inventory to re-enable notifications — no further code changes needed.

## [1.4.1] - 2026-09-30

### Docs

- Repo moved from `anultravioletaurora/Nomadintosh` to the `Cosmonautical-Cloud` GitHub org. Updated `repository`/`homepage`/`issues` in `galaxy.yml` to match. Galaxy namespace (`anultravioletaurora`) is unaffected — it's tied to the Galaxy account, not the repo's GitHub location.

## [1.4.0] - 2026-09-30

### Changed

- **Breaking:** the `notify` role (webhook notifications) was extracted out to the shared [`cosmonautical.notify`](https://github.com/Cosmonautical-Cloud/ansible-collection-notify) collection, so Nomaduntu can use it too without a circular collection dependency on Nomadable. `roles/notify/` and the unused, drifted `tasks/notify.yml` duplicate were both removed. It's a module there, not a role — the two call sites (`roles/nomad/tasks/install.yml`, `roles/software_update/tasks/main.yml`) now call `cosmonautical.notify.discord` directly on the task (looping over `discord_webhooks`, `delegate_to: localhost`) instead of `include_role: notify` with `notify_webhook_message`. The local `inventory/hosts.yml` `notifications: [{type, url}]` var is renamed `discord_webhooks: [{id, token}]` (the `type` key is redundant now that it's Discord-specific, and `id`/`token` replace the full `url`) — update any fork's inventory accordingly.

## [1.3.0] - 2026-09-30

### Added

- `container.enabled`, `podman.enabled`, and `docker.enabled` are now tri-state: `true` installs/enables as before, `false` actively tears down an existing install (uninstalls the package, unloads and removes its LaunchAgent where applicable, stops/removes the Podman machine where applicable, and removes the corresponding Nomad driver plugin), and leaving the variable absent entirely still means "don't manage this at all" either way. See `roles/container/README.md`, `roles/podman/README.md`, `roles/docker_desktop/README.md`, and `roles/nomad/README.md`.

### Fixed

- Nomad's LaunchAgent is now restarted (`launchctl kickstart -k`) whenever `server.hcl` changes and Nomad is already running, not just when the Nomad package itself was upgraded — previously a config-only change (e.g. a driver plugin enabled/disabled) would template a new `server.hcl` but never actually apply it to the running agent, requiring a manual restart or reboot. Removed `roles/nomad/tasks/start.yml`, which had been empty (and its "Kickstart Nomad services" step consequently a no-op) since the `organize launchagents` commit.

## [1.2.1] - 2026-09-29

### Changed

- **Breaking:** `nfs_mounts_shares` entries now take only `share_export_path` (renamed from `export`). `name` and `mount_point` are gone — the mount point is always `volume_mount_path` (renamed from `nfs_mounts_default_dir`, still `/Volumes`) + `/<name>`, with `<name>` derived from `share_export_path`'s final path component, so a share's name is never spelled out twice. Existing inventory entries need updating: `{name, export, mount_point?}` → `{share_export_path}`.

### Removed

- CockroachDB role inclusion in `playbooks/nomadintosh.yml`, added in 1.1.0 but the `cockroachdb` role itself was never added under `roles/` - every Darwin run failed at that task. Also dropped the stale reference from `README.md`.

## [1.2.0] - 2026-09-29

### Added

- `nfs_mounts_shares` entries no longer require `mount_point`: it now defaults to `nfs_mounts_default_dir` (`/Volumes`) + `/<name>` when omitted — the same path these shares' SMB counterparts used — so a share can be added from an inventory source that only supplies `{name, export}` (e.g. a Semaphore variable group) without also spelling out the mount path every time. Explicit `mount_point` values are unaffected.
- `existing_consul_datacenter` and `existing_cluster_servers` (optional): when this run's own inventory doesn't include the real Consul/Nomad servers — e.g. a Semaphore run scoped to just the `jellify` group, with `cosmonautical`'s three servers living in a separate inventory source entirely — set these to join that already-running control plane instead of bootstrapping an isolated one from an empty server list. Mirrors the same two variables Nomaduntu's Consul/Nomad roles already support. `existing_consul_datacenter` also now falls back to this host's own inventory group name (instead of rendering an empty `datacenter`) if left unset and no `server.enabled` host is found in this run either.

### Docs

- Fixed `roles/nfs_mounts/README.md`, which claimed shares mount under `/Volumes/NFS/<name>` and default to a fixed Cosmonautical/Books/ROMs/Music list — both stale: the actual template mounts at `/Volumes/<name>` directly (the same path SMB used), and the role default is `[]` (no shares).
- Updated `inventory/README.md`, the top-level `README.md`, and the `consul`/`nomad` role READMEs to document `nfs_mounts_shares`, `seaweedfs`, and the new `existing_consul_datacenter`/`existing_cluster_servers` variables — none of which were mentioned since they were added in 1.1.0. Also dropped the stale `minecraft.enabled` row from `inventory/README.md` (that role was removed in 1.1.0).

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
