# uid_normalize

Changes `ansible_user`'s (violet's) UID on macOS to a fixed value and re-owns
their known local directories to match. Needed on jellify hosts because the
Jellify NFS export (unlike cosmonautical's Cosmonautical/Books/ROMs/Music
shares, which the NAS squashes to a fixed uid/gid regardless of the client -
see nomad-jobs' `AGENTS.md` gotcha #4) checks the real client UID, and
expects 1000 to match the NAS-side account.

**Deliberately not part of any normal deployment pass.** This changes a live
user account's numeric identity and re-owns files by UID - a mistake here
can lock the account out of its own files or silently orphan things this
role doesn't know to re-own. Tasks here are tagged `never`, Ansible's
built-in "skip unless explicitly named" tag, so a plain `./deploy.zsh` run
(or any tags-less/`--tags` run that doesn't name it) never touches this.
Run it deliberately, one host at a time:

```
ansible-playbook playbooks/nomadintosh.yml --limit galileo.jellify.app --tags uid_normalize
```

Ideally with the target user logged out of any GUI session on that host
first, and reboot afterward so anything already running under the old UID
picks up the change cleanly.

## What it does

1. Reads the user's current `UniqueID` via `dscl`.
2. Aborts if `uid_normalize_target` is already assigned to a *different*
   account on the host - `dscl -change` would otherwise happily create a
   second account with the same UID, which is almost never what you want.
3. If the current UID doesn't already match, changes it via
   `dscl . -change /Users/<user> UniqueID <old> <new>`.
4. Recursively `chown`s each path in `uid_normalize_paths` from the old UID
   to the new one.

## Configuration

| Variable | Default | Purpose |
|---|---|---|
| `uid_normalize_target` | `1000` | The UID to set |
| `uid_normalize_paths` | the user's home directory, `homebrew_dir`, `nomad_working_dir` | Paths to re-own after the UID change |

## Caveats

- Only re-owns the paths listed. Anything else already on the host and
  owned by the old UID (Homebrew-installed services' own data directories
  not covered here, Spotlight/TCC state, etc.) isn't touched - lowest-risk
  on a freshly provisioned host with little pre-existing state, which is
  the situation this was written for (brand-new jellify hosts), not a
  years-old host with data scattered everywhere.
- Only changes the UID, not group membership/GID.
- Idempotent: a host already at the target UID is a no-op.
