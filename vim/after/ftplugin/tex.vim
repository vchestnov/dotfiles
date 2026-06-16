" --- Folding setup ---------------------------------------------------------
setlocal foldmethod=expr
setlocal foldexpr=<SID>TexFoldExpr(v:lnum)

setlocal foldenable
" Optional; adjust to taste
setlocal foldnestmax=7
setlocal foldlevel=1

setlocal suffixes+=.aux,.log,.dvi,.bak,.bbl,.blg,.out,.toc
setlocal suffixes+=.fdb_latexmk,.fls,.synctex.gz,.pdf

setlocal suffixesadd+=.tex,.bib,.sty,.cls

let s:cmd_level = {
      \ 'part': 1,
      \ 'chapter': 2,
      \ 'section': 3,
      \ 'subsection': 4,
      \ 'subsubsection': 5,
      \ 'paragraph': 6,
      \ 'subparagraph': 7,
      \ }
let s:cmd_alt = 'part\|chapter\|section\|subsection\|subsubsection\|paragraph\|subparagraph'

function! s:StripComment(line) abort
  " Remove TeX comments. A % starts a comment iff preceded by an even number of backslashes.
  let s = a:line
  let i = 0
  while 1
    let p = match(s, '%', i)
    if p < 0
      return s
    endif
    let k = p - 1
    let bs = 0
    while k >= 0 && strpart(s, k, 1) ==# '\'
      let bs += 1
      let k -= 1
    endwhile
    if (bs % 2) == 0
      return strpart(s, 0, p)
    endif
    let i = p + 1
  endwhile
endfunction

function! s:TexFoldExpr(lnum) abort
  let l = s:StripComment(getline(a:lnum))

  " Start fold on sectioning commands (title line included)
  let m = matchlist(l, '^\s*\\\(' . s:cmd_alt . '\)\*\?\s*\(\[[^]]*\]\s*\)\?{')
  if !empty(m)
    let lvl = get(s:cmd_level, m[1], 1)
    return '>' . lvl
  endif

  " Otherwise, keep same fold level as previous line
  return '='
endfunction

setlocal foldtext=<SID>TexFoldText()
function! s:TexFoldText() abort
  let line = trim(s:StripComment(getline(v:foldstart)))

  " Extract sectioning command (part/chapter/section/...)
  let cmd = matchstr(line, '^\s*\\\zs\%(' . s:cmd_alt . '\)\ze\*\?')
  if cmd ==# ''
    let cmd = 'fold'
  endif

  " Extract title from {...} (best-effort)
  let title = matchstr(line, '{\zs.\{-}\ze}')
  if title ==# ''
    let title = line
  endif

  let n = v:foldend - v:foldstart + 1
  return printf('++ %s: %s (%d lines)', cmd, title, n)
endfunction
