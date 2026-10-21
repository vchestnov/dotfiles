# CLI cheatsheet engines

> Historical tool survey. Current `cht` usage is documented in
> [cheatsheets/README.md](../../cheatsheets/README.md).

Goal: fast terminal access to examples for `rg`, `fd`, `sed`, `awk`, Bash, `find`, `xargs`, and similar tools, with offline availability.

## Local recommendation

Use the repo-local `cht` helper first:

```bash
cht
cht rg
cht fd
cht -l
cht -e awk
```

It reads Markdown files from `cheatsheets/cli/`, uses `fzf` for picking, and falls back to `less`/`cat` for display. It needs no network and no external cheatsheet database.

## Survey

### navi

Best fit if you want an interactive command launcher, not just documentation. It uses `fzf`/`skim`, supports shell widgets, dynamic argument suggestions, Git-backed cheatsheet repositories, and can import/use sheets from tools such as tldr and cheat.sh. It stores sheets locally, so it is a strong next step for your workflow.

Tradeoff: more moving parts and a custom `.cheat` format. Best when you want to select and run snippets.

### tldr / tealdeer / tlrc

Best fit for quick canonical examples of common commands. The tldr project is a large community-maintained Markdown collection. `tealdeer` and `tlrc` are fast Rust clients; once their cache is populated, lookups are offline.

Tradeoff: pages are intentionally short and generic. Great for `tar`, `find`, `sed`, `awk`; weaker for personal one-liners and project-specific habits.

### cheat

Best fit for editable personal cheatsheets with multiple cheatpaths. It can combine community sheets and your own writable sheet directory, and it supports `fzf`.

Tradeoff: less launcher-oriented than navi and less standardized than tldr. Good if the main object is "my notes by command name".

### cheat.sh / cht.sh

Best fit online. It aggregates many sources and covers programming languages as well as Unix commands. It has a command-line client and can be installed as a standalone service for offline use.

Tradeoff: offline mode is heavier than the others because it means running or maintaining the local service/data. I would not use it as the first offline solution here.

### Plain Markdown plus fzf

Best fit for dotfiles: transparent, versioned, no install step, and easy to adapt from real shell history. This is what `scripts/cht` implements.

Tradeoff: you maintain the content yourself. It pairs well with `navi` later because the useful examples are already curated.

## Suggested path

1. Keep `cht` and `cheatsheets/cli/` as the durable offline base.
2. Install `navi` later if you want Ctrl-G style shell-widget snippet insertion.
3. Install `tealdeer` or `tlrc` later for broad tldr coverage; run `tldr --update` once while online to populate the cache.
4. Skip local cheat.sh unless you specifically want its programming-language Q&A style offline.

## Sources checked

- tldr pages: https://github.com/tldr-pages/tldr
- navi: https://github.com/denisidoro/navi
- cheat: https://github.com/cheat/cheat
- cheat.sh: https://github.com/chubin/cheat.sh
- tealdeer config/cache paths: https://tealdeer-rs.github.io/tealdeer/config_directories.html
