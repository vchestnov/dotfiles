# Vim LSP Cheatsheet

This repo currently uses:

- `vim-lsp`
- `vim-lsp-settings`
- `supertab`

Configured servers in [vimrc](vimrc):

- `clangd` for `c/cpp/objc/objcpp`
- `pylsp` for `python`
- `julia-lsp` for `julia`
- `wolfram-lsp` for `mma`

## Check Mathematica LSP

Shell-side checks:

```bash
command -v wolfram-lsp
command -v WolframKernel
command -v wolfram
command -v wolframscript
command -v math
WolframKernel -noinit -noprompt -nopaclet -nostartuppaclets -noicon -run 'Needs["PacletManager`"]; Print[PacletFind["LSPServer"]]'
```

The launcher used by Vim is [scripts/wolfram-lsp](scripts/wolfram-lsp). It starts:

```bash
WolframKernel -noinit -noprompt -nopaclet -nostartuppaclets -noicon -run 'Needs["LSPServer`"]; LSPServer`StartServer[]'
```

Vim-side checks:

1. Open a Mathematica file: `foo.wl` or `foo.m`
2. Confirm the filetype:

```vim
:set filetype?
```

Expected: `filetype=mma`

3. Check server status:

```vim
:LspStatus
:verbose LspStatus
```

4. If needed, inspect diagnostics:

```vim
:LspDocumentDiagnostics
```

For package-style symbols where official Wolfram LSP does not provide `gd`,
use the repo's grep-based fallback:

```vim
:WolframGotoDefinition
```

or:

```vim
<leader>wd
```

It searches `*.m` and `*.wl` files under the current project root plus
`~/dev`, `~/soft`, and `~/.local/share/Wolfram/ApplicationData/Applications`.
You can override those defaults with `g:wolfram_definition_search_paths` in
[vimrc](vimrc).

If Mathematica LSP does not attach, the usual causes are:

- `wolfram-lsp` is not on `PATH`
- no Wolfram kernel executable is on `PATH`
- the official paclets are not installed: `CodeParser`, `CodeInspector`, `CodeFormatter`, `LSPServer`
- the buffer filetype is not `mma`
- the installed `LSPServer` paclet was built for a different Wolfram version

## Check Julia LSP

Shell-side checks:

```bash
command -v julia
command -v julia-lsp
julia --startup-file=no --history-file=no --project="${XDG_DATA_HOME:-$HOME/.local/share}/julia/environments/lsp" -e 'using LanguageServer'
```

The launcher used by Vim is [scripts/julia-lsp](scripts/julia-lsp). It starts `LanguageServer.jl` from a user-local Julia environment.

Vim-side checks:

1. Open a Julia file: `foo.jl`
2. Confirm the filetype:

```vim
:set filetype?
```

Expected: `filetype=julia`

3. Check server status:

```vim
:LspStatus
:verbose LspStatus
```

If Julia LSP does not attach, the usual causes are:

- `julia` is not on `PATH`
- `julia-lsp` is not on `PATH`
- `LanguageServer.jl` was not installed in the local LSP environment
- the buffer filetype is not `julia`

## Main Keybindings

`<leader>` is space.

- `gd`: definition
- `gD`: declaration
- `gi`: implementation
- `gr`: references
- `K`: hover docs
- `<leader>rn`: rename
- `<leader>ca`: code action
- `[d`: previous diagnostic
- `]d`: next diagnostic
- `<leader>ds`: document symbols
- `<leader>ws`: workspace symbols
- `<leader>wd`: Wolfram package definition fallback

## Completion

LSP completion is wired through `omnifunc`:

```vim
<C-x><C-o>
```

This repo also sets:

```vim
let g:SuperTabDefaultCompletionType = '<c-x><c-o>'
```

so `SuperTab` should use omni-completion in LSP buffers.

## Useful Commands

- `:LspDefinition`
- `:LspDeclaration`
- `:LspImplementation`
- `:LspReferences`
- `:LspHover`
- `:LspRename`
- `:LspCodeAction`
- `:LspDocumentSymbol`
- `:LspWorkspaceSymbol`
- `:LspDocumentDiagnostics`
- `:LspStatus`
- `:LspStopServer`
- `:WolframGotoDefinition`

## Relevant Repo Files

- [vimrc](vimrc)
- [scripts/wolfram-lsp](scripts/wolfram-lsp)
- [LSP installer](bootstrap/installers/lsp.sh)
