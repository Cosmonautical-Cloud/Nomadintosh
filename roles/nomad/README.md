# nomad

Installs and configures a [Nomad](https://developer.hashicorp.com/nomad/docs) agent on the host.

## What it does

1. Creates the config directory (`/etc/nomad.d`) and working/data directory (`/opt/nomad`).
2. Installs or upgrades Nomad via the `hashicorp/tap` Homebrew tap.
3. If `podman: true` is set on the host, downloads, compiles, and installs the [`nomad-driver-podman`](https://developer.hashicorp.com/nomad/plugins/drivers/podman) plugin into `/opt/nomad/plugins`.
4. Templates `server.hcl` into `/etc/nomad.d/` — datacenter, server mode, `bootstrap_expect`, `retry_join`, and any configured host volumes are derived from the inventory.
5. Writes a LaunchAgent plist to `~/Library/LaunchAgents/homebrew.mxcl.nomad.plist` and bootstraps it into launchd if it isn't already running.
6. If Nomad was freshly installed or upgraded, the agent is restarted to pick up any configuration changes.

## Host variables

| Variable | Values | Effect |
|---|---|---|
| `server` | `true` / _(absent)_ | Runs this node as a Nomad server (scheduler). Without it the node runs as a client only. |
| `podman` | `true` / _(absent)_ | Installs the `nomad-driver-podman` plugin and enables it in the Nomad config. |
| `volumes` | list of `{name, path}` | Registers [host volumes](https://developer.hashicorp.com/nomad/docs/configuration/client#host_volume) on the client so Nomad jobs can mount local paths. |

## Configuration

All paths are driven by variables defined in [`playbooks/group_vars/all.yml`](../../playbooks/group_vars/all.yml):

| Variable | Default | Purpose |
|---|---|---|
| `config_dir` | `/etc` | Root for `/etc/nomad.d` |
| `working_dir` | `/opt` | Root for `/opt/nomad` (data dir, plugins dir, jobs dir) |
| `homebrew_dir` | `/opt/homebrew` | Used to locate the `nomad` binary |

Role-level defaults in `defaults/main.yml` set `plugin_dir`, `podman_driver_version`, and `podman_driver_name`.

## No manual setup required

Datacenter name, peer list, and server count are all derived from the inventory at template time — no variables need to be set by hand.
