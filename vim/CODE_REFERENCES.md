# Code references in PDF reports

Ctrl + left-click on a blue code reference jumps to the referenced file and
temporarily highlights its line range in Vim. The helper prefers a Vim session
where that file is already open, including windows in another tab. If it is not
open, it opens in the Vim session paired with the report. Unsaved buffers are
preserved. Ordinary Ctrl + clicks still jump to the report's LaTeX source.

## Authoring a report

Copy [coderef.sty](../templates/latex/coderef.sty) next to the report, then load
it in the preamble:

```latex
\usepackage{coderef}
```

Use a literal path relative to the `.tex` file, a first line, a last line, and
a label:

```latex
\coderef{../InterXPairing.m}{1114}{1148}{Tabpart1Fast}
```

This prints `Tabpart1Fast: lines 1114–1148`. For other visible text, use
`\codelink` with the same first three arguments:

```latex
\codelink{../InterXPairing.m}{1114}{1148}{\texttt{Tabpart1Fast} (1114--1148)}
```

Paths may contain spaces and underscores. Write literal paths, not LaTeX macros
or escaped underscores. Calls may span multiple source lines, appear together
on one line, or occur inside wrapper macros and tables.

The package typesets each reference from a generated input file named
`REPORT.coderef-N.tex`. This gives SyncTeX a distinct target even in tables.
References use unbreakable coloured boxes; keep labels short enough to fit the
text or table column. These are SyncTeX navigation targets; ordinary PDF
hyperlinks and Zathura's `f` navigation keep their usual behaviour.

Compile with SyncTeX enabled, twice for cross-references:

```sh
TEXINPUTS=docs: pdflatex -synctex=1 -recorder -halt-on-error \
  -output-directory=docs docs/subleading-tab-report.tex
```

For a report compiled from its own directory, the `TEXINPUTS` setting is not
needed. Keep the `.synctex.gz`, `.fls`, and generated `.coderef-N.tex` files in
the output directory; recompile after changing the report. If moving the PDF,
keep the original build directory available for SyncTeX. The `-recorder` flag
lets the package resolve source paths without shell escape. Code line ranges
describe the inspected snapshot: update them when the code changes. The helper
rejects ranges beyond the end of the current file.

## Using it

Open the code in Vim and the report's `.tex` in Vim; these may be the same or
different sessions. Run `:TexView` in the report once per session to pair Zathura.
Ctrl + left-click on a reference to jump. Folds around the first line open, and
the range is highlighted for four seconds. The target Vim window or tab is
selected; raising a terminal above other desktop windows depends on the window
manager. Neither saving nor leaving insert mode repeats the jump.

New Vim sessions register automatically. To enable existing sessions without
restarting them, run this in each Vim that has the code or report open:

```vim
:runtime plugin/coderef.vim
```

Then reload the report integration and re-pair its viewer:

```vim
:unlet! b:did_dotfiles_tex_synctex
:runtime ftplugin/tex_synctex.vim
:TexView
```

Requirements: Vim with `+clientserver`, Python 3, SyncTeX, and Zathura. Sessions
must use the same clientserver backend (normally X11). Socket sessions started
with `vim --clientserver socket` are also supported. Existing Zathura windows
are paired with `busctl` as in the ordinary forward/inverse search setup.
