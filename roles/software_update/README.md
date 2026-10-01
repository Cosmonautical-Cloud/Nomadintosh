# software_update

Runs macOS system updates and ensures the Xcode Command Line Tools are installed on the host.

## What it does

1. Downloads all pending macOS system updates via `softwareupdate --download` (does not install them, so reboots are not triggered automatically).
2. Checks whether any downloaded update requires a restart and emits a warning if so — a follow-up run of `reboot.zsh` should be performed in that case.
3. Detects and installs the latest available **Command Line Tools for Xcode** package if one is available. This ensures `git`, `make`, and other build tools are present (required by Homebrew).
   `softwareupdate -l` hides CLT from its default listing unless an on-demand install flag file exists first — the same signal `xcode-select --install` drops to trigger its GUI prompt. This task sets that flag, finds the newest `Command Line Tools for Xcode` label (if any), installs it headlessly via `softwareupdate --install`, then clears the flag — no GUI, no manual `xcode-select --install`. Naturally idempotent: once installed, Apple stops listing it as available, so later runs no-op until the next CLT release.

## No manual setup required

This role runs automatically as a pre-task for every host and requires no configuration.

> **Note:** If the playbook warns that a restart is required, run `./reboot.zsh` to serially reboot all nodes before re-running the main deployment.
