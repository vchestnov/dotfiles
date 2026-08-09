# Repository Guidance

## Script responsibilities

### `bootstrap.sh`

- Installs and builds software for Ubuntu 24.04 desktop and no-sudo server environments.
- Resolves `desktop`, `server`, `nothing`, or `test` into components before doing work.
- Supports `--dry-run`, `--only`, `--enable`, `--skip`, `--yes`, and `--list`.
- Prints one execution plan, then asks once for confirmation.
- Keeps destructive actions outside profiles. Noninteractive risky actions also require `--allow-risky`.
- Uses shared helpers for apt refreshes, downloads, Git updates, builds, logging, and run-state reporting.
- Stores run status in `$XDG_STATE_HOME/bootstrap/last-run`.

When adding a component, update all relevant places: `COMPONENTS`, reset state, `set_component`,
`component_enabled`, `component_method`, profile defaults, execution guard, and CLI tests.

### `makesymlinks.sh`

- Distributes Git-backed configuration from `DOTFILES_DIR` into `$HOME` and XDG locations.
- Uses the same four profile names, but its flags describe configuration links rather than installers.
- Creates missing parent directories, preserves existing paths as timestamped backups, and replaces
  incorrect symlinks safely.
- Supports standalone inspection with `--dry`.
- Must not install packages, clone repositories, or generate machine state.

`bootstrap.sh` calls `makesymlinks.sh` with the selected profile. Keep profile meaning aligned, but do
not force both scripts to share identical flags: installation and configuration have different scopes.

## Shell style

- Bash scripts use `#!/usr/bin/env bash` and `set -Eeuo pipefail`.
- Quote paths and expansions. Prefer `[[ ... ]]`, arithmetic `(( ... ))`, arrays, and `local` variables.
- Reuse helpers instead of duplicating apt, Git, download, backup, or link logic.
- Keep sections named and ordered. Put reusable functions before profile resolution; gate execution
  sections with explicit component flags.
- Log intent, success, warnings, and actionable failures. Do not hide meaningful errors with `|| true`.
- Avoid `eval`, implicit word splitting, direct edits to shell rc files, and writes through symlinks into
  tracked configuration.
- Prefer idempotent operations. Never reset or overwrite dirty source checkouts; update clean Git trees
  by fast-forward only.

## Environment and safety practices

- Follow XDG paths. Install user software under `~/.local`, sources under `${SRC_DIR:-$HOME/soft}`,
  and build/download artifacts under `$XDG_CACHE_HOME/bootstrap`.
- Use apt for Ubuntu base packages and libraries. Prefer user-local upstream installs where useful.
- Track configured upstream branches for active scientific projects; pin foundational release archives
  and centralize their defaults near bootstrap path setup.
- Keep `server` defaults free of sudo-requiring components.
- Add destructive or strongly personal behavior only as a named entry in `RISKY_COMPONENTS`; never make
  it a profile default.
- Put persistent configuration in the repository and link it with `makesymlinks.sh`. Keep secrets,
  credentials, generated state, and host-local data outside Git.
- Resolve repository assets relative to `SCRIPT_DIR` or `DOTFILES_DIR`; do not assume the current directory.
- Preserve unrelated working-tree changes. Never clone or hard-reset this dotfiles repository from bootstrap.

## Validation

Run after changing either script:

```sh
bash -n bootstrap.sh makesymlinks.sh tests/bootstrap_cli.sh
bash tests/bootstrap_cli.sh
./bootstrap.sh desktop --dry-run
./bootstrap.sh server --dry-run
git diff --check
```

Extend `tests/bootstrap_cli.sh` whenever profiles, components, CLI behavior, risk gates, or run-state output change.
