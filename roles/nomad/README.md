# nomad

Installs and configures a [Nomad](https://developer.hashicorp.com/nomad/docs) agent on the host.

## What it does

1. Creates the config directory (`/etc/nomad.d`) and working/data directory (`/opt/nomad`).
2. Installs or upgrades Nomad via the `hashicorp/tap` Homebrew tap.
3. If `container.enabled: true`, downloads and installs the [`nomad-driver-container`](https://github.com/anultravioletaurora/nomad-driver-container) plugin into `/opt/nomad/plugins`; if `container.enabled: false`, removes it. Same for `podman.enabled` and [`nomad-driver-podman`](https://developer.hashicorp.com/nomad/plugins/drivers/podman) (downloaded and compiled from source rather than pre-built). Neither happens if the variable is absent entirely.
4. Templates `server.hcl` into `/etc/nomad.d/` — datacenter, server mode, `bootstrap_expect`, `retry_join`, any configured host volumes, and the `container`/`podman`/`docker` plugin blocks (each present only when that variable's `.enabled` is `true`) are derived from the inventory.
5. Writes a LaunchAgent plist to `~/Library/LaunchAgents/homebrew.mxcl.nomad.plist` and bootstraps it into launchd if it isn't already running.
6. If Nomad was already running and either the package was upgraded or `server.hcl` changed (e.g. a driver plugin was enabled/disabled), the agent is restarted (`launchctl kickstart -k`) so the change actually takes effect — templating a new config alone doesn't make a running agent re-read it.

## Host variables

| Variable | Values | Effect |
|---|---|---|
| `server` | `true` / _(absent)_ | Runs this node as a Nomad server (scheduler). Without it the node runs as a client only. |
| `container.enabled` | `true` / `false` / _(absent)_ | Installs/removes the `nomad-driver-container` plugin and enables/disables it in the Nomad config (see the `container` role for the CLI itself) |
| `podman.enabled` | `true` / `false` / _(absent)_ | Installs/removes the `nomad-driver-podman` plugin and enables/disables it in the Nomad config (see the `podman` role for Podman itself) |
| `docker.enabled` | `true` / `false` / _(absent)_ | Enables/disables the built-in `docker` plugin in the Nomad config (see the `docker_desktop` role for Docker Desktop itself) |
| `volumes` | list of `{name, path}` | Registers [host volumes](https://developer.hashicorp.com/nomad/docs/configuration/client#host_volume) on the client so Nomad jobs can mount local paths. |

## Configuration

All paths are driven by variables defined in [`playbooks/group_vars/all.yml`](../../playbooks/group_vars/all.yml):

| Variable | Default | Purpose |
|---|---|---|
| `config_dir` | `/etc` | Root for `/etc/nomad.d` |
| `working_dir` | `/opt` | Root for `/opt/nomad` (data dir, plugins dir, jobs dir) |
| `homebrew_dir` | `/opt/homebrew` | Used to locate the `nomad` binary |

Role-level defaults in `defaults/main.yml` set `plugin_dir`, `podman_driver_version`, and `podman_driver_name`.

## No manual setup required (usually)

Datacenter name, peer list, and server count are all derived from the inventory at template time — no variables need to be set by hand, *provided* this run's own inventory actually includes the hosts with `server.enabled: true`.

### Joining an existing external cluster

Nomad's own `datacenter` is always this host's inventory group name (a job-placement tag, independent of Consul's) and is never overridden. `retry_join`, though, only finds servers that are part of *this run's* inventory — if they're not (e.g. a Semaphore run scoped to just the `jellify` group), set `existing_cluster_servers` (a list of hostnames/IPs, same variable the `consul` role uses) to merge in the real servers from elsewhere. See `templates/nomad.d/server.hcl.j2` and the `consul` role's README for the full explanation.
