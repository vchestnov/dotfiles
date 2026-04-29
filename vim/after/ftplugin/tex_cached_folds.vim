" Fast LaTeX section folding (cached, single-pass)
" ~/.vim/after/ftplugin/tex.vim   or   ~/.config/vim/after/ftplugin/tex.vim

if exists('b:did_latex_section_folds_fast')
  finish
endif
let b:did_latex_section_folds_fast = 1

setlocal foldmethod=expr
setlocal foldexpr=<SID>TexFoldExpr(v:lnum)
setlocal foldtext=<SID>TexFoldText()
setlocal foldlevelstart=99
setlocal foldminlines=1

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
  " Return line with TeX comment removed.
  " A % starts a comment iff it is preceded by an even number of backslashes.
  let s = a:line
  let i = 0
  while 1
    let p = match(s, '%', i)
    if p < 0
      return s
    endif

    " Count consecutive backslashes immediately before %
    let k = p - 1
    let bs = 0
    while k >= 0 && strpart(s, k, 1) ==# '\'
      let bs += 1
      let k -= 1
    endwhile

    " Even # of '\' => % is a real comment start
    if (bs % 2) == 0
      return strpart(s, 0, p)
    endif

    " Odd # of '\' => escaped %, keep searching
    let i = p + 1
  endwhile
endfunction

function! s:RebuildTexFoldCache() abort
  let n = line('$')
  let b:tex_fold_cache = repeat([0], n + 1)  " 1-based indexing
  let b:tex_head_cache = repeat([0], n + 1)

  let lvl  = 0     " current sectioning level (0 = none yet)
  let head = 0     " line number of last heading

  for lnum in range(1, n)
    let l = s:StripComment(getline(lnum))

    " Match sectioning command only at start of line
    let m = matchlist(l, '^\s*\\\(' . s:cmd_alt . '\)\*\?\s*\(\[[^]]*\]\s*\)\?{')
    if !empty(m)
      let lvl = get(s:cmd_level, m[1], 0)
      let head = lnum
      let b:tex_fold_cache[lnum] = lvl
      let b:tex_head_cache[lnum] = head
    else
      " Body lines are one deeper than the last heading -> fold under heading
      let b:tex_fold_cache[lnum] = (lvl > 0 ? (lvl + 1) : 0)
      let b:tex_head_cache[lnum] = head
    endif
  endfor

  let b:tex_fold_dirty = 0
endfunction

function! s:TexFoldExpr(lnum) abort
  " Rebuild cache lazily. Avoid doing it on *every keystroke* while typing.
  if !exists('b:tex_fold_dirty') | let b:tex_fold_dirty = 1 | endif
  if b:tex_fold_dirty
    if mode() =~# 'i'
      " While in insert mode, keep folds slightly stale for speed
      return get(get(b:, 'tex_fold_cache', []), a:lnum, 0)
    endif
    call s:RebuildTexFoldCache()
  endif
  return b:tex_fold_cache[a:lnum]
endfunction

function! s:TexFoldText() abort
  let h = get(get(b:, 'tex_head_cache', []), v:foldstart, 0)
  if h <= 0
    let h = v:foldstart
  endif
  let line = trim(s:StripComment(getline(h)))

  " Best-effort title extraction from {...}
  let title = matchstr(line, '{\zs.\{-}\ze}')
  if title ==# ''
    let title = line
  endif

  let n = v:foldend - v:foldstart + 1
  return printf('%s  …  (%d lines)', title, n)
endfunction

augroup TexFoldCache
  autocmd! * <buffer>
  " Mark cache dirty on edits; rebuild when you leave insert / write / enter buffer
  autocmd TextChanged,TextChangedI <buffer> let b:tex_fold_dirty = 1
  autocmd BufEnter,InsertLeave,BufWritePost <buffer> call <SID>RebuildTexFoldCache() | silent! normal! zx
augroup END

nnoremap <buffer> <leader>zf :call <SID>RebuildTexFoldCache()<CR>zx
