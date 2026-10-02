# homebrew_packages

Resolves the inventory's Homebrew lists, trusts the taps they need, clears conflicting formula versions, and hands off to [`geerlingguy.mac.homebrew`](https://github.com/geerlingguy/ansible-collection-mac) to install Homebrew, taps, and packages.

## What it does

1. **Merges** `additional_homebrew_packages` and `additional_homebrew_taps` with every `additional_homebrew_packages__<suffix>` / `additional_homebrew_taps__<suffix>` variable visible to the host (sorted by name). Ansible replaces lists across group/host precedence, so this is how a group adds packages without repeating the `all`-level list.
2. **Resolves taps.** A fully qualified package (`user/tap/formula`) implies its tap — listing a tap's formula is the decision to use it — so it's added to the tap list without being listed separately. `homebrew/*` taps are skipped (official, always trusted, and tapping `homebrew/core` would clone it in full).
3. **Trusts** every resolved tap via the `homebrew_trust` role. Homebrew 7+ won't load formulae from untrusted third-party taps.
4. **Removes conflicting versions** for `exclusive` entries: every other version of that formula — the unversioned one from `homebrew/core` or its own tap, and any other `@version` — is uninstalled first. Needed for versioned formulae that all link the same binary (`oven-sh/bun/bun@<version>` → `bin/bun`), where a leftover version makes the new one fail to link after a version bump. Opt-in, because keg-only versions (`openjdk@17` next to `openjdk@21`) coexist fine.
5. Runs `geerlingguy.mac.homebrew` with `hashicorp/tap` plus the resolved taps and the package names.

## Variables

| Variable | Default | Description |
|---|---|---|
| `additional_homebrew_packages` (+ `__<suffix>`) | `[]` | Formula names, or `{name, exclusive}` |
| `additional_homebrew_taps` (+ `__<suffix>`) | `[]` | Extra taps (`user/repo` or `{name, url}`), only needed for taps no package names |
| `homebrew_packages_base_taps` | `[hashicorp/tap]` | Taps every host gets |

```yaml
additional_homebrew_packages__ci:
  - name: oven-sh/bun/bun@1.3.4   # taps and trusts oven-sh/bun
    exclusive: true               # uninstalls bun / other bun@ versions first
  - openjdk@17
```
