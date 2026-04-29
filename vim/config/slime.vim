if exists('g:dotfiles_slime_config_loaded')
    finish
endif
let g:dotfiles_slime_config_loaded = 1

" Slime/REPL controls:
" - configures vim-slime to target Vim terminal splits
" - provides vertical/horizontal :Repl commands
" - adds file-backed multiline send helpers for Mathematica and Asir

let g:slime_target = 'vimterminal'
let g:slime_paste_file = '/tmp/.slime_paste'
let g:slime_python_ipython = 1
let g:slime_mma_paste_index = 0
let g:slime_asir_paste_index = 0

function! _EscapeText_mma(text)
    let text = substitute(a:text, "\n*$", "", "")
    if count(text, "\n") >= 2
        let file = printf('/tmp/.seva.slime.%c.m', 97 + g:slime_mma_paste_index)
        let g:slime_mma_paste_index = (g:slime_mma_paste_index + 1) % 26
        call writefile(split(a:text, "\n"), file, 'b')
        return ['Get["' . file . '"]' . "\n"]
    else
        return [text . "\n"]
    endif
endfunction

function! _EscapeText_mmaCodeInspect(text)
    echo 'mmaCodeInspect'
    let text = substitute(a:text, "\n*$", "", "")
    if count(text, "\n") >= 2
        let file = printf('/tmp/.seva.slime.%c.m', 97 + g:slime_mma_paste_index)
        let g:slime_mma_paste_index = (g:slime_mma_paste_index + 1) % 26
        call writefile(split(a:text, "\n"), file, 'b')
        return ['ReadString["' . file . '"] // CodeInspect' . "\n"]
    else
        return ['"' . text . '" // CodeInspect' . "\n"]
    endif
endfunction

function! _EscapeText_asir(text)
    let text = substitute(a:text, "\n*$", "", "")
    if count(text, "\n") >= 2
        let file = printf('/tmp/.seva.slime.%c.rr', 97 + g:slime_asir_paste_index)
        let g:slime_asir_paste_index = (g:slime_asir_paste_index + 1) % 26
        call writefile(add(split(a:text, "\n"), 'end$'), file, 'b')
        return ['load("' . file . '");' . "\n"]
    else
        return [text . "\n"]
    endif
endfunction

function! ReplV(first, ...)
    let l:size = a:first =~# '^\d\+$' ? str2nr(a:first) : 0

    if l:size <= 0
       let l:size = 120
       let l:command = join([a:first] + a:000)
    else
        let l:command = join(a:000)
    endif

    let l:oldbuf = bufnr('%')
    exec 'vert botright term ++cols=' . l:size . ' ++close ' . l:command

    let g:slime_target = 'vimterminal'
    call setbufvar(l:oldbuf, 'slime_config', {'bufnr': bufnr('%')})

    exec 'vert resize ' . l:size
    setlocal winfixwidth
    wincmd p
endfunction

function! ReplH(first, ...) abort
    let l:size = a:first =~# '^\d\+$' ? str2nr(a:first) : 0

    if l:size <= 0
        let l:size = 25
        let l:command = join([a:first] + a:000)
    else
        let l:command = join(a:000)
    endif

    let l:oldbuf = bufnr('%')
    exec 'botright term ++rows=' . l:size . ' ++close ' . l:command

    let g:slime_target = 'vimterminal'
    call setbufvar(l:oldbuf, 'slime_config', {'bufnr': bufnr('%')})

    exec 'resize ' . l:size
    setlocal winfixheight
    wincmd p
endfunction

command! -nargs=* Repl call ReplV(<q-args>)
command! -nargs=* ReplV call ReplV(<f-args>)
command! -nargs=* ReplH call ReplH(<f-args>)

" REPL interaction key bindings:
" - F1 sends the current paragraph or visual selection
" - F2 is intentionally left free for other buffer-local text objects
xmap <F1> <Plug>SlimeRegionSend
nmap <F1> <Plug>SlimeParagraphSend
