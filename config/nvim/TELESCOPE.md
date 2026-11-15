# Telescope Cheatsheet

Leader key: `<Space>`

Core search:

- `<leader>sf` : find files
- `<leader>sg` : live grep in project (`rg`)
- `<leader>sw` : grep current word
- visual `<leader>sw` : grep current selection
- `<leader>s/` : grep only open files
- `<leader>/` : fuzzy search in current buffer
- `<leader>s.` : recent files
- `<leader>sr` : resume last picker

Navigation / lookup:

- `<leader><leader>` : buffers
- `<leader>sh` : help tags
- `<leader>sk` : keymaps
- `<leader>sc` : commands
- `<leader>ss` : Telescope pickers
- `<leader>sn` : search Neovim config files
- `<leader>sd` : diagnostics

LSP-related pickers:

- `grr` : references
- `gri` : implementations
- `grd` : definitions
- `grt` : type definitions
- `gO` : document symbols
- `gW` : workspace symbols

Inside a Telescope picker:

- `<C-j>` : move selection down
- `<C-k>` : move selection up
- `<C-/>` : show picker help in insert mode
- `?` : show picker help in normal mode
- `<CR>` : open selection
- `<Esc>` : close picker

Minimal replacement for old `fzf.vim` habits:

- `:Files` -> `<leader>sf`
- `:Rg pattern` -> `<leader>sg`, then type pattern
- `:Rg <C-r><C-w>` -> `<leader>sw`
- `:Buffers` -> `<leader><leader>`
