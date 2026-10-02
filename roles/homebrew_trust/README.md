# homebrew_trust

Marks third-party Homebrew taps as trusted.

## Why this exists

Homebrew 7 refuses to load formulae or casks from a non-official tap unless it's trusted (`brew trust`, stored per-user in `~/.homebrew/trust.json`). The one exception is a fully-qualified name given on the command line (`brew install hashicorp/tap/nomad`), which Homebrew allows for that single invocation. That's why Consul and Nomad installs never tripped over it, but anything that later loads the tap without the full name on the command line (`brew upgrade`, `brew outdated`, `brew bundle`) skips or rejects untrusted formulae. Neither `geerlingguy.mac.homebrew` nor `community.general.homebrew` knows about `brew trust`, so this role fills the gap.

## What it does

1. Skips everything if Homebrew isn't installed yet. On a fresh host's first run, packages listed fully qualified still install through the exception above, and the next run trusts their taps.
2. Runs `brew trust --tap <name>` for each entry in `homebrew_trust_taps`, reporting `changed` only when a new trust entry was written.

## Variables

| Variable | Default | Description |
|---|---|---|
| `homebrew_trust_taps` | `[]` | Taps to trust. Plain `user/repo` strings or `{name: user/repo}` dicts (the same shapes `homebrew_taps` accepts) |
| `homebrew_dir` | _(from `playbooks/group_vars/all.yml`)_ | Homebrew prefix used to find `brew` |

## Usage

The `homebrew_packages` role includes it with every tap it resolved (explicit `additional_homebrew_taps` plus the taps of fully qualified packages), before installing anything.
