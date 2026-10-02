# Inventory File Guide for Nomadintosh

This document explains how to structure your Ansible inventory file (`hosts.yml`) when deploying services using `playbooks/deploy.yml`.

## Key Concepts

### Datacenter derivation

The **group name** each host belongs to becomes its Consul/Nomad **datacenter**. This is derived automatically from `group_names` at runtime — you do not set a `datacenter` variable manually. Every host in the `cosmonautical` group will belong to the `cosmonautical` datacenter, and so on.

### Servers vs. clients

Hosts with `server: { enabled: true }` form the Nomad/Consul control plane for their datacenter. All other hosts are enrolled as client nodes that schedule and run workloads. The `bootstrap_expect` value is set automatically based on how many `server: { enabled: true }` hosts exist in the inventory.

### `retry_join`

Both Nomad and Consul are configured to `retry_join` every host across the full inventory that has `server: true`. You do not need to maintain this list manually.

### Joining an existing external cluster

If a run's own inventory doesn't include the real Consul/Nomad servers at all — e.g. a Semaphore run scoped to just the `jellify` group, with `cosmonautical`'s three servers living in a separate inventory source entirely — set two optional variables (in `all.vars`, a Semaphore variable group, or `--extra-vars`) instead of relying on the above:

| Variable | Effect |
|---|---|
| `existing_consul_datacenter` | Fixes Consul's `datacenter` to this value instead of deriving it from whichever `server: true` host this run happens to find first. Nomad's own `datacenter` is unaffected — it's always this host's inventory group name, since it's purely a job-placement tag. |
| `existing_cluster_servers` | A list of hostnames/IPs merged into `retry_join` for **both** Consul and Nomad, on top of whatever `server: true` hosts this run already found. |

Left unset, this preserves the default behavior above — see `roles/consul/README.md` and `roles/nomad/README.md` for the exact precedence. Nomaduntu's own Consul/Nomad roles use the same two variables for the same purpose, so either OS's hosts can join a control plane whose servers live in the other repo's inventory.

---

## Inventory Structure

```yaml
all:
  vars:
    # Applied to every host
<datacenter-name>:
  hosts:
    <server1.example.com>:
      server:
        enabled: true
    <client1.example.com>:
      podman:
        enabled: true
      gh_actions:
        enabled: true
```

Variables defined directly under a hostname override any group-level `vars` for that host.

---

## Supported Variables

### Connection variables (set under `all.vars` or per-group `vars`)

| Variable | Description |
|----------|-------------|
| `ansible_user` | SSH user for all hosts |
| `ansible_ssh_private_key_file` | Path to the SSH private key |
| `ansible_password` | SSH password (if not using key auth) |
| `ansible_become_password` | `sudo` password |
| `additional_homebrew_packages` | List of extra Homebrew packages to install on every host |
| `existing_consul_datacenter` | Fixes Consul's datacenter instead of deriving it from the inventory (see above) |
| `existing_cluster_servers` | Extra hosts merged into Consul's and Nomad's `retry_join` (see above) |
| `nas_host` | Address of the NFS server `nfs_mounts_shares` are mounted from. **Required** if any host sets `nfs_mounts_shares` — no default |

### Host variables (set per-host)

| Variable | Default | Description |
|----------|---------|-------------|
| `server.enabled` | `false` | Configures the host as a Nomad/Consul server node |
| `podman.enabled` | _(absent)_ | `true` installs Podman, its machine, and the `nomad-driver-podman` plugin; `false` actively removes all three; absent leaves the host unmanaged either way (see `roles/podman/README.md`) |
| `docker.enabled` | _(absent)_ | `true` installs Docker Desktop and the Nomad `docker` plugin config; `false` actively removes Docker Desktop; absent leaves the host unmanaged either way (see `roles/docker_desktop/README.md`) |
| `gh_actions.enabled` | `false` | Deploys a GitHub Actions self-hosted runner as a Nomad job |
| `gh_actions.env` | _(absent)_ | Map of environment variables injected into the runner process (see below) |
| `container.enabled` | _(absent)_ | `true` installs Apple's Container CLI, its LaunchAgent, and the `nomad-driver-container` plugin; `false` actively removes all three; absent leaves the host unmanaged either way (see `roles/container/README.md`) |
| `seaweedfs.master.enabled` / `seaweedfs.volume.enabled` | `false` | Installs SeaweedFS; an enabled volume registers a `seaweedfs-data` Nomad host volume |
| `nfs_mounts_shares` | _(absent)_ | List of `{share_export_path}` NFS shares to mount (see below) |
| `volumes` | _(absent)_ | List of host volumes to expose to the Nomad client (see below) |

#### `nfs_mounts_shares` format

Each entry needs only `share_export_path`; the mount point is always `volume_mount_path` (`/Volumes`) + `/<name>`, `<name>` being `share_export_path`'s final path component — the same path these shares' SMB counterparts used. Not overridable per-share:

```yaml
nfs_mounts_shares:
  - share_export_path: /var/nfs/shared/Cosmonautical   # mounts at /Volumes/Cosmonautical
  - share_export_path: /var/nfs/shared/Jellify          # mounts at /Volumes/Jellify
```

Define it once under a group's `vars:` when every host in the group mounts the same shares, rather than repeating the list per host (see `cosmonautical` and `jellify` in the actual `inventory/hosts.yml`, gitignored — not the example below). If one host in the group also needs its own unique share on top of the group's shared ones — e.g. each `cosmonautical` host has a personal backup share named after itself — build the list with Jinja instead of hardcoding a `name` per host, using the `inventory_hostname_short` magic variable:

```yaml
cosmonautical:
  vars:
    nfs_mounts_shares: >-
      {{
        [
          {'share_export_path': '/var/nfs/shared/Cosmonautical'},
          {'share_export_path': '/var/nfs/shared/Books'},
        ] + [
          {'share_export_path': '/var/nfs/shared/' ~ (inventory_hostname_short | capitalize)},
        ]
      }}
```

On `cassiopeia.cosmonautical.cloud` this resolves to `Cosmonautical`, `Books`, and `Cassiopeia`; on `taurus.cosmonautical.cloud` it resolves to the same two shared shares plus `Taurus`. No per-host override needed.

The `jellify` group's `Jellify` share was granted 2026-09-27 on the same NAS as `cosmonautical` (whatever your inventory sets as `nas_host`) — its mount point (`/Volumes/Jellify`) has to match what `nomad-jobs`' `minecraft.nomad.hcl` expects, since that job's host volume points at this path.

#### `gh_actions.env` format

An optional map of key/value pairs passed as environment variables to the GitHub Actions runner process via the Nomad job's `env {}` block. Useful for variables that would normally be sourced from a login shell (e.g. `/etc/profile`) but are not visible to processes launched by Nomad:

```yaml
gh_actions:
  enabled: true
  env:
    MY_VAR: "some-value"
    ANOTHER_VAR: "another-value"
```

If `gh_actions.env` is absent, no `env {}` block is added to the job.

#### `volumes` format

The `volumes` variable accepts a list of objects with `name` and `path` keys. Each entry is registered as a [Nomad host volume](https://developer.hashicorp.com/nomad/docs/configuration/client#host_volume) on the client:

```yaml
volumes:
  - name: config
    path: /Users/myuser/.config
  - name: data
    path: /opt/myapp/data
```

---

## Example Inventory

```yaml
all:
  vars:
    ansible_user: violet
    ansible_ssh_private_key_file: ~/.ssh/id_rsa
    additional_homebrew_packages:
      - fastfetch

cosmonautical:
  hosts:
    cassiopeia.cosmonautical.cloud:
      server:
        enabled: true
    taurus.cosmonautical.cloud:
      server:
        enabled: true
    copernicus.cosmonautical.cloud:
      server:
        enabled: true
      docker:
        enabled: true
      podman:
        enabled: true
      container:
        enabled: true
      volumes:
        - name: config
          path: /Users/violet/.config


  hosts:
    galileo.jellify.app:
      podman:
        enabled: true
      gh_actions:
        enabled: true
      minecraft:
        enabled: true
      container:
        enabled: true
```
In this example, `cosmonautical` and `jellify` are two separate datacenters. The three `cassiopeia`, `taurus`, and `copernicus` hosts form the `cosmonautical` control plane (`bootstrap_expect = 3`). `galileo` is a client-only node in the `jellify` datacenter running Nomad jobs via Podman.
