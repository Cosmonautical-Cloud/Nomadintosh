# thunderbolt_link

Gives one Thunderbolt port a static point-to-point address, outside the Thunderbolt Bridge, so two Macs cabled together can run MLX distributed inference over it. MLX's `jaccl` backend does RDMA over Thunderbolt 5, and it needs both an address and an `rdma_<interface>` device on that port.

## What it does

1. Disables the `Thunderbolt Bridge` network service. The bridge otherwise owns every Thunderbolt port.
2. Renders `thunderbolt-link.sh`, which takes the interface out of `bridge0`, gives it `address` with a /30 netmask, and adds a host route to `peer` through it. This is what `mlx.distributed_config --auto-setup` runs by hand, but that doesn't survive a reboot.
3. Installs a LaunchDaemon (label `cloud.cosmonautical.thunderbolt-link`) that runs the script at load and every `thunderbolt_link_interval` seconds (60). The port has no address until the cable is up, so applying it only at boot isn't enough. The script only changes what's missing.
4. Warns if `ibv_devices` doesn't list `rdma_<interface>`.

## Configuration

Nothing happens unless a host sets `thunderbolt_link`:

```yaml
taurus.cosmonautical.cloud:
  thunderbolt_link:
    interface: en2
    address: 172.31.250.1
    peer: 172.31.250.2
orion.cosmonautical.cloud:
  thunderbolt_link:
    interface: en3
    address: 172.31.250.2
    peer: 172.31.250.1
```

`interface` is whichever port the cable is in. After plugging it in, `networksetup -listallhardwareports` maps `Thunderbolt N` ports to `enN`, and `ifconfig enN` shows `status: active` on the right one.

## Before the first run

RDMA can only be enabled from macOS Recovery. On each Mac: shut down, hold the power button until the startup options appear, open Options → Utilities → Terminal, run `rdma_ctl enable`, and reboot. `rdma_ctl status` then says `enabled`, and `ibv_devices` lists `rdma_enN` devices. Both Macs need Thunderbolt 5 ports and macOS 26.2 or later, connected port to port with a Thunderbolt 5 cable.
