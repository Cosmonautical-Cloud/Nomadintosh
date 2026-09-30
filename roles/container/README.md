# container

Installs or removes [Apple's Container CLI](https://github.com/apple/container) based on `container.enabled`, registering it as a LaunchAgent so the container system starts automatically at login.

## What it does

`container.enabled: true` (`tasks/setup.yml`):

1. Installs or upgrades the `container` package via Homebrew.
2. Templates a LaunchAgent plist (`com.apple.container.plist`) into `~/Library/LaunchAgents/`.
   - On first install: bootstraps the agent into launchd with `launchctl bootstrap`.
   - On upgrade: restarts the existing agent with `launchctl kickstart -k`.
3. Asserts that the container system is running by calling `container system status`.

The LaunchAgent invokes `container system start --enable-kernel-install` at login, writing stdout and stderr to `{{ log_dir }}/container.log`.

`container.enabled: false` (`tasks/teardown.yml`): unloads the LaunchAgent (`launchctl bootout`, if loaded), removes its plist, and uninstalls the `container` package via Homebrew. Nomad's `nomad-driver-container` plugin is torn down separately by the `nomad` role (see its README), which is also conditioned on `container.enabled`.

`container` absent entirely — this role isn't included at all (see `playbooks/nomadintosh.yml`); a host that's never mentioned `container` is left alone either way.

## Host variables

| Variable | Values | Effect |
|---|---|---|
| `container.enabled` | `true` / `false` / _(absent)_ | Install, uninstall, or don't manage the Container CLI on this host |

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
