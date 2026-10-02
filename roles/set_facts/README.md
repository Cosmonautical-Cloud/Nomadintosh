# set_facts

Resolves the Nomad and Consul datacenters from DNS, and fails early on hosts that can't be resolved.

## What it does

1. Asserts `inventory_hostname` is a fully qualified name (`host.<datacenter>.<tld>`) — not an IP and not a short name. Use `ansible_host` to connect by IP.
2. Sets `datacenter` — this host's **Nomad** datacenter — to the second-to-last DNS label: `hopper.jellify.app` → `jellify`.
3. Sets `consul_datacenter` — this host's **Consul** datacenter — to, in order: `existing_consul_datacenter` if set; else the domain label shared by every `server.enabled: true` host in the inventory; else this host's own domain label (a client-only run with no servers in its inventory).
4. Asserts the `server.enabled` hosts share a single domain label — they form one Consul datacenter.

The two differ on purpose: a Nomad datacenter is only a scheduling label, but a Consul datacenter is a separate cluster with its own servers. Clients in `jellify.app` join the `cosmonautical` Consul servers, so their Consul datacenter is `cosmonautical` while their Nomad datacenter is `jellify`.

## Usage

`playbooks/deploy.yml` runs it first, tagged `always` (the `consul` and `nomad` templates read these facts, so it has to run even on `--tags` runs).

## No manual setup required

No variables need to be set. Inventory groups play no part in datacenter resolution — they're free for roles and Nomad meta.
