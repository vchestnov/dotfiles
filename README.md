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
  Creates symlinks from this repository into `$HOME`, keeping dotfiles version-controlled while remaining editable in place.

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

Validate profile resolution and safety rules without installing anything:

```sh
bash tests/bootstrap_cli.sh
```

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
- [FZF_SEARCH_CHEATSHEET.md](./FZF_SEARCH_CHEATSHEET.md) — quick reference for seeded `RG` search and fuzzy project-word picking
- [SSH_X11_FORWARDING_NOTES.md](./SSH_X11_FORWARDING_NOTES.md) — notes on recovering broken second-hop X forwarding in the SSH/tmux workflow
- [Offline CLI cheatsheets](./cheatsheets/README.md) — using and extending `cht`
- [Suckless maintenance](./SUCKLESS_WORKFLOW.md) — maintained repositories and pinned builds
- [Archived files](./old/README.md) — older scripts, configuration snapshots, patches, and research

If you find something useful here, feel free to borrow it. If something doesn’t fit your setup, delete it.
