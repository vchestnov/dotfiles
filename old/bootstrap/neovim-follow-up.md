# Completed Neovim installation request

Archived on 17 October 2026. Source installation is implemented in
[`bootstrap/installers/neovim.sh`](../../bootstrap/installers/neovim.sh);
maintenance instructions are in [`bootstrap/README.md`](../../bootstrap/README.md).

The original request is preserved below.

## Neovim Follow-Up

This is the same Ubuntu dotfiles repo as before. Main files are `bootstrap.sh`, `makesymlinks.sh`, `vimrc`, and `scripts/`. I use `desktop` and `server` profiles; `server` must work without sudo. I prefer user-local, XDG-compliant installs under `~/.local`, with sources under `~/soft` or `SRC_DIR`. `config/scientific-env.sh` is repo-managed and linked by `makesymlinks.sh`. Bootstrap now symlinks launcher scripts instead of copying them. I want to add Neovim built from source in a way that fits this setup. Please inspect the current repo first and then patch the install flow.
