# Maintaining bootstrap

Run `./bootstrap.sh --list` to find component names. Use `nothing --only NAME
--dry-run` to inspect one installer, then omit `--dry-run` to run it. Profiles and
CLI options still work from any current directory.

## Where to edit

| File | Responsibility |
| --- | --- |
| `../bootstrap.sh` | Loads the modules and starts the runner |
| `components.sh` | One declaration per component, in execution order; named groups |
| `profiles.sh` | Default selections for desktop, server, nothing, and test |
| `versions.sh` | Release versions and default installation methods |
| `installers/*.sh` | Installation recipes and project-specific helpers |
| `lib.sh` | Shared Git, download, build, apt, and generated-file helpers |
| `registry.sh`, `cli.sh`, `runner.sh` | Selection, arguments, confirmation, execution, reporting |
| `paths.sh` | User-overridable XDG, source, installation, and cache locations |

For another Ubuntu base package, edit the `apt_install` list in
`installers/system.sh`. Give software its own component when it needs an
independently selectable installation recipe. Related components can share a file,
as the scientific libraries and the mail tools do.

## Add software

1. Copy `installer-template.sh` to `installers/example.sh` and edit
   `install_example`. Sourced files must only define functions; downloads, directory
   creation, and other work belong inside the installer function.
2. Add its version to `versions.sh`, for example `: "${EXAMPLE_VERSION:=1.2.3}"`.
3. Add one declaration to `components.sh`, after any providers it needs:

   ```bash
   register_component example \
       --installer install_example --file example.sh \
       --method 'pinned source release'
   ```

4. Add `example` to the appropriate list in `profiles.sh` if it should be a default.
   Otherwise it remains available through `--only` and `--enable`.
5. Extend the CLI checks for any new profile rules or behavior, then run the
   validation commands below. Ordinary component selection is checked for every
   registered component automatically.

There are no separate name lists, `DO_*` flags, reset functions, or execution guards
to update. One registry entry supplies the plan description, implementation, and
selection state. The runner uses that same ordered plan for installation.

Registration options:

| Option | Meaning |
| --- | --- |
| `--installer FUNCTION` | Function called once when this component is selected |
| `--file FILE.sh` | File under `installers/` defining that function |
| `--method TEXT` | Description printed in the plan |
| `--sudo true` | Component needs sudo; defaults to false |
| `--risky true` | Adds it to `RISKY_COMPONENTS`; never allowed in profile defaults |
| `--requires LIST` | Comma-separated components automatically selected with it |
| `--plan FUNCTION` | Optional function printing additional read-only plan details |

Required components must be registered earlier. Explicitly skipping a required
component is an error. Build tools that the host can already provide do not need
their own mandatory component: for example, `git-lfs` can use an existing Go
installation. Order selected providers before their consumers in the registry.
The server profile rejects defaults marked as requiring sudo. Explicit opt-ins
can still request those components.

Groups such as `science` and `desktop-apps` expand to concrete components. Keep their
membership in `components.sh`. `--skip science` removes its members; it does not
disable separately selected SageMath or polymake.

## Writing an installer

Use `local` variables, quoted arguments, and the shared helpers. `build_and_install
"Name"` runs make with the configured job count, followed by `make install`.
Additional arguments are passed to make as individual words:

```bash
build_and_install "Example" "PREFIX=$HOME/.local"
build_and_install "System tool" --system
```

For CMake or Ninja, invoke those commands directly with quoted arguments. Avoid
shell command strings and `eval`. `clone_or_update` preserves dirty checkouts,
requires an explicitly configured matching origin, and only fast-forwards branches.
It can also check out a release tag without attempting to merge a remote branch.

An installer returns zero when its work is complete. A failing command stops the
run and records the current component. Call `skip_component 'reason'; return 0`
when an explicit prerequisite or optional source is unavailable. Use
`component_incomplete 'reason'` if useful work completed but an optional part failed.
The final report distinguishes these results from success.

Do not wrap a multi-command installer in `if`, `!`, or `||`: Bash disables
`errexit` throughout functions called in those contexts. Handle expected failures
around the particular command, or check every failure explicitly in such a helper.

Persistent configuration belongs in repository assets distributed by
`../makesymlinks.sh`. Its targeted `nothing --fontconfig`, `nothing --neovim`, and
`nothing --user-dirs` options support configuration needed by individual installers.
System assets are installed from repository files. For generated files containing
host paths, use `write_generated_file PATH [MODE]` with a heredoc; it backs up
changed paths and never writes through an existing symlink.

## Suckless tools

`dwm` still selects all five maintained tools and their desktop integration.
`installers/suckless.sh` delegates source handling to `../scripts/lib/suckless.sh`.
Commits and repository URLs remain exclusively in `../config/suckless.lock`.
Bootstrap builds committed snapshots in the cache; source editing, upstream
merging, and pinning follow [SUCKLESS_WORKFLOW.md](../SUCKLESS_WORKFLOW.md).
The removed `wipe-suckless` component is rejected as an unknown component.

## Run reports and validation

`$XDG_STATE_HOME/bootstrap/last-run` records selected, completed, skipped, incomplete,
and failed components. `status` is `running`, `success`, `partial`, or `failed`.
Partial runs return zero so optional omissions can finish; inspect the report to
identify them. Required command failures return the failing command's status.
Cancelled plans, listings, and dry runs do not write run state.

```bash
bash -n bootstrap.sh makesymlinks.sh tests/bootstrap_cli.sh
for script in bootstrap/*.sh bootstrap/installers/*.sh; do bash -n "$script"; done
bash tests/bootstrap_cli.sh
bash tests/suckless_workflow.sh
./bootstrap.sh desktop --dry-run
./bootstrap.sh server --dry-run
git diff --check
```

The CLI checks include isolated runner fixtures, use temporary HOME/XDG paths,
and do not install software. The suckless checks build tiny local fixtures and
exercise pinning without touching the maintained repositories.
