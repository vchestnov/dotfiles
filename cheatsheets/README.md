# Offline CLI cheatsheets

The [`cht` helper](../scripts/cht) reads the Markdown files in [cli/](cli/).
It is linked into `~/.local/bin` by `makesymlinks.sh` for desktop and server
profiles.

```bash
cht              # Choose a sheet with fzf
cht rg           # Read a sheet by name
cht -l           # List available sheets
cht -e awk       # Edit a sheet using $EDITOR, defaulting to Vim
```

Interactive selection requires `fzf`. For display in a terminal, the helper uses
`$PAGER` when set and otherwise uses Leaf. To choose another pager:

```bash
PAGER='less -R' cht rg
```

Redirected or piped output is plain Markdown. File discovery uses `fd` when
available and otherwise `find`. Reading local sheets does not require a network
connection.

Add sheets under `cli/`, using the command name as the filename, such as `rg.md`.
Set `CHT_DIR` to use another sheet directory.

The earlier tool comparison is retained as
[historical research](../old/research/CLI_CHEATSHEET_ENGINES.md).
