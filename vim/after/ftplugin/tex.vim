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

" Return [contents, closing-brace-position] for a balanced {...} group.
function! s:ExtractBraced(text, open) abort
  if a:open < 0 || strpart(a:text, a:open, 1) !=# '{'
    return ['', -1]
  endif

  let depth = 0
  let i = a:open

  while i < strlen(a:text)
    let char = strpart(a:text, i, 1)

    " Ignore escaped braces such as \{ and \}.
    let backslashes = 0
    let j = i - 1
    while j >= 0 && strpart(a:text, j, 1) ==# '\'
      let backslashes += 1
      let j -= 1
    endwhile
    let escaped = backslashes % 2

    if !escaped
      if char ==# '{'
        let depth += 1
      elseif char ==# '}'
        let depth -= 1
        if depth == 0
          return [strpart(a:text, a:open + 1, i - a:open - 1), i]
        endif
      endif
    endif

    let i += 1
  endwhile

  return ['', -1]
endfunction

function! s:SectionTitle(start, end) abort
  let text = ''

  " Read successive lines until the complete section argument is available.
  for lnum in range(a:start, min([a:end, a:start + 30]))
    let text .= ' ' . s:StripComment(getline(lnum))

    let outer_open = match(
          \ text,
          \ '^\s*\\\%(' . s:cmd_alt . '\)\*\?\s*'
          \ . '\%(\[[^]]*\]\s*\)\?\zs{'
          \ )

    let outer = s:ExtractBraced(text, outer_open)
    if outer[1] < 0
      continue
    endif

    let title = outer[0]

    " Prefer the PDF/bookmark argument of \texorpdfstring{TeX}{PDF}.
    let pdfcmd = match(title, '\\texorpdfstring\>')
    if pdfcmd >= 0
      let first_open = match(title, '{', pdfcmd)
      let first = s:ExtractBraced(title, first_open)

      if first[1] >= 0
        let second_open = match(title, '{', first[1] + 1)
        let second = s:ExtractBraced(title, second_open)

        if second[1] >= 0
          let title = second[0]
        endif
      endif
    endif

    return trim(substitute(title, '\s\+', ' ', 'g'))
  endfor

  return ''
endfunction

setlocal foldtext=<SID>TexFoldText()

function! s:TexFoldText() abort
  let line = trim(s:StripComment(getline(v:foldstart)))

  let cmd = matchstr(
        \ line,
        \ '^\s*\\\zs\%(' . s:cmd_alt . '\)\ze\*\?'
        \ )
  if cmd ==# ''
    let cmd = 'fold'
  endif

  let title = s:SectionTitle(v:foldstart, v:foldend)
  if title ==# ''
    let title = line
  endif

  let n = v:foldend - v:foldstart + 1
  return printf('++ %s: %s (%d lines)', cmd, title, n)
endfunction
