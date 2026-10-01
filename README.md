# Nomadintosh

<img src="logo.png" alt="Nomadintosh Logo" width="200" height="225"  />

An Ansible playbook for deploying [Nomad](https://developer.hashicorp.com/nomad/docs) + [Consul](https://developer.hashicorp.com/consul/docs) on a macOS cluster.

**[Nomad](https://developer.hashicorp.com/nomad/docs)** is a workload orchestrator by HashiCorp. It schedules and runs containerised and bare-metal applications across a cluster of machines, similar in spirit to Kubernetes but can run natively on macOS.

**[Consul](https://developer.hashicorp.com/consul/docs)** is a service mesh and service discovery tool, also by HashiCorp. It provides a distributed key-value store, health checking, and DNS-based service discovery. Nomad integrates with Consul natively to handle cluster membership and service registration.

## Scope

This playbook (like its [Nomaduntu](https://github.com/anultravioletaurora/Nomaduntu) counterpart and the [Nomadable](https://github.com/anultravioletaurora/Nomadable) parent that composes them) provisions the Nomad + Consul **agents** themselves — it intentionally does not deploy the job specs those agents run. An Ansible role that used to template and register Nomad job specs directly (a `gh_actions` role rendering `actions-runner.nomad.hcl`, etc.) was removed 2026-09-05 once job deployment moved to dedicated repos: [`Jellify/Nomad-Jobs`](https://github.com/anultravioletaurora/Nomad-Jobs) (Terraform-managed) and a legacy hand-deployed `nomad-jobs` repo. If you're looking to add or change a running job, it belongs in one of those, not here.

<details>
<summary><strong>Why I built this</strong></summary>

I wanted a job orchestrator to keep my homelab workloads organised, but Kubernetes doesn't run natively on macOS or Apple Silicon — it requires a Linux VM intermediary, which adds overhead and complexity.

My previous homelab was a 3-node [Rancher Harvester](https://harvesterhci.io/) cluster. I wanted to experiment with Apple Silicon to evaluate performance-per-watt as an alternative, and Nomad was the natural fit: it runs as a native macOS binary, supports scheduling workloads directly on the host without a container runtime, and is significantly simpler to operate than Kubernetes at homelab scale.

A bonus of running bare-metal jobs is easy access to full hardware acceleration — no passthrough configuration needed.

Longer term, Nomad's multi-platform support means I can add Linux or Windows agents to the same cluster if needed — for example, running [Exact Audio Copy](https://www.exactaudiocopy.de/) on a Windows node for lossless CD ripping.

![Three Mac Minis stacked in a rack — "cosmonautical", a 3-node cluster comprising 2× M4 Mac Mini and 1× M4 Pro Mac Mini](cluster.jpg)
*"cosmonautical" — 2× M4 Mac Mini + 1× M4 Pro Mac Mini*


</details>

## Requirements

- Ansible installed on the control machine (`brew install ansible`)
- Ansible collections:
  ```
  ansible-galaxy collection install -r collections/requirements.yml
  ```

## Inventory

Hosts are organised into named groups; the group name becomes the Consul/Nomad [**datacenter**](https://developer.hashicorp.com/consul/docs/reference/agent/configuration-file/general#datacenter) for every host in that group. See [inventory/README.md](inventory/README.md) for full instructions on how to populate `inventory/hosts.yml`.

**Host variables:**

| Variable | Values | Purpose |
|---|---|---|
| `server.enabled` | `true` / _(absent)_ | Configures the host as a Nomad/Consul server |
| `container.enabled` | `true` / `false` / _(absent)_ | Installs/removes Apple's [Container](https://github.com/apple/container) CLI, its LaunchAgent, and the Nomad `nomad-driver-container` plugin |
| `podman.enabled` | `true` / `false` / _(absent)_ | Installs/removes Podman, its machine, its LaunchAgent, and the Nomad `nomad-driver-podman` plugin |
| `docker.enabled` | `true` / `false` / _(absent)_ | Installs/removes Docker Desktop and the Nomad `docker` plugin config |
| `volumes` | list of `{name, path}` | Configures [Nomad host volumes](https://developer.hashicorp.com/nomad/docs/configuration/client#host_volume) on the client |
| `nfs_mounts_shares` | list of `{share_export_path}` | NFS shares to mount from `nas_host` via a watchdog LaunchDaemon. Mount point is always `volume_mount_path` (`/Volumes`) + `/<name>`, `<name>` being `share_export_path`'s final path component — matches the SMB paths these shares replace |
| `seaweedfs.master.enabled` / `seaweedfs.volume.enabled` | `true` / _(absent)_ | Installs SeaweedFS; an enabled volume registers a `seaweedfs-data` Nomad host volume |
| `existing_consul_datacenter` | _(absent)_ | Fixes Consul's `datacenter` when this run's own inventory doesn't include the real servers — see the `consul` role's README |
| `existing_cluster_servers` | list of hostnames/IPs | Extra hosts merged into Consul's and Nomad's `retry_join`, for the same reason as above |

Example host definition:

```yaml
galileo.jellify.app:
  server:
    enabled: true
  container:
    enabled: true
  podman:
    enabled: true
```

## Running the playbook

Run a full deployment:

```zsh
./deploy.zsh
```

Dry-run in check + diff mode to preview changes without applying them:

```zsh
./check.zsh
```

Serial Reboot all hosts in the inventory:

```zsh
./reboot.zsh
```

To limit execution to a single host or group, you can also pass `--limit` directly to the underlying playbook:

```zsh
ansible-playbook -i inventory/hosts.yml playbooks/nomadintosh.yml --limit <hostname>
```

## What it does

For every host, the playbook performs the following steps:

1. **Facts** — asserts the host is running macOS and sets the `datacenter` fact derived from the host's inventory group name.
2. **Software Update** — downloads all pending macOS system updates via `softwareupdate`, installs any available Command Line Tools for Xcode, and warns if a restart is required.
3. **Sysctl tuning** — deploys a LaunchDaemon that applies `kern.ipc.somaxconn = 1024` (macOS's default of 128 causes connection refusals under concurrent load).
4. **NFS mounts** _(`cosmonautical`/`jellify` groups)_ — deploys a watchdog LaunchDaemon that mounts each host's `nfs_mounts_shares` and remounts any that go missing.
5. **Homebrew** — [Homebrew](https://brew.sh/) is the package manager of choice for this project. The playbook installs Homebrew if not present, taps `hashicorp/tap`, and installs any packages listed in `additional_homebrew_packages`. All system packages — including Consul, Nomad, Podman, and the Apple Container CLI — are managed exclusively through Homebrew.
6. **Apple Container** _(hosts with `container: true`)_ — installs Apple's [Container](https://github.com/apple/container) CLI via Homebrew and registers a LaunchAgent that starts the container system at login. On the Nomad side, the playbook downloads and installs [`nomad-driver-container`](https://github.com/anultravioletaurora/nomad-driver-container) — a custom Nomad task driver that integrates Nomad's scheduling with Apple's Container runtime. This allows Nomad jobs to run OCI containers natively on macOS using Apple's Virtualization.framework, without Docker Desktop or a Podman VM. The driver is configured in `nomad.d/server.hcl` with garbage collection enabled and log collection active.
7. **Docker Desktop** _(hosts with `docker: true`)_ — installs and configures Docker Desktop.
8. **Podman** _(hosts with `podman: true`)_ — installs Podman, initialises the machine, and installs the [`nomad-driver-podman`](https://developer.hashicorp.com/nomad/plugins/drivers/podman) plugin.
9. **SeaweedFS** _(hosts with `seaweedfs.master.enabled` / `seaweedfs.volume.enabled`)_ — installs SeaweedFS via Homebrew and creates the host's volume directory.
10. **Consul** — creates config/data directories, installs Consul via Homebrew, templates [`server.hcl`](https://developer.hashicorp.com/consul/docs/reference/agent/configuration-file) with datacenter, node name, server/client mode, and [`retry_join`](https://developer.hashicorp.com/consul/docs/reference/agent/configuration-file/general#retry_join) derived from inventory (or `existing_consul_datacenter`/`existing_cluster_servers`, if this run's inventory doesn't include the real servers — see the `consul` role's README), and registers a LaunchAgent.
11. **Nomad** — creates config/data directories, installs Nomad via Homebrew, templates [`server.hcl`](https://developer.hashicorp.com/nomad/docs/configuration) (including [`bootstrap_expect`](https://developer.hashicorp.com/nomad/docs/configuration/server#bootstrap_expect) and [`retry_join`](https://developer.hashicorp.com/nomad/docs/configuration/server_join), also honoring `existing_cluster_servers`), configures any enabled task driver plugins (`nomad-driver-container`, `nomad-driver-podman`), and registers a LaunchAgent.
12. **UID normalize** _(opt-in only, `--tags uid_normalize`)_ — normalizes `ansible_user`'s UID to a fixed value; skipped by a plain run.

Services are managed as macOS LaunchAgents (Nomad, Consul, and optionally the Podman machine and Apple Container system).

## Notifications

A reusable webhook task file is available at [`tasks/notify.yml`](tasks/notify.yml). Import it anywhere in a playbook to POST a notification on completion:

```yaml
- name: Send completion notification
  ansible.builtin.import_tasks: notify.yml
  vars:
    webhook_message: "nomadintosh deployment completed"
```

Store `notify_webhook_url` in Ansible Vault. The default body format is Discord-compatible (`content` + `username`); override with `webhook_body` for other platforms.

## Remarks

- **Platform** — This playbook is tested against Apple Silicon running macOS 26 Tahoe. Mileage on x86 Macs or other macOS versions may vary.
- **Bare-metal preference** — Where possible, workloads are deployed as native bare-metal jobs rather than containers. This is a deliberate choice to optimise performance on macOS — specifically to avoid the memory overhead of the Linux VM that Docker Desktop and Podman require on macOS, and to take advantage of native hardware acceleration (Metal, VideoToolbox, Core ML) which is unavailable or requires passthrough configuration inside a container runtime.
- **`nomad-driver-container` is experimental** — The [nomad-driver-container](https://github.com/anultravioletaurora/nomad-driver-container) plugin is an early-stage, lightly tested project. It may behave unexpectedly, and is not recommended for workloads where stability is critical.
- **Companion project** — [Nomaduntu](https://github.com/anultravioletaurora/Nomaduntu) is the Ubuntu counterpart to this playbook. Nomad's multi-platform support means both clusters can participate in the same datacenter if desired — set `existing_consul_datacenter`/`existing_cluster_servers` on either side when a group's own inventory run doesn't include the real Consul servers (e.g. Semaphore running each OS group separately). Nomaduntu's inventory/README.md documents the same two variables.


## Special Thanks

- **[Jeff Geerling](https://www.jeffgeerling.com/)** — for his extensive work on [Ansible for DevOps](https://www.ansiblefordevops.com/), his [open-source Ansible roles](https://github.com/geerlingguy), and his deep-dive coverage of [Apple Silicon in homelabs](https://www.youtube.com/@JeffGeerling) that helped inspire this project.
- **[HashiCorp](https://www.hashicorp.com/)** — for building [Nomad](https://developer.hashicorp.com/nomad/docs) and [Consul](https://developer.hashicorp.com/consul/docs), making native macOS workload orchestration possible.
- **[Homebrew contributors](https://github.com/Homebrew/brew/graphs/contributors)** — for maintaining the package manager that makes the entire software stack on this project possible. Every binary this playbook installs — from Nomad and Consul to Podman and the Apple Container CLI — is delivered and kept up to date through Homebrew.
- **[nomad-driver-podman contributors](https://github.com/hashicorp/nomad-driver-podman)** — for the Podman task driver plugin that enables rootless container workloads on Nomad.
