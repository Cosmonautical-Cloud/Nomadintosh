# Nomad Jobs (removed)

This playbook used to template and register a handful of Nomad job specs
directly (`actions-runner`, `minecraft`) via a dedicated Ansible role and
`playbooks/jobs.yml`, invoked through `run-jobs.zsh`. That role and playbook
were removed 2026-09-05 — see the "Scope" section in
[README.md](README.md) — once job deployment moved to dedicated repos:
[`Jellify/Nomad-Jobs`](https://github.com/anultravioletaurora/Nomad-Jobs)
(Terraform-managed) and a legacy hand-deployed `nomad-jobs` repo.

`gh_actions`/`minecraft` inventory flags may still appear on some hosts in
`inventory/hosts.yml` from before this removal — they're inert now and don't
trigger any behavior in this playbook.

This file is kept only so a link to it doesn't 404; the job descriptions it
used to document now live as `.nomad.hcl` files in the repos above.
