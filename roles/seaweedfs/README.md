# seaweedfs

Installs [SeaweedFS](https://github.com/seaweedfs/seaweedfs) and macFUSE via Homebrew, and creates the directory backing a host's SeaweedFS volume.

## What it does

1. Installs `seaweedfs` via Homebrew.
2. Installs `macfuse` via Homebrew (required to mount SeaweedFS volumes as a filesystem).
3. If `seaweedfs.volume.enabled: true`, creates `seaweedfs.volume.path` as a directory owned by `ansible_user` (group `staff`, mode `0755`).

This role only installs the software and prepares the volume directory — it does not itself register a SeaweedFS host volume with Nomad, start a master/volume server, or template any SeaweedFS configuration. Wiring a `seaweedfs-data` host volume into `nomad.d/server.hcl` is handled by the [`nomad`](../nomad/README.md) role when `seaweedfs.volume.enabled` is set; actually running the master/volume processes is a Nomad job, not this role.

## Host variables

| Variable | Values | Effect |
|---|---|---|
| `seaweedfs.master.enabled` | `true` / _(absent)_ | Include this role for the host, alongside `seaweedfs.volume.enabled` (see `playbooks/nomadintosh.yml`'s gate). Doesn't affect this role's own tasks. |
| `seaweedfs.volume.enabled` | `true` / _(absent)_ | Include this role for the host, and create `seaweedfs.volume.path` as a directory. |
| `seaweedfs.volume.path` | path | Directory to create for the volume's data (e.g. `/opt/seaweedfs/data`). Required when `seaweedfs.volume.enabled: true`. |

## Example

```yaml
cassiopeia.cosmonautical.cloud:
  seaweedfs:
    master:
      enabled: true
    volume:
      enabled: true
      path: /opt/seaweedfs/data
```

## Notes

- macFUSE-mounted SeaweedFS volumes have proven unstable for latency/consistency-sensitive workloads (Postgres, SQLite) in this homelab. Don't back that kind of workload with a FUSE-mounted SeaweedFS volume — use SeaweedFS's S3/WebDAV interfaces, or plain local/NFS storage, for anything that can't tolerate it.
