# container

Installs [Apple's Container CLI](https://github.com/apple/container) and registers it as a LaunchAgent so the container system starts automatically at login.

## What it does

1. Installs or upgrades the `container` package via Homebrew.
2. Templates a LaunchAgent plist (`com.apple.container.plist`) into `~/Library/LaunchAgents/`.
   - On first install: bootstraps the agent into launchd with `launchctl bootstrap`.
   - On upgrade: restarts the existing agent with `launchctl kickstart -k`.
3. Asserts that the container system is running by calling `container system status`.

The LaunchAgent invokes `container system start --enable-kernel-install` at login, writing stdout and stderr to `{{ log_dir }}/container.log`.

## Host variables

| Variable | Values | Effect |
|---|---|---|
| `container.enabled` | `true` / _(absent)_ | Include this role for the host. Without it the role is skipped entirely. |

## Dependencies

| Variable | Purpose |
|---|---|
| `homebrew_dir` | Path to the Homebrew prefix (e.g. `/opt/homebrew`). Used to resolve the `container` binary. |
| `log_dir` | Directory where `container.log` is written. |

These are expected to be set in [`playbooks/group_vars/all.yml`](../../playbooks/group_vars/all.yml).

## Notes

- Apple's Container CLI requires macOS 26 Tahoe or later and Apple Silicon.
- `--enable-kernel-install` allows the Container runtime to install its kernel extension on first run; this may prompt for user approval in System Settings on first launch.
- This role installs the Container CLI only. The [`nomad`](../nomad/README.md) role is responsible for installing and configuring [`nomad-driver-container`](https://github.com/anultravioletaurora/nomad-driver-container) to integrate the runtime with Nomad.
