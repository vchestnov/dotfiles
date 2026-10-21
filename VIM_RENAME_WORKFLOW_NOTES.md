# Vim Rename Workflow Notes

## Goal

Improve the common rename workflow beyond manually typing:

```vim
:%s/\<old\>/new/g
```

## Current Useful Building Blocks

- LSP semantic rename in LSP-enabled buffers:

```vim
<leader>rn
```

- Exact textual rename in current buffer:

```vim
:%s/\<old\>/new/gc
```

- Seed current word into substitution:

```vim
:%s/\<<C-r><C-w>\>//gc
```

## Promising Workflows

### 1. Semantic rename

Best when the language server understands the symbol and should update all
references semantically.

- use `<leader>rn`

### 2. Textual rename with confirmation

Best when renaming plain text in the current buffer and wanting explicit
confirmation.

- use `:%s/\<old\>/new/gc`
- or a seeded version based on the word under cursor

### 3. Selective match-by-match rename

Best when a global substitution is too broad.

Suggested built-in workflow:

```vim
*
cgn
```

Then:

- type replacement
- press `<Esc>`
- use `.` to repeat replacement on the next match
- use `n` to skip forward

### 4. Project-wide textual rename

Best when renaming across multiple files without LSP support.

Suggested workflow:

- search first with `:RG` / `<leader>rg`
- inspect matches
- then use quickfix-based editing such as `:cdo` / `:cfdo`

## Likely Ergonomic Improvements To Implement Later

### `inccommand`

Add:

```vim
set inccommand=split
```

This gives live preview for `:s` commands and is likely the highest-value
general improvement.

### Seeded rename mapping

Add a mapping that preloads:

```vim
:%s/\<<C-r><C-w>\>//gc
```

so the replacement can be typed immediately.

### Visual-mode rename helper

Possible addition:

- a mapping that uses the current visual selection as the search text
- still asks for the replacement interactively

## Suggested Next Step

When returning to this topic, likely implement:

1. `set inccommand=split`
2. a seeded current-word rename mapping
3. optionally a visual-mode variant
