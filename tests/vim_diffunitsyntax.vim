" Run: vim -Nu NONE -i NONE -n -es -V1 -S tests/vim_diffunitsyntax.vim
set nocompatible
set nomore
let s:root = fnamemodify(resolve(expand('<sfile>:p')), ':h:h')
let &runtimepath = s:root . '/vim,' . s:root . '/vim/plugged/diffunitsyntax,' . $VIMRUNTIME
let g:DiffUnit = 'Char'
let g:DiffColors = 0
syntax on
runtime plugin/diffunitsyntax.vim
doautocmd VimEnter

function! s:IsHighlighted(lnum, col) abort
    return !empty(filter(
          \ map(synstack(a:lnum, a:col), 'synIDattr(v:val, "name")'),
          \ 'v:val =~? "^diffunitsyntax"'))
endfunction

try
    let s:old = 'dwm b1b49f92a1f8c94a74567cd160bea1cfb37a2805 -'
    let s:new = 'dwm e7c87fabd705fdabdc8b8bb6216d516ac7c3d35a -'
    let s:lines = ['--- a/config/suckless.lock', '+++ b/config/suckless.lock',
          \ '@@ -1 +1 @@', '-' . s:old, '+' . s:new]
    call setline(1, s:lines)
    setlocal syntax=git
    call cursor(4, 1)
    let s:cursor = getpos('.')

    for s:iteration in range(4)
        " Simulate a refresh while the plugin's previous syntax is still present.
        let b:diffunitsyntax = {}
        call diffunitsyntax#DiffUnitSyntax()
        call assert_true(s:IsHighlighted(4, 6), 'old hash has character highlighting')
        call assert_true(s:IsHighlighted(5, 6), 'new hash has character highlighting')
        call assert_false(s:IsHighlighted(4, 2), 'unchanged tool name on removed line')
        call assert_false(s:IsHighlighted(5, 2), 'unchanged tool name on added line')
        call assert_equal(s:lines, getline(1, '$'), 'buffer text preserved')
        call assert_equal(s:cursor, getpos('.'), 'cursor preserved')
    endfor

catch
    call add(v:errors, v:exception . ' at ' . v:throwpoint)
endtry

if !empty(v:errors)
    for s:error in v:errors
        echomsg s:error
    endfor
    cquit
endif
echomsg 'PASS: diffunitsyntax lockfile redraw and character ranges'
qa!
