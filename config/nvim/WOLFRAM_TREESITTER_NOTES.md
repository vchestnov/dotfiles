# Wolfram Tree-sitter Notes

## Current state

The Wolfram Language Tree-sitter experiment is partially working in Neovim:

- parser loads successfully
- highlighting works
- folding via Tree-sitter is not reliable on realistic multiline Wolfram code
- Wolfram buffers currently use indent-based folding instead
- Tree-sitter textobjects for Wolfram are experimental

The main reason is that the upstream Wolfram grammar does not yet parse some real-world multiline constructs robustly enough for folds/textobjects to be trustworthy.

## Upstream grammar

Upstream repository:

- <https://github.com/LumaKernel/tree-sitter-wolfram>

Local inspection clone used during debugging:

- `/tmp/tree-sitter-wolfram-inspect`

Important files there:

- `/tmp/tree-sitter-wolfram-inspect/grammar.js`
- `/tmp/tree-sitter-wolfram-inspect/src/node-types.json`
- `/tmp/tree-sitter-wolfram-inspect/src/parser.c`
- `/tmp/tree-sitter-wolfram-inspect/src/scanner.c`
- `/tmp/tree-sitter-wolfram-inspect/queries/highlights.scm`

`grammar.js` is the real source of truth. `src/parser.c` is generated from it.

## Current dotfiles integration

Main Neovim config:

- [config/nvim/init.lua](init.lua)

Local Wolfram queries:

- [config/nvim/queries/wolfram/highlights.scm](queries/wolfram/highlights.scm)
- [config/nvim/queries/wolfram/folds.scm](queries/wolfram/folds.scm)
- [config/nvim/queries/wolfram/textobjects.scm](queries/wolfram/textobjects.scm)

Relevant behavior currently configured:

- `mma` filetype is registered to Tree-sitter language `wolfram`
- Wolfram parser is installed manually through `nvim-treesitter`
- Wolfram highlighting uses Tree-sitter
- Wolfram folding uses `foldmethod=indent`
- non-Wolfram languages still use Tree-sitter folding

## Why Tree-sitter folding was disabled for Wolfram

On real Wolfram code, the grammar misparsed some multiline definitions and bracket-heavy expressions. A representative failing pattern was:

- definitions using `:=`
- nested `RightComposition[...]`
- pattern constructs like `m:(_List | _SparseArray)`
- indexed forms like `#[[1]]`

Because the parse tree ended too early, Tree-sitter folds and Tree-sitter-based definition textobjects also became inaccurate.

So the current setup is:

- Tree-sitter for Wolfram highlighting
- indent-based folding for Wolfram

## Health / feature expectations

For Wolfram, `:checkhealth nvim-treesitter` currently meaningfully supports only:

- `H` for highlights

The upstream grammar does not currently provide:

- `folds.scm`
- `locals.scm`
- `indents.scm`
- `injections.scm`

So lack of `F/L/I/J` from upstream is expected unless we add and maintain those queries ourselves.

## What was needed to make this work

Notable integration/debugging points:

- current machine Neovim is `0.11.5`
- `nvim-treesitter` had to be pinned to `master`, not `main`, because newer `main` requires Neovim `0.12+`
- custom parser install had to include both:
  - `src/parser.c`
  - `src/scanner.c`
- old `nvim-treesitter` installer had to be patched around obsolete `tree-sitter generate --no-bindings`
- Tree-sitter CLI had to be installed separately
- local highlight query had to be vendored into the repo for Wolfram

## Difficulty estimate for improving the grammar

Reasonable estimate:

- query-only improvements: easy
- fixing one concrete grammar bug at a time: moderate
- making the grammar broadly robust for real Wolfram code: hard, ongoing project

The main work would happen in:

- `grammar.js`

not in Neovim config.

## Recommended workflow for a dedicated follow-up chat

The right way to improve this is incrementally:

1. pick one failing Wolfram snippet from real code
2. inspect how the parser currently parses it
3. patch `grammar.js`
4. regenerate the parser
5. retest in Neovim
6. only then refine queries such as folds/textobjects/highlights

This is much better than trying to redesign the whole grammar in one pass.

## Good next targets

If continuing this work, the highest-value next targets are:

1. make top-level `Set` / `SetDelayed` definitions parse correctly across multiline bodies
2. improve handling of pattern-heavy function heads
3. improve handling of nested pure functions and indexed expressions
4. revisit Tree-sitter-based Wolfram folds only after parse-tree quality improves
