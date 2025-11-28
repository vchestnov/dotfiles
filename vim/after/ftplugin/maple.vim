" ~/.vim/after/ftplugin/maple.vim
setlocal comments=:#  " tell Vim that '#' starts a comment
setlocal commentstring=#\ %s

" enable auto comment continuation
setlocal formatoptions+=r
setlocal formatoptions+=o

" ftplugin/maple.vim
" Maple: pseudo-Mathematica-style Section/Subsection/Subsubsection folding
" and heading highlighting using comment markers.

" Prevent reloading twice
if exists("b:did_maple_ftplugin")
  finish
endif
let b:did_maple_ftplugin = 1

" --- Folding setup ---------------------------------------------------------

" Use an expression-based fold method so we can define our own heading levels.
setlocal foldmethod=expr
setlocal foldexpr=<SID>MapleFoldExpr(v:lnum)

" Some sensible fold defaults; tweak to taste.
setlocal foldenable
setlocal foldnestmax=3
" Start with top-level sections open, deeper levels folded.
setlocal foldlevel=1

" Convention (you can change these patterns below if you like):
"   # ===== Section: Title =====
"   # ---- Subsection: Title ----
"   # -- Subsubsection: Title --
"
" Only the leading comment pattern matters; the rest of the line is free-form.

function! s:MapleFoldExpr(lnum) abort
  let l = getline(a:lnum)

  " Top-level Section
  if l =~# '^\s*# ====='
    " Start a new level-1 fold here
    return '>1'
  " Second-level Subsection
  elseif l =~# '^\s*# ----'
    " Start a new level-2 fold here
    return '>2'
  " Third-level Subsubsection
  elseif l =~# '^\s*# --'
    " Start a new level-3 fold here
    return '>3'
  endif

  " '=' means "keep the same fold level as the previous line"
  return '='
endfunction

" --- Syntax highlighting for headings -------------------------------------

if has('syntax') && exists('b:current_syntax')
  " Highlight patterns for headings inside Maple comments.
  " Adjust the regexes if your comment style differs.

  " Top-level section headings
  syntax match mapleSectionHeading    /^\s*# =====.*$/ containedin=mapleComment,@Spell

  " Subsection headings
  syntax match mapleSubsectionHeading /^\s*# ----.*$/  containedin=mapleComment,@Spell

  " Subsubsection headings
  syntax match mapleSubsubHeading     /^\s*# --[^-].*$/ containedin=mapleComment,@Spell

  " Fallback if the syntax file doesn't define mapleComment:
  " They’ll still match, just not be constrained to comments.
  " (The `containedin` above is harmless if mapleComment doesn’t exist.)

  " Link to reasonable defaults without overriding user customizations.
  if !hlexists('mapleSectionHeading')
    " no-op, just in case; hlexists checks highlight groups, not syntax names
  endif

  highlight default link mapleSectionHeading    Title
  highlight default link mapleSubsectionHeading Identifier
  highlight default link mapleSubsubHeading     Statement
endif

" --- Optional: Helpers to insert headings ---------------------------------
" Comment these out if you don't want them.

" Insert a Section heading
command! -buffer MapleSection call s:MapleInsertHeading('section')
" Insert a Subsection heading
command! -buffer MapleSubsection call s:MapleInsertHeading('subsection')
" Insert a Subsubsection heading
command! -buffer MapleSubsubsection call s:MapleInsertHeading('subsubsection')

function! s:MapleInsertHeading(kind) abort
  if a:kind ==# 'section'
    let text = input('Section title: ')
    if text ==# '' | return | endif
    call append(line('.') - 1, '# ===== ' . text . ' =====')
  elseif a:kind ==# 'subsection'
    let text = input('Subsection title: ')
    if text ==# '' | return | endif
    call append(line('.') - 1, '# ---- ' . text . ' ----')
  elseif a:kind ==# 'subsubsection'
    let text = input('Subsubsection title: ')
    if text ==# '' | return | endif
    call append(line('.') - 1, '# -- ' . text . ' --')
  endif
endfunction

" Optional mappings (buffer-local):
"   <leader>ms  -> insert Section heading above current line
"   <leader>mn  -> insert Subsection heading above current line
"   <leader>mm  -> insert Subsubsection heading above current line
nnoremap <buffer> <silent> <leader>ms :MapleSection<CR>
nnoremap <buffer> <silent> <leader>mn :MapleSubsection<CR>
nnoremap <buffer> <silent> <leader>mm :MapleSubsubsection<CR>
