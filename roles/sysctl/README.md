# sysctl

Applies a list of kernel `sysctl` tunables on boot via a LaunchDaemon, since macOS doesn't reliably honor `/etc/sysctl.conf`.

## What it does

1. Renders a small shell script (`sysctl-tuning.sh`) that runs `sysctl -w` for every entry in `sysctl_settings`.
2. Installs a `LaunchDaemon` (label `sysctl_launchdaemon_label`, defaults to `cloud.cosmonautical.sysctl-tuning`) into `launch_daemons_dir` (defaults to `/Library/LaunchDaemons`, defined in [`playbooks/group_vars/all.yml`](../../playbooks/group_vars/all.yml)) with `RunAtLoad` that executes that script — so the settings are re-applied on every boot, not just the current session.
3. If the rendered script or plist changed, reloads the LaunchDaemon immediately so the new values take effect on this run too (no reboot required) — though note that already-running processes keep whatever backlog/limits their listening sockets were opened with; they need to restart themselves to pick up a new value.

## Configuration

Override `sysctl_settings` (a list of `{name, value}`) in host or group vars to add more tunables. Defaults to:

```yaml
sysctl_settings:
  - name: kern.ipc.somaxconn
    value: 1024
```

`kern.ipc.somaxconn` is macOS's cap on how many pending (not-yet-`accept()`ed) connections a listening socket can queue. The default of 128 is a dated, low BSD default — under real concurrent load (e.g. multiple devices syncing Nextcloud at once) it fills up fast, and anything past it gets an instant `ECONNREFUSED` rather than queuing. 1024 matches typical Linux server defaults.
