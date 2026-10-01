# podman

Installs or removes [Podman](https://podman.io/) based on `podman.enabled`, managing a Podman machine on the host and a LaunchAgent to keep it running across reboots.

## What it does

`podman.enabled: true` (`tasks/setup.yml`):

1. Installs or upgrades Podman via Homebrew.
2. Checks for an existing Podman machine. If none exists, initialises and starts one.
3. Inspects the machine to obtain its Unix socket path and sets the `podman_socket_path` fact (used by the Nomad role when building the Podman driver config).
4. Templates a LaunchAgent plist to `{{ launch_agents_dir }}/{{ podman_launchagent_label }}.plist` (defaults to `~/Library/LaunchAgents/com.podman.machine.default.plist`) and bootstraps it into launchd so the Podman machine starts automatically on login.

`podman.enabled: false` (`tasks/teardown.yml`): stops and removes any existing Podman machine, unloads the LaunchAgent (`launchctl bootout`, if loaded) and removes its plist, then uninstalls Podman via Homebrew. Nomad's `nomad-driver-podman` plugin is torn down separately by the `nomad` role (see its README), which is also conditioned on `podman.enabled`.

`podman` absent entirely — this role isn't included at all (see `playbooks/nomadintosh.yml`); a host that's never mentioned `podman` is left alone either way.

## Host variables

| Variable | Values | Effect |
|---|---|---|
| `podman.enabled` | `true` / `false` / _(absent)_ | Install, uninstall, or don't manage Podman on this host |

## Configuration

`launch_agents_dir` (defined in [`playbooks/group_vars/all.yml`](../../playbooks/group_vars/all.yml)) sets where the LaunchAgent plist is written. Role-level defaults in `defaults/main.yml` set `podman_launchagent_label` and `podman_launchagent_program_args` (the latter built from `homebrew_dir` and `podman_machine_name`) — each defaulted to the value the plist previously hardcoded.

## No manual setup required

Podman is installed and the machine is initialised entirely automatically. The socket path is discovered at runtime and passed to the Nomad role.
