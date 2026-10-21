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

`bootstrap.sh` loads modules from `bootstrap/`. Register each component once in
`bootstrap/components.sh`, in execution order. Put its installer function in
`bootstrap/installers/`, release defaults in `bootstrap/versions.sh`, and optional
profile membership in `bootstrap/profiles.sh`. See `bootstrap/README.md` and
`bootstrap/installer-template.sh`. Extend CLI checks for changed behavior.

Registry declarations derive component lists, selection, sudo requirements, and
`RISKY_COMPONENTS`. Required components must be registered earlier. Installer modules
must only define functions when sourced, so plans and listings cannot change the host.
The runner records completed, skipped, incomplete, and failed components. Keep installer
calls outside conditional contexts so Bash error handling remains active.

The `dwm` component installs all five tools from `config/suckless.lock` through
`scripts/lib/suckless.sh`, using fresh cached snapshots. Follow `SUCKLESS_WORKFLOW.md`
for source maintenance. Bootstrap must not patch these tools, merge upstream, change
existing remotes, or delete their maintained checkouts. `wipe-suckless` was removed.

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
- Keep functions named and modules focused. Put reusable helpers in `bootstrap/lib.sh`
  or the appropriate installer module; dispatch selected components through the registry.
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
- Mark destructive or strongly personal components with `--risky true` in the registry;
  this derives `RISKY_COMPONENTS`. Never make them profile defaults.
- Put persistent configuration in the repository and link it with `makesymlinks.sh`. Keep secrets,
  credentials, generated state, and host-local data outside Git.
- Resolve repository assets relative to `SCRIPT_DIR` or `DOTFILES_DIR`; do not assume the current directory.
- Preserve unrelated working-tree changes. Never clone or hard-reset this dotfiles repository from bootstrap.

## Archive policy

- Keep obsolete source, configuration snapshots, and historical notes worth preserving in `old/`.
- `garage/` is ignored local scratch; do not use it for history intended to be included in Git.
- Document archived files and their current replacements in `old/README.md`.
- Preserve historical source contents; do not modernize archived scripts or source them from active code.
- Keep secrets, generated caches, and host-local state outside the versioned archive.

## Validation

Run after changing either script:

```sh
bash -n bootstrap.sh makesymlinks.sh tests/bootstrap_cli.sh
for script in bootstrap/*.sh bootstrap/installers/*.sh; do bash -n "$script"; done
bash tests/bootstrap_cli.sh
bash tests/suckless_workflow.sh
./bootstrap.sh desktop --dry-run
./bootstrap.sh server --dry-run
git diff --check
```

Extend `tests/bootstrap_cli.sh` whenever profiles, components, CLI behavior, risk gates, or run-state output change.
