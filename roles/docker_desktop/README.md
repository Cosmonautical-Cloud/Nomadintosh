# docker_desktop

Installs or removes [Docker Desktop](https://www.docker.com/products/docker-desktop/) on the host via Homebrew Cask, based on `docker.enabled`.

## What it does

- `docker.enabled: true` — installs the `docker-desktop` cask if not already present.
- `docker.enabled: false` — uninstalls it if present. Nomad's `docker` plugin config is already conditioned on `docker.enabled` in `roles/nomad/templates/nomad.d/server.hcl.j2`, so disabling here also drops it from `server.hcl` on the same run.
- `docker` absent entirely — this role isn't included at all (see `playbooks/deploy.yml`); a host that's never mentioned `docker` is left alone either way.

## Host variables

| Variable | Values | Effect |
|---|---|---|
| `docker.enabled` | `true` / `false` / _(absent)_ | Install, uninstall, or don't manage Docker Desktop on this host |

## Manual setup required

Docker Desktop requires a user to **accept the licence agreement and complete the first-run setup** through the GUI before it can be used. This role does not automate that step.
