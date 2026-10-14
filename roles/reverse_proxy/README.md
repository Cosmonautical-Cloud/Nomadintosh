# reverse_proxy

Installs [traefik](https://traefik.io/) via Homebrew and hardens it with
[fail2ban](https://www.fail2ban.org/) + `pf`, banning any IP that trips
`traefik`'s access log too many times.

This role doesn't deploy or configure traefik itself — that's a Nomad job
(`traefik` in the separate [`Cosmonautical/Nomad-Jobs`](https://github.com/Cosmonautical-Cloud/Nomad-Jobs)
repo, run via the `raw_exec` driver), which is why this role only installs
the `traefik` formula rather than templating any of its config. It exists
here, as its own opt-in role rather than a Nomad-Jobs concern, because
installing the binary and provisioning the host's firewall/fail2ban are
both host-provisioning jobs, same as every other package this playbook
installs via Homebrew.

## What it does

1. Installs `traefik` via Homebrew — the Nomad job just execs the binary
   this installs (`{{ homebrew_dir }}/bin/traefik`), it doesn't manage the
   package.
2. Installs `fail2ban` via Homebrew.
3. Creates the directory the Nomad job's traefik writes its access log
   into, so fail2ban has somewhere to watch even before that job's first
   deploy.
4. Templates a dedicated fail2ban filter + jail (`jail.d/traefik-abuse.conf`,
   not the shared `jail.local`, so this role never clobbers anything else
   a jail added by hand) — see "The `traefik-abuse` jail" below.
5. Adds a wildcard `anchor "f2b/*"` stanza to `/etc/pf.conf` (marked,
   idempotent `blockinfile`) and enables `pf` if it isn't already, since
   fail2ban's ban action manipulates `pf` tables/anchors rather than
   `iptables` (macOS has no `iptables`).
6. Deploys a `pf-enable` LaunchDaemon that re-enables `pf` and reloads
   `pf.conf` on every boot — macOS doesn't persist `pf`'s enabled state
   across a reboot by itself.
7. Deploys a LaunchDaemon for fail2ban itself (`homebrew.mxcl.fail2ban`,
   matching the label `sudo brew services start fail2ban` would use —
   templated explicitly here instead so Ansible stays in control of
   reload/idempotency), and reloads fail2ban's config in place
   (`fail2ban-client reload`) rather than restarting it when only the
   filter/jail changed.

Tearing down (`reverse_proxy.enabled: false`) reverses all of the above:
unloads both LaunchDaemons, removes the `pf.conf` anchor stanza (reloading
the ruleset), removes the jail/filter files, and uninstalls both `fail2ban`
and `traefik` via Homebrew. It deliberately leaves `pf`'s own
enabled/disabled state alone — something else on the host may depend on it
independently of fail2ban.

## The `traefik-abuse` jail

Bans an IP for `reverse_proxy_fail2ban_bantime` seconds (default 1 hour)
after `reverse_proxy_fail2ban_maxretry` (default 8) matching responses
within `reverse_proxy_fail2ban_findtime` seconds (default 10 minutes),
using `reverse_proxy_fail2ban_banaction` (default `pf[actiontype=allports]`
— blocks the IP entirely at the firewall, not just on 80/443, since these
hosts also front Minecraft/Valheim/Postgres through the same traefik).

"Matching" means a line in the watched log at all: `reverse_proxy_traefik_access_log`
is meant to be traefik's `accessLog` with `filters.statusCodes` already
narrowed down to the codes worth banning over (403/404/418/999 at the time
of writing — see `Nomad-Jobs`' `traefik/README.md`), so every logged
request is already a candidate failure. **This role's
`reverse_proxy_fail2ban_status_codes` default must be kept in sync by hand
with that job's `accessLog.filters.statusCodes`** — the two repos have no
shared source of truth for this list, and this role's filter regex
re-checks the status code defensively, but the log itself is the real
filter.

## Host variables

| Variable | Values | Effect |
|---|---|---|
| `reverse_proxy.enabled` | `true` / `false` / _(absent)_ | Installs and hardens traefik on this host. `false` (not just absent) actively tears everything down — see "What it does" above. Set this on every host the `traefik` Nomad job might land on, not just whichever one currently runs it (it's a `raw_exec` job that migrates between hosts). |

## Configuration

| Variable | Default | Purpose |
|---|---|---|
| `reverse_proxy_traefik_access_log` | `{{ homebrew_dir }}/var/log/traefik/access.log` | Must match the Nomad job's `accessLog.filePath` |
| `reverse_proxy_fail2ban_status_codes` | `[403, 404, 418, 999]` | Must match the Nomad job's `accessLog.filters.statusCodes` |
| `reverse_proxy_fail2ban_jail_name` | `traefik-abuse` | Jail/filter name, and the `jail.d`/`filter.d` filename |
| `reverse_proxy_fail2ban_maxretry` | `8` | Matches within `findtime` before a ban |
| `reverse_proxy_fail2ban_findtime` | `600` (10 min) | Sliding window `maxretry` is counted over |
| `reverse_proxy_fail2ban_bantime` | `3600` (1 hour) | Ban duration |
| `reverse_proxy_fail2ban_banaction` | `pf[actiontype=allports]` | fail2ban action — see `{{ homebrew_dir }}/etc/fail2ban/action.d/pf.conf` for the other `pf[...]` options |
| `reverse_proxy_pf_conf_path` | `{{ config_dir }}/pf.conf` | Where the wildcard anchor is inserted |

All other paths (`homebrew_dir`, `config_dir`, `log_dir`, `launch_daemons_dir`)
come from [`playbooks/group_vars/all.yml`](../../playbooks/group_vars/all.yml),
same as every other role.
