# consul

Installs and configures a [Consul](https://developer.hashicorp.com/consul/docs) agent on the host.

## What it does

1. Creates the config directory (`/etc/consul.d`) and working/data directory (`/opt/consul`).
2. Installs or upgrades Consul via the `hashicorp/tap` Homebrew tap. If the *upgrade* fails but Consul is already installed and runnable, the failure is treated as a warning rather than fatal — the box keeps running its current version until Homebrew has a bottle for it (the common case right after a new macOS release, when the installed Command Line Tools can't build the formula from source either). A host with no working Consul at all still fails hard.
3. Templates `server.hcl` into `/etc/consul.d/` — datacenter, node name, server/client mode, `bootstrap_expect`, and `retry_join` are all derived automatically from the inventory.
4. Writes a LaunchAgent plist to `{{ launch_agents_dir }}/{{ consul_launchagent_label }}.plist` (defaults to `~/Library/LaunchAgents/homebrew.mxcl.consul.plist`) and bootstraps it into launchd if it isn't already running.
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
| `homebrew_dir` | `/opt/homebrew` | Used to locate the `consul` binary |
| `log_dir` | `{{ homebrew_dir }}/var/log` | Directory the LaunchAgent writes `consul_launchagent_log_file` into |
| `launch_agents_dir` | `~/Library/LaunchAgents` | Where the LaunchAgent plist is written |

Role-level defaults in `defaults/main.yml` expand these into `consul_config_dir` and `consul_working_dir`, and set the LaunchAgent's own `consul_launchagent_label`, `consul_launchagent_program_args`, `consul_launchagent_log_file`, and `consul_launchagent_working_dir` — each defaulted to the value the plist previously hardcoded.

## No manual setup required (usually)

Datacenter name, peer list, and server count are all derived from the inventory at template time — no variables need to be set by hand, *provided* this run's own inventory actually includes the hosts with `server.enabled: true`.

### Joining an existing external cluster

If this run's inventory doesn't include the real Consul servers — e.g. a Semaphore run scoped to just the `jellify` group, with `cosmonautical`'s three servers living in a separate inventory source entirely — set two optional variables (in `all.vars`, a Semaphore variable group, or `--extra-vars`):

| Variable | Effect |
|---|---|
| `existing_consul_datacenter` | Fixes `datacenter` to this value instead of deriving it from whichever `server.enabled` host this run happens to find first. Falls back to this host's own inventory group name if left unset and no `server.enabled` host is found in this run either, so a misconfigured run still renders a real datacenter rather than an empty one. |
| `existing_cluster_servers` | A list of hostnames/IPs merged into `retry_join`, on top of any `server.enabled: true` hosts this run already found. |

Left unset, this preserves the original behavior above. See `templates/consul.d/server.hcl.j2` for the exact precedence — Nomaduntu's own Consul role uses the same two variables for the same purpose.
