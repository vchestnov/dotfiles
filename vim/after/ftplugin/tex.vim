" --- Folding setup ---------------------------------------------------------
setlocal foldmethod=expr
setlocal foldexpr=<SID>TexFoldExpr(v:lnum)

setlocal foldenable
" Optional; adjust to taste
setlocal foldnestmax=20
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
let s:fold_env_alt = 'frame\|itemize\|enumerate'

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

function! s:FoldEnvironment(line, command) abort
  return matchstr(
        \ a:line,
        \ '^\s*\\' . a:command . '\s*{\s*\zs\%(' . s:fold_env_alt . '\)\ze\s*}'
        \ )
endfunction

function! s:TexFoldExpr(lnum) abort
  let l = s:StripComment(getline(a:lnum))

  " Fold environments within the current section level.  'a1' starts a
  " nested fold on the \begin line; 's1' closes it after the \end line.
  if s:FoldEnvironment(l, 'begin') !=# ''
    return 'a1'
  endif
  if s:FoldEnvironment(l, 'end') !=# ''
    return 's1'
  endif

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

function! s:FoldTitle(title) abort
  let title = a:title

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

    return s:FoldTitle(outer[0])
  endfor

  return ''
endfunction

function! s:FrameTitle(start, end) abort
  let text = ''
  let inline_title = ''

  " A frame title is normally on the first few lines.  Limit the scan to
  " avoid using a \frametitle from unrelated content later in the frame.
  for lnum in range(a:start, min([a:end, a:start + 30]))
    let text .= ' ' . s:StripComment(getline(lnum))

    " Save the optional \begin{frame}[...]{title} title as a fallback.
    if inline_title ==# ''
      let begin_end = matchend(text, '^\s*\\begin\s*{\s*frame\s*}')
      if begin_end >= 0
        let tail = strpart(text, begin_end)
        let title_open = match(tail, '^\s*\%(\[[^]]*\]\s*\)\?\zs{')
        let outer = s:ExtractBraced(tail, title_open)
        if outer[1] >= 0
          let inline_title = s:FoldTitle(outer[0])
        endif
      endif
    endif

    " Prefer an explicit \frametitle, including its optional short title.
    let title_open = match(
          \ text,
          \ '\\frametitle\>\%(<[^>]*>\s*\)\?\%(\[[^]]*\]\s*\)\?\s*\zs{'
          \ )
    let outer = s:ExtractBraced(text, title_open)
    if outer[1] >= 0
      return s:FoldTitle(outer[0])
    endif
  endfor

  return inline_title
endfunction

function! s:ListTitle(start, end) abort
  let items = 0

  for lnum in range(a:start, a:end)
    let line = s:StripComment(getline(lnum))
    let start = 0
    while 1
      let item = match(line, '\\item\>', start)
      if item < 0
        break
      endif
      let items += 1
      let start = item + 5
    endwhile
  endfor

  return printf('%d %s', items, items == 1 ? 'item' : 'items')
endfunction

setlocal foldtext=<SID>TexFoldText()

function! s:TexFoldText() abort
  let line = trim(s:StripComment(getline(v:foldstart)))
  let env = s:FoldEnvironment(line, 'begin')

  if env ==# 'frame'
    let cmd = env
    let title = s:FrameTitle(v:foldstart, v:foldend)
  elseif env ==# 'itemize' || env ==# 'enumerate'
    let cmd = env
    let title = s:ListTitle(v:foldstart, v:foldend)
  else
    let cmd = matchstr(
          \ line,
          \ '^\s*\\\zs\%(' . s:cmd_alt . '\)\ze\*\?'
          \ )
    if cmd ==# ''
      let cmd = 'fold'
    endif
    let title = s:SectionTitle(v:foldstart, v:foldend)
  endif

  if title ==# '' && env ==# ''
    let title = line
  endif

  let n = v:foldend - v:foldstart + 1
  return printf('++ %s: %s (%d lines)', cmd, title, n)
endfunction
