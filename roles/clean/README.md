# clean

Runs `brew cleanup` on the host.

## What it does

1. Runs `brew cleanup`, which removes old installed versions of upgraded formulae still sitting in the Homebrew Cellar, plus stale entries in Homebrew's download cache.

## Why this exists

`community.general.homebrew: state: latest` (used by the `nomad`, `consul`, and `podman` roles) upgrades a formula but never removes the previous version's files - Homebrew leaves them in place unless something explicitly runs `brew cleanup` afterward. Left unchecked, every upgrade across every Homebrew-managed formula on a host accumulates old Cellar versions indefinitely.

## Usage

This role is used by the `playbooks/clean.yml` playbook, invoked via `./clean.zsh`.

```bash
./clean.zsh
```

## No manual setup required

No configuration is needed.
