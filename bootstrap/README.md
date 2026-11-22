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

## Command-line tools

Both `desktop` and `server` include `zoxide`, `eza`, `dust`, `tlrc`, `duf`, and
`procs`. Each is independently selectable, for example:

```bash
./bootstrap.sh nothing --only zoxide,eza,dust,tlrc,duf,procs --dry-run
```

These components compile pinned upstream source releases and install into
`$BIN_DIR` (default `~/.local/bin`) without sudo. Versions are overridable through
`ZOXIDE_VERSION`, `EZA_VERSION`, `DUST_VERSION`, `TLRC_VERSION`, `DUF_VERSION`, and
`PROCS_VERSION`. Source trees live under `$SRC_DIR`, downloaded archives under
`$XDG_CACHE_HOME/bootstrap/downloads`, and build output under `$BUILD_DIR`.
Repeated runs reuse those archives and build output.

The Rust tools use `ensure_cargo_toolchain` to provision a user-local compiler
(`CLI_RUST_TOOLCHAIN_VERSION`, default `1.96.0`) without changing the user's
default toolchain. They require a C compiler/linker; Eza builds its bundled
libgit2 and also needs CMake. Selecting `duf` automatically selects the existing
user-local `go` toolchain component. The `tlrc` component installs the command
`tldr`; run `tldr --update` to populate its page cache. To enable zoxide's shell
integration, follow its [upstream setup instructions](https://github.com/ajeetdsouza/zoxide#installation)
in the repository-managed shell configuration.

## Vim

Vim is built without embedded Python (`-python`, `-python3`), so its executable
does not depend on a particular `libpython` version. The configured plugins use
Vimscript and external tools. Python language servers, TeX inverse search, and
the custom `:MathematicaCleanup` formatter run Python as a separate process;
they do not require Vim's Python interface. The formatter uses only Python's
standard library and works with Python 3.12.

Rebuild an existing installation with `./bootstrap.sh nothing --only vim`.
Check the result with `vim --version` and `ldd ~/.local/bin/vim`.

## pySecDec

Install with `./bootstrap.sh server --only pysecdec`. This optional component
installs the pinned `PYSECDEC_VERSION` release and its dependencies into
`$XDG_DATA_HOME/pysecdec`, preferring binary wheels. It requires Python 3.8+ with
venv support, a C++ compiler, and GNU Make 4+; it never uses sudo. pySecDec keeps
its bundled native tools within the environment. Existing scientific libraries
and the system Python environment are not modified.

Activate with `source ~/.local/share/pysecdec/bin/activate`, or invoke
`~/.local/share/pysecdec/bin/python` directly. Override `PYSECDEC_PYTHON` to select
the Python used to create the environment, and `PYSECDEC_VENV_DIR` to change its
location. Existing unrecognized environments are preserved with an actionable
error instead of being overwritten.

Run `scripts/check-pysecdec-box1l` after installation. It downloads the upstream
example matching the installed release, generates and compiles the integral,
and compares its three Laurent coefficients at `s=4`, `t=-0.75`, `s1=1.25`,
`msq=1` with the upstream analytic reference. Comparisons allow five estimated
integration errors per real/imaginary part plus rounding of the reference.
Every run gets a fresh directory under `$BUILD_DIR` with generation/build logs,
the numerical output, and `validation.json`. `PYSECDEC_JOBS` controls compilation
parallelism. This numerical check needs downloads and a compiler; the isolated
`tests/pysecdec_installer.sh` fixtures run as part of the normal CLI checks.

## AMFlow 2.0

`./bootstrap.sh nothing --only amflow` updates AMFlow by fast-forward when its
checkout is clean, then builds `diffeq_solver/desolver` and the WSTP `link` binary.
`science-extra` also selects this component. Dirty source trees, reducer paths,
example settings, and calculation results are preserved. AMFlow uses the shared
Git update helper; no release pin is needed.

Ubuntu 24.04 desktop base packages include `libgmp-dev`, `libmpfr-dev`,
`libmpc-dev`, `libyaml-cpp-dev`, `libboost-dev` (Boost >= 1.83), and `mpsolve`.
On servers, supply these dependencies in the system or `$SCI_PREFIX` first;
missing dependencies produce an incomplete component report. No sudo or
shell startup edits are performed by the AMFlow installer.

The installer detects the WSTP Developer Kit through the installed Wolfram
commands, including symlinked installations such as `/opt/bin/math`, without
starting a licensed kernel. Override detection with `AMFLOW_WSTP_DIR` pointing
at `.../SystemFiles/Links/WSTP/DeveloperKit/Linux-x86-64`. `AMFLOW_DIR` overrides
the checkout location (default `$SCI_REPOS_DIR/amflow`). Compilation and generated
configuration stay under `$BUILD_DIR`; only the executables are installed into
the checkout. Existing differing executables are backed up.

The installer adds local `.git/info/exclude` rules only for `diffeq_solver/desolver`,
`diffeq_solver/link`, and their `.backup.*` files. It adds these rules
before checking an existing clone for updates, including clones built by older
installers. Existing exclude rules are preserved, and repeated runs leave them
unchanged. Upstream `.gitignore` stays untouched; tracked edits and other
untracked files still prevent automatic updates.

If the WSTP kit is missing, only `desolver` is built and the component is marked
incomplete. The traditional Wolfram backend is available with
`SetAMFOptions["DESolver" -> "MMA"]`. A working Wolfram licence is required to
validate package loading, the WSTP link, and reducer calculations; building the
link alone does not validate them. Run numerical checks in a temporary copy of
`diffeq_solver/check` so generated results do not overwrite scientific work.

## Blade and FLINT upgrades

Blade's native search and solver code uses full FLINT directly, in addition to
its FiniteFlow dependency. The minimal `flint-finiteflow-dep` library does not
provide the matrix routines Blade needs.

After a FLINT ABI change, rebuild Blade with an unused `BLADE_BUILD_DIR` under
`$BUILD_DIR` so CMake selects the current headers and libraries through
`SCI_PREFIX`. Preserve the old installed tools before replacing them, then check
`bin/{redg1,fitrel,ssolve,recmod,dynamicrr}` and `lib/libsearch.so` with `ldd -r`.
Validate a forced `"BladeMode" -> Full` reduction against plain IBP; an automatic
one-loop example can choose plain IBP and leave the compiled search path untested.
Keep the custom-cache patch on the maintained Blade branch when rebuilding.

## Language servers

The LSP installer reuses an existing clangd by default. Set
`CLANGD_INSTALL_METHOD=existing` to require that behavior, or select `tar`, `git`,
or `apt` explicitly to replace it. Broken Python LSP virtual environments are
preserved as timestamped backups before a new environment is created.

Bash loads nvm with automatic activation disabled, then selects the installed
default from its alias files. This avoids repeated Node processes and version
scans when opening panes. Inherited managed Node selections are preserved;
partial versions and other aliases fall back to nvm's normal activation.

## SSH agent refresh

Core configuration links `config/ssh-agent.bash`; user scripts include
`ssh-agent-socket`. Run `ssh_agent_refresh` to repair a stale shell,
`ssh_agent_refresh --choose` to select an agent, or `ssh_agent_list` to list
reachable sockets. Vim's `:RefreshSSHAuthSock` uses the same resolver.

The third-party `ssh-find-agent` helper is retired; core setup no longer installs
it and Bash no longer sources it. Reload `~/.bashrc` in existing shells to clear
its `ssh_find_agent` and `ssh-find-agent` functions. Use `ssh_agent_refresh --choose`
in place of `ssh_find_agent -c`. Its historical source is kept in
[`old/ssh-find-agent/`](../old/ssh-find-agent/).

The resolver preserves a reachable current agent, including an empty one, then
tries the current tmux session's agent. Discovery recognizes modern `.sshd.` and
`.agent.` names and legacy `/tmp/ssh-*/agent.*` sockets owned by the user.
Ambiguous discovery requires a choice. Checks have a short timeout and never
delete sockets or start agents. The prompt hook reacts to tmux socket changes
without doing discovery on every prompt.

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

Codex is a writable configuration exception: `makesymlinks.sh nothing --codex`
merges shared defaults into a regular local profile and preserves local trust and
preference changes. Its last-defaults snapshot stays in `CODEX_HOME`. Never
symlink the live profile into the repository; see
[shared Codex preferences](../README.md#shared-codex-cli-preferences).

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
bash -n bootstrap.sh makesymlinks.sh tests/bootstrap_cli.sh tests/amflow_installer.sh tests/codex_profile.sh
for script in bootstrap/*.sh bootstrap/installers/*.sh; do bash -n "$script"; done
bash tests/bootstrap_cli.sh
bash tests/amflow_installer.sh
bash tests/codex_profile.sh
bash tests/suckless_workflow.sh
bash tests/vim_mma_cleanup.sh
./bootstrap.sh desktop --dry-run
./bootstrap.sh server --dry-run
git diff --check
```

The CLI checks include isolated runner fixtures, use temporary HOME/XDG paths,
and do not install software. The suckless checks build tiny local fixtures and
exercise pinning without touching the maintained repositories.
