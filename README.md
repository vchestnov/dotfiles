# dotfiles

Personal dotfiles and bootstrap scripts for a minimal, keyboard-driven Linux environment.

This repository contains configuration files and helper scripts I use to set up and maintain my Linux systems in a reproducible and mostly distribution-agnostic way.

## Overview

The repo is centered around two ideas:

- **Bootstrap once, refine later** — bring a fresh system into a usable state quickly.
- **Minimal but practical** — favor small, composable tools and explicit configuration.

Most of the setup is shell-driven and designed to be readable, hackable, and easy to adapt.

## Structure

- `bootstrap.sh`  
  Installs packages, builds selected software from source, and applies system-level and user-level configuration.  
  Intended to be run on a fresh or semi-fresh system.

- `makesymlinks.sh`  
  Links configuration into `$HOME` and synchronizes writable Codex profiles from shared defaults.

- `config/`, `dotfiles/`, etc.  
  Application-specific configuration (window manager, terminal, editor, CLI tools).

The exact layout may evolve, but the goal is to keep responsibilities clearly separated.

## Usage

Clone the repository somewhere convenient, for example:

```sh
git clone https://github.com/vchestnov/dotfiles.git ~/dotfiles
cd ~/dotfiles
```

Create symlinks:

```sh
./makesymlinks.sh
```

Inspect the resolved desktop plan, then apply it:

```sh
./bootstrap.sh desktop --dry-run
./bootstrap.sh desktop
```

The bootstrap prints the complete component plan and asks once before applying it.
The `server` profile never selects components that require sudo; `nothing` is an
empty base for targeted runs; `test` selects the maintained suckless bundle.
Email setup is included in `desktop` and is opt-in on `server` with `--enable email`.

Useful controls:

```sh
./bootstrap.sh --list
./bootstrap.sh server --dry-run
./bootstrap.sh nothing --only go,git-lfs
./bootstrap.sh desktop --skip tex,email
./bootstrap.sh desktop --enable desktop-apps
```

Bulky application groups (`krita`, `messengers`, and `media`) are optional.
Potentially destructive operations are never profile defaults. They must be
selected explicitly, for example `--enable reset-user-dirs`; combining them with
`--yes` also requires `--allow-risky`.

`makesymlinks.sh` owns distribution and backup of Git-backed configuration.
`bootstrap.sh` invokes it from the current checkout and does not clone or reset
the dotfiles repository.

Installation recipes are under `bootstrap/installers/`. To add software, register
its installer once in `bootstrap/components.sh`; see
[Maintaining bootstrap](bootstrap/README.md) for the template, profiles, and validation.

Tool guides cover [terminal email](EMAIL_SETUP.md), [Vim LSP](LSP_CHEATSHEET.md),
[Telescope](config/nvim/TELESCOPE.md), and the
[Wolfram Tree-sitter integration](config/nvim/WOLFRAM_TREESITTER_NOTES.md).

Validate profile resolution and safety rules without installing anything:

```sh
bash tests/bootstrap_cli.sh
```

### AMFlow 2.0

AMFlow is included in the scientific components and can also be updated on its own:

```sh
./bootstrap.sh nothing --only amflow --dry-run
./bootstrap.sh nothing --only amflow
```

The installer builds the native solver and WSTP link in the cache and backs up
replaced executables. Local Git excludes keep those binaries and backups from
blocking later upgrades; source edits, reducer settings, and calculation results
are preserved. See [AMFlow installation details](bootstrap/README.md#amflow-20)
for dependencies, WSTP detection, and validation limits.

### Shared Codex CLI preferences

See the [Codex permissions and unattended work reference](cheatsheets/cli/codex.md)
(`cht codex`) for approval boundaries, automatic review, and overnight task examples.

The `desktop` and `server` configuration profiles merge the shared
[Codex defaults](config/codex/dotfiles.config.toml) into a regular local file at
`${CODEX_HOME:-$HOME/.codex}/dotfiles.config.toml`. Codex saves settings and project
trust into its active profile, so this file must stay outside Git. To synchronize
just Codex configuration, preview and apply it from this checkout:

```sh
DOTFILES_DIR="$PWD" ./makesymlinks.sh --dry nothing --codex
DOTFILES_DIR="$PWD" ./makesymlinks.sh nothing --codex
command codex --profile dotfiles
```

The shared `bashrc` aliases `codex` to `codex --profile dotfiles`. Open a new
Bash terminal or run `source ~/.bashrc`, then launch with just `codex`.
Use `command codex` to bypass the alias, for example to select another profile.

After transferring repository changes to the server, use the same commands there,
or run `./makesymlinks.sh server` as part of the normal server configuration setup.
The sync requires Python 3.11+ and preserves changed profiles as timestamped
`.bak` copies. Existing profile symlinks are migrated to regular local files;
their contents, including trust records, are preserved. Backups contain the old
contents rather than another link into the repository.
Use a current Codex CLI; separate profile files require version 0.134.0 or later
(see [Codex profiles](https://learn.chatgpt.com/docs/config-file/config-advanced#profiles)).

The shared defaults contain model and reasoning preferences, status line, dense
session picker, status colors, and `Alt-V` / `F1` key bindings. Edit this repository
file to change shared preferences, then transfer and synchronize it on each machine.
The local `.dotfiles-profile-defaults.toml` snapshot records the last shared defaults:
later syncs update or remove defaults that are still unchanged locally. Local
overrides and deletions are preserved, including when the shared value also changes.
On the first sync, existing local settings take precedence. Project trust is never
distributed from the shared template to a new profile.

Changes saved through Codex stay local. Copy only preferences you want to share
back into the repository template. The selected profile overrides matching base
settings; project configuration and explicit CLI flags can override the profile.

Each machine keeps its own `config.toml`, writable `dotfiles.config.toml`, defaults
snapshot, project trust records, login credentials, rules, sessions, history,
caches, and other runtime state. `~/.codex` stays local. Log in separately on each machine.
The `nothing` and `test` link profiles leave Codex alone unless `--codex` is given.

Repository-local agent skills are backed up under `.agents/skills`, with source
metadata in `skills-lock.json`.

### npm global installs and Codex updates

The shared Node shell configuration uses nvm when installed. Without nvm, it
exports `NPM_CONFIG_PREFIX="$HOME/.local"`, including to npm processes started by
Codex. Global installs then use a user-owned directory on desktop and server.
The npm config file keeps `prefix` unset because nvm rejects that setting.

After syncing this checkout, reload the helper in an existing shell and update:

```sh
source "${XDG_CONFIG_HOME:-$HOME/.config}/nvm/shell.bash"
npm config get prefix
npm install -g @openai/codex
```

The prefix should be `~/.local` with system Node, or the selected Node version's
directory under nvm. New Bash terminals load this helper automatically.

## Assumptions

* Ubuntu 24.04 for the desktop profile
* Bash 4 or newer
* A dependency-provisioned Linux host for the no-sudo server profile
* Comfort with terminal workflows
* Willingness to edit scripts rather than treat them as a black box

This repo reflects my preferences; it is not intended to be a universal solution.

## Philosophy

* Prefer plain shell over heavy frameworks
* Prefer explicit configuration over defaults
* Prefer reproducibility over convenience
* Prefer tools that compose well in the terminal

## Notes

- `ff-personal` and `ff-maths` launch the corresponding Firefox
  profiles from the terminal or dmenu. Extra arguments are passed to Firefox,
  for example `ff-maths --new-window https://arxiv.org`.
  The maintained dwm binds Alt+Ctrl+P to `ff-personal --new-tab about:newtab`
  and Alt+Ctrl+M to `ff-maths --new-tab about:newtab`.
  The launchers live in `scripts/`; `makesymlinks.sh desktop` (or `server`)
  links them into `~/.local/bin` with the other user scripts.
  They require Python 3 and resolve display names from Firefox's local profile
  metadata, supporting the newer profile manager and legacy `profiles.ini`.
  Profile directories and browser data stay outside Git. Snap, native, and XDG
  profile locations are searched; set `FIREFOX_PROFILE_ROOT` to the directory
  containing `profiles.ini` and/or `Profile Groups` to select one installation.
- `monitor on` detects the connected external screen and enables it above the
  laptop. It prefers `3440x1440`, then `1920x1080`, then the monitor's preferred
  mode. `monitor off` disables external outputs. All commands configure only
  external outputs; the laptop is used only as a positioning reference.
  `monitor toggle` turns external outputs off if any are active, otherwise on.
  `monitor status` (also the default command) shows connections and active modes.
  Use `monitor menu` for a dmenu chooser, or
  `monitor on --output HDMI-1 --mode 1920x1080` for an explicit override.
  With multiple external screens connected, `on` asks through dmenu unless
  `--output` is given. Add `--dry-run` to preview a layout command, and use
  `--internal NAME` if the laptop output cannot be detected automatically.
  Run it from an X11 session. `makesymlinks.sh` links the helper into
  `~/.local/bin` with the other user scripts; it can also be run directly as
  `./scripts/monitor`. Nothing runs automatically on cable connection.
  At login, the dwm session runs `monitor arrange` once to stack already-active
  external outputs above the laptop, preserving their modes and leaving disabled
  outputs alone. Run `monitor arrange` manually to reapply that positioning.
  Disabling or unplugging an active screen still moves its windows onto the
  remaining screen in dwm; reconnecting does not restore their former placement.
  The maintained dwm binds Alt+Shift+M to `monitor toggle`; Alt+M selects monocle.
- `toggle-monitor-grayscale` toggles all active screens using the Intel display
  driver's CTM through `xrandr`, without restarting a compositor. Use `on` or `off`
  to select a mode, and add an output such as `HDMI-1` to target one screen.
  `status` lists each screen; `--status` prints `grayscale` only when every
  selected screen is grayscale, otherwise `color`, for Vim's automatic sync.
  `trial --seconds 30` restores the original matrices after 30 seconds, or sooner
  with Enter, `q`, or Ctrl+C. `scripts/test-monitor-grayscale-ctm` defaults to this
  trial mode. Run these commands from an X11 session with CTM support; disable any
  old picom grayscale shader before switching. The previous implementation and
  its assets are backed up in [old/grayscale-picom/](old/grayscale-picom/).
- Vim follows the display's CTM state automatically, using `monochrome` in
  grayscale with a subdued gutter and dark fold backgrounds. Returning to color
  restores the previous theme. `Space t g` (or `:GreyscaleToggle`) switches Vim
  manually until the next display transition; `:GreyscaleSync` follows the
  display immediately. Install the theme with `:PlugInstall` if needed.
- In Vim TeX buffers, `Space l v` (or `:TexView`) jumps Zathura to the
  cursor's location in the compiled PDF. Compile with `pdflatex -synctex=1 main.tex`
  (or `latexmk -pdf -synctex=1 main.tex`) first and recompile after edits so the
  PDF and source line numbers agree. The PDF defaults to the source basename.
  If that PDF is absent, Vim uses the `synctex` command to find a matching PDF
  in the source directory or its parents, stopping at the Git repository root.
  Included files can also specify `% !TeX root = ../main.tex` in their first 50 lines.
  For another output directory or filename, `:TexView build/main.pdf` remembers
  that PDF for the current buffer. Escape spaces in this command's path with `\ `.
  `Ctrl` + left-click on PDF text in Zathura jumps back to the source line in the
  Vim session that opened the viewer. This requires Vim's `+clientserver` feature;
  `:TexView` starts a server automatically and configures the viewer to use it.
  It also pairs already open windows for that PDF through `busctl` (provided by
  systemd on Ubuntu), so PDFs opened from the shell work after running `:TexView`.
  Older Zathura versions without the D-Bus `ExecuteCommand` method need the PDF
  window closed once and reopened with `:TexView`. The jump opens folds around
  the target line.
- [PDF code references](./vim/CODE_REFERENCES.md) — Ctrl + click on report code
  references to jump to the file and highlighted line range in an existing Vim.
- [Zathura regexp search](./config/zathura/REGEX_SEARCH.md) — `/` and `?` accept
  Vim patterns such as `\<BP\>` or `\<\(BP\|GB\)\>`, with `n` / `N` navigation.
  The native literal search remains available under `g/` and `g?`.
- `vpn on`, `vpn off`, and `vpn toggle` control the on-demand Redshield WireGuard
  profile. `vpn status` reports activation; `vpn check` verifies representative
  IPv4/IPv6 routes, tests HTTPS traffic through the tunnel to Cloudflare, and shows
  the tunnel's DNS settings. IPv4 connectivity must work; unavailable IPv6 is
  reported separately, with its tested route still required to use the tunnel.
  `vpn --status` prints `VPN:on` or `VPN:off` for slstatus; activation alone does
  not verify traffic. The helper installs no kill switch. Changing the public
  source address can interrupt existing SSH connections.
  Keep the original configuration outside Git at
  `~/.config/vpn/redshield/Netherlands.conf` (directory mode 0700, file mode 0600).
  For initial setup, run
  `/usr/bin/python3 scripts/lib/redshield-import.py ~/.config/vpn/redshield/Netherlands.conf`
  from this checkout (`--dry-run` validates without changing anything).
  This requires `python3-gi` and `gir1.2-nm-1.0`, saves a NetworkManager profile
  named `redshield` with autoconnect disabled, restricts the downloaded file to
  mode 0600, and sets the default DNS route (`~.`) and priority 50 for
  systemd-resolved. Local network DNS domains remain available. Both IP
  families must have tunnel addresses and default routes. Existing profiles are
  preserved; wg-quick hooks and custom routing tables are refused. Keep the
  downloaded file and installed profile outside Git. NetworkManager stores the
  installed profile under `/etc/NetworkManager/system-connections/`.
  `makesymlinks.sh desktop` links the helper into `~/.local/bin`; run `vpn toggle`
  from dmenu, or bind it in the maintained dwm source using the suckless workflow.
- [FZF_SEARCH_CHEATSHEET.md](./FZF_SEARCH_CHEATSHEET.md) — quick reference for seeded `RG` search and fuzzy project-word picking
- [SSH_X11_FORWARDING_NOTES.md](./SSH_X11_FORWARDING_NOTES.md) — notes on recovering broken second-hop X forwarding in the SSH/tmux workflow
- [Offline CLI cheatsheets](./cheatsheets/README.md) — using and extending `cht`
- [Suckless maintenance](./SUCKLESS_WORKFLOW.md) — maintained repositories and pinned builds
- [Archived files](./old/README.md) — older scripts, configuration snapshots, patches, and research

If you find something useful here, feel free to borrow it. If something doesn’t fit your setup, delete it.
