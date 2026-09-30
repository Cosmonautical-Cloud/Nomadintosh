# consul

Installs and configures a [Consul](https://developer.hashicorp.com/consul/docs) agent on the host.

## What it does

1. Creates the config directory (`/etc/consul.d`) and working/data directory (`/opt/consul`).
2. Installs or upgrades Consul via the `hashicorp/tap` Homebrew tap.
3. Templates `server.hcl` into `/etc/consul.d/` — datacenter, node name, server/client mode, `bootstrap_expect`, and `retry_join` are all derived automatically from the inventory.
4. Writes a LaunchAgent plist to `~/Library/LaunchAgents/homebrew.mxcl.consul.plist` and bootstraps it into launchd if it isn't already running.
5. If Consul was freshly installed or upgraded, the agent is restarted to pick up any configuration changes.

## Host variables

| Variable | Values | Effect |
|---|---|---|
| `server` | `true` / _(absent)_ | Runs this node as a Consul server (raft participant, UI enabled). Without it the node runs as a client-only agent. |

## Configuration

All paths are driven by variables defined in [`playbooks/group_vars/all.yml`](../../playbooks/group_vars/all.yml):

| Variable | Default | Purpose |
|---|---|---|
| `config_dir` | `/etc` | Root for `/etc/consul.d` |
| `working_dir` | `/opt` | Root for `/opt/consul` (data dir) |

Role-level defaults in `defaults/main.yml` expand these into `consul_config_dir` and `consul_working_dir`.

## No manual setup required

Datacenter name, peer list, and server count are all derived from the inventory at template time — no variables need to be set by hand.
