" Prevent reloading twice
if exists("b:did_maple_ftplugin")
  finish
endif
let b:did_maple_ftplugin = 1

setlocal comments=:#
setlocal commentstring=#\ %s

" enable auto comment continuation
setlocal formatoptions+=r
setlocal formatoptions+=o

" if exists("b:did_indent")
"   finish
" endif
" let b:did_indent = 1

setlocal indentexpr=GetMapleIndent()
" setlocal indentkeys=o,O,0=end,0=fi,0=od,0=end\ proc,0=end\ if,0=end\ do
setlocal indentkeys=o,O,0=end,0=fi,0=od,0=else,0=elif,0=end\ proc,0=end\ if,0=end\ do

function! GetMapleIndent() abort
  let lnum = v:lnum
  let prev = prevnonblank(lnum - 1)
  if prev <= 0
    return 0
  endif

  let ind   = indent(prev)
  let line  = getline(lnum)
  let pline = getline(prev)


  " Helpers: detect whether prev line is a header or a mid/close line.
  let prev_is_proc_header = pline =~# '^\s*\w\+\s*:=\s*proc\>' || pline =~# '^\s*proc\>'
  let prev_is_then_do     = pline =~# '\<\%(then\|do\)\>\s*[:;]\=\s*\%(#.*\)\=$'
  let prev_is_mid         = pline =~# '^\s*\%(else\|elif\)\>\s*[:;]\=\s*\%(#.*\)\=$'

  " Dedent on closers and mid-block keywords
  if line =~# '^\s*\%(end\s\+proc\|end\s\+if\|end\s\+do\|fi\|od\|else\|elif\)\>\s*[:;]\=\s*\%(#.*\)\=$'
    " If the previous line is a header (then/do/proc) or an else/elif line,
    " don't subtract shiftwidth (handles empty arms cleanly).
    if prev_is_proc_header || prev_is_then_do || prev_is_mid
      return ind
    endif
    return max([ind - &shiftwidth, 0])
  endif

  " Indent after openers
  if prev_is_proc_header
    return ind + &shiftwidth
  endif

  if prev_is_then_do
    return ind + &shiftwidth
  endif

  " Indent the else-body
  if pline =~# '^\s*else\>\s*[:;]\=\s*\%(#.*\)\=$'
    return ind + &shiftwidth
  endif

  return ind
endfunction

let s:maple_kw_list = ['for','if','elif','else','while','return','proc','end','do','od','fi','local']
let s:maple_kw = '\%(' . join(s:maple_kw_list, '\|') . '\)\>'
let s:sep = '\%(:\%([=:-]\)\@!\|;\)'
" let s:closer = '\%(\<fi\>\|\<od\>\|\<end\>\s\+\%(if\|do\|proc\|module\|try\)\)\>\s*[:;]\='
let s:closer_kw = '\%(\<fi\>\|\<od\>\|\<else\>\|\<end\>\s\+\%(if\|do\|proc\|module\|try\)\)\>'

function! s:MapleSplitCtl(first, last) abort
    let view = winsaveview()
    try
        let l1 = a:first
        let l2 = a:last

        " 0) Split after 'then' or 'else' when it's written as:  then <code>
        " (avoid silly 'then :' or 'then ;' or 'then #comment')
        let before = line('$')
        silent! keeppatterns execute l1 . ',' . l2
            \ . 's/\%(\<then\>\|\<else\>\)\zs\s\+\ze\%([^:;#\s]\)/\r/g'
        let l2 += line('$') - before

        " 1) Split after openers do/then with immediate ;/:  and after proc(...) headers
        let before = line('$')
        silent! keeppatterns execute l1 . ',' . l2
            \ . 's/\%(\<\%(do\|then\)\>\|\<proc\>\s*(.\{-})\)\s*' . s:sep . '\zs\s*\ze\S/\r/g'
        let l2 += line('$') - before

        " 2) Split before control keywords when preceded by ;/:
        let before = line('$')
        silent! keeppatterns execute l1 . ',' . l2
            \ . 's/' . s:sep . '\zs\s*\ze' . s:maple_kw . '/\r/g'
        let l2 += line('$') - before

        " 3) Force closers onto their own line (even if not preceded by ;/:)
        let before = line('$')
        silent! keeppatterns execute l1 . ',' . l2
              \ . 's/\S\zs\s*\ze' . s:closer_kw . '/\r/g'
        let l2 += line('$') - before

        " 4) Also split AFTER a closer’s terminator if more code follows (e.g. 'end if; r:=...')
        let before = line('$')
        silent! keeppatterns execute l1 . ',' . l2
            \ . 's/' . s:closer_kw . '\s*' . s:sep . '\zs\s*\ze\S/\r/g'
        let l2 += line('$') - before
    finally
        call winrestview(view)
    endtry
endfunction

command! -range=% MapleSplitCtl call <SID>MapleSplitCtl(<line1>, <line2>)

function! s:MapleSplitOp(type) abort
    " operatorfunc sets '[ and '] to the affected region
    let l1 = line("'[")
    let l2 = line("']")
    execute l1 . ',' . l2 . 'MapleSplitCtl'
endfunction

" Normal mode: start an operator, then give a motion/textobject
nnoremap <buffer> <leader>s :set opfunc=<SID>MapleSplitOp<CR>g@

" Visual mode: run directly on the selection
xnoremap <buffer> <leader>s :<C-U>'<,'>MapleSplitCtl<CR>

" ----------------------------- User-tweakables -----------------------------

" Canonical marker strings used when inserting headings
let b:maple_h1_marks = get(b:, 'maple_h1_marks', '###')
let b:maple_h2_marks = get(b:, 'maple_h2_marks', '===')
let b:maple_h3_marks = get(b:, 'maple_h3_marks', '---')

" Add trailing marks too? 0 => "# ### Title", 1 => "# ### Title ###"
let b:maple_heading_trailing_marks = get(b:, 'maple_heading_trailing_marks', 0)

" Start with top-level folds open
setlocal foldmethod=expr
setlocal foldexpr=<SID>MapleFoldExpr(v:lnum)
setlocal foldenable
setlocal foldnestmax=3
setlocal foldlevel=1

" ------------------------------ Regex helpers ------------------------------

" Heading detection (no minimum length; any positive run)
let s:re_h1 = '^\s*#\s*#\{3,}\s*.\+'
let s:re_h2 = '^\s*#\s*=\{3,}\s*.\+'
let s:re_h3 = '^\s*#\s*-\{3,}\s*.\+'

function! s:MapleFoldExpr(lnum) abort
  let l = getline(a:lnum)
  if l =~# s:re_h1
    return '>1'
  elseif l =~# s:re_h2
    return '>2'
  elseif l =~# s:re_h3
    return '>3'
  endif
  return '='
endfunction

" ------------------------------- Title logic -------------------------------

function! s:TrimBannerTitle(title) abort
  let t = a:title
  let t = trim(t)

  " Drop ALL leading marker runs (#,=,-) and whitespace
  let t = substitute(t, '^\s*[#=-]\+\s*', '', '')

  " Drop ALL trailing marker runs (#,=,-) and whitespace
  let t = substitute(t, '\s*[#=-]\+\s*$', '', '')

  return trim(t)
endfunction

function! s:ExtractBannerTitleFromLine(line) abort
  " Remove leading Maple comment and marker run, then trim banner markers on both sides.
  " Examples:
  "   "# =====Foo====" -> "Foo"
  "   "   # --- Foo ---" -> "Foo"
  "
  " Step 1: drop leading spaces + comment hash
  let t = substitute(a:line, '^\s*#\s*', '', '')

  " Step 2: drop the first marker run (### / === / --- / etc.)
  let t = substitute(t, '^[#=-]\+\s*', '', '')

  " Step 3: now strip any banner junk on both ends
  return s:TrimBannerTitle(t)
endfunction

function! s:MakeBannerLine(level, title) abort
  let title = s:TrimBannerTitle(a:title)
  if title ==# ''
    return ''
  endif

  if a:level ==# 1
    let marks = b:maple_h1_marks
  elseif a:level ==# 2
    let marks = b:maple_h2_marks
  else
    let marks = b:maple_h3_marks
  endif

  let line = '# ' . marks . ' ' . title
  if b:maple_heading_trailing_marks
    let line .= ' ' . marks
  endif
  return line
endfunction

function! s:IsHeadingLineForLevel(line, level) abort
  if a:level ==# 1
    return a:line =~# s:re_h1
  elseif a:level ==# 2
    return a:line =~# s:re_h2
  else
    return a:line =~# s:re_h3
  endif
endfunction

function! s:InsertOrUpdateBanner(level) abort
  let cur = getline('.')
  let prefill = ''
  if s:IsHeadingLineForLevel(cur, a:level)
    let prefill = s:ExtractBannerTitleFromLine(cur)
  endif

  let prompt = (a:level ==# 1 ? 'Heading (H1) title: '
        \ : a:level ==# 2 ? 'Heading (H2) title: '
        \ : 'Heading (H3) title: ')

  let title = input(prompt, prefill)
  let newline = s:MakeBannerLine(a:level, title)
  if newline ==# ''
    return
  endif

  " If cursor is already on a heading of this level, replace it; else insert above.
  if s:IsHeadingLineForLevel(cur, a:level)
    call setline('.', newline)
  else
    call append(line('.') - 1, newline)
  endif
endfunction

function! s:DetectHeadingLevel(line) abort
  " Returns 1/2/3 for H1/H2/H3 heading lines, or 0 if not a heading.
  if a:line =~# '^\s*#\s*#\+\s*.\+'
    return 1
  elseif a:line =~# '^\s*#\s*=\+\s*.\+'
    return 2
  elseif a:line =~# '^\s*#\s*-\+\s*.\+'
    return 3
  endif
  return 0
endfunction

function! s:ReformatHeadingAtCursor() abort
  let l = getline('.')
  let lvl = s:DetectHeadingLevel(l)
  if lvl == 0
    echo "MapleReformatHeading: not on a banner heading line"
    return
  endif

  let title = s:ExtractBannerTitleFromLine(l)
  let newline = s:MakeBannerLine(lvl, title)
  if newline ==# ''
    echo "MapleReformatHeading: empty title (after trimming)"
    return
  endif

  call setline('.', newline)
endfunction

" ------------------------------ Commands -----------------------------------

command! -buffer MapleH1 call <SID>InsertOrUpdateBanner(1)
command! -buffer MapleH2 call <SID>InsertOrUpdateBanner(2)
command! -buffer MapleH3 call <SID>InsertOrUpdateBanner(3)

" Optional mappings (buffer-local)
nnoremap <buffer> <silent> <leader>mh1 :MapleH1<CR>
nnoremap <buffer> <silent> <leader>mh2 :MapleH2<CR>
nnoremap <buffer> <silent> <leader>mh3 :MapleH3<CR>

command! -buffer MapleReformatHeading call <SID>ReformatHeadingAtCursor()

" Optional mapping
nnoremap <buffer> <silent> <leader>mhr :MapleReformatHeading<CR>


" -------------------------- Optional highlighting --------------------------

if has('syntax')
  syntax match mapleHeadingH1 /^\s*#\s*#\+\s*.\+$/
  syntax match mapleHeadingH2 /^\s*#\s*=\+\s*.\+$/
  syntax match mapleHeadingH3 /^\s*#\s*-\+\s*.\+$/

  highlight default link mapleHeadingH1 Title
  highlight default link mapleHeadingH2 Identifier
  highlight default link mapleHeadingH3 Statement
endif
