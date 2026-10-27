# Archived files

Historical source files, configuration snapshots, and completed notes are kept
here so they can be included in Git. `garage/` remains ignored local scratch.
The archive was organized on 17 October 2026.

These are reference snapshots. Archived scripts describe earlier layouts and can
replace configuration if run; use the current entry points linked below.

| Archive | Contents | Current replacement |
| --- | --- | --- |
| [bootstrap/](bootstrap/) | Three older `makesymlinks` implementations | [makesymlinks.sh](../makesymlinks.sh) |
| [grayscale-picom/](grayscale-picom/) | Original picom-based grayscale toggle, shader, and configuration, including uncommitted fixes at the time of archival | [CTM grayscale toggle](../scripts/toggle-monitor-grayscale) |
| [bootstrap/neovim-follow-up.md](bootstrap/neovim-follow-up.md) | Completed Neovim source installation request, formerly in `TODO.md` | [Neovim installer](../bootstrap/installers/neovim.sh) and [bootstrap maintenance guide](../bootstrap/README.md) |
| [suckless/SUCKLESS_PATCH_NOTES.md](suckless/SUCKLESS_PATCH_NOTES.md) | Troubleshooting instructions for the retired bootstrap patch workflow | [SUCKLESS_WORKFLOW.md](../SUCKLESS_WORKFLOW.md) |
| [suckless/patches/](suckless/patches/) | Historical dwm, dmenu, and slock patches, including earlier dwm variants | Maintained source repositories and [config/suckless.lock](../config/suckless.lock) |
| [research/CLI_CHEATSHEET_ENGINES.md](research/CLI_CHEATSHEET_ENGINES.md) | Earlier comparison of terminal cheatsheet tools | [Current cheatsheet usage](../cheatsheets/README.md) |
| [vim/vim-lsp-cleaned/](vim/vim-lsp-cleaned/) | Earlier Vim configuration snapshot, formerly in `garage/` | [vimrc](../vimrc) and [vim/config/](../vim/config/) |

The historical patches and source snapshots retain their original contents,
including edits that had not yet been committed when they were archived. The
previous `patches/dwm/garage/` directory is named `variants/` here so Git does not
ignore it. The active Blade patch remains under `patches/blade/`.

The old Vim ZIP remains in ignored `garage/` as a local backup; its four files are
identical to the extracted snapshot archived here. The local desktop launcher in
`garage/.gnome/` also remains local.

Keep archived files out of installer, configuration-linking, and startup paths.
Put current instructions beside the maintained code or in the active documentation,
and link them from the repository README.
