# release_archives

Installs version-pinned tools that ship as release archives (zip/tar) rather than through a package manager — or whose package manager can't pin versions.

## What it does

For each entry in the merged `release_archives` list:

1. Creates `<dest>/<version>` (owned by `owner`, default `ansible_user`) and unpacks `url` into it, unless a completion marker from a previous run is already there.
2. Points `<dest>/current` at the unpacked tree. If the archive unpacks to a single top-level directory (most do — `maestro.zip` unpacks to `maestro/{bin,lib}`), `current` points *into* it, so `<dest>/current/bin` is the same shape for every archive.
3. With `prune` (default `true`), removes every other directory under `<dest>` — leftovers from earlier versions. `<dest>` is treated as belonging to this archive; set `prune: false` if it's shared.

## Variables

| Variable | Description |
|---|---|
| `release_archives` | List of `{name, version, url, dest, owner?, prune?}` |
| `release_archives__<suffix>` | Any number of extra lists, merged in (sorted by variable name) — lets a group add archives without repeating the base list |

```yaml
release_archives__ci:
  - name: maestro
    version: "2.5.1"
    url: https://github.com/mobile-dev-inc/maestro/releases/download/cli-2.5.1/maestro.zip
    dest: /opt/maestro          # -> /opt/maestro/2.5.1, /opt/maestro/current -> 2.5.1/maestro
```

Track `version` with Renovate by putting it in its own variable with a `# renovate:` comment, and templating it into `version` and `url`.
