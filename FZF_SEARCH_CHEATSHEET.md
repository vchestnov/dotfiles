# FZF Search Cheatsheet

## Search Preview

The right preview in `:Rg`, `:RG`, and `<leader>rg` wraps long lines.
While the picker is open:

- `Ctrl-U` / `Ctrl-D`: scroll the preview up / down by half a page
- `Ctrl-/`: hide / show the preview

## Seeded RG Search

- `<leader>rg` in normal mode:
  launch `:RG` with the word under cursor as the initial query

- `<leader>rg` in visual mode:
  launch `:RG` with the current selection as the initial query

This is the fast replacement for workflows like:

```vim
:Rg <C-w><C-r>
```

## Fuzzy Project Word Picker

- `:RGW`
  open an `fzf` picker over unique words found in the current project, then
  launch `:RG` with the chosen word as the initial query

This is useful when:

- the word is not under cursor
- the word is not in an open buffer
- you remember it only approximately

## Notes

- `RG` is interactive, so after it opens you can keep refining the query
- `RGW` uses git root when available, otherwise the current working directory
- on very large projects `RGW` may be slower, because it first builds a
  project-wide word list
