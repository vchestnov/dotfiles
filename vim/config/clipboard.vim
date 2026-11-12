if exists('g:dotfiles_clipboard_config_loaded')
    finish
endif
let g:dotfiles_clipboard_config_loaded = 1

" Use the forwarded X clipboard on demand, without Vim opening an X connection
" during startup. Older Vim builds and local desktop sessions keep their defaults.
if has('nvim') || has('gui_running') || !has('clipboard_provider')
            \ || !exists('+clipmethod') || empty($DISPLAY)
            \ || (empty($SSH_CONNECTION) && empty($SSH_TTY))
            \ || !executable('xsel') || !get(g:, 'dotfiles_remote_clipboard', 1)
    finish
endif

let s:xsel = shellescape(exepath('xsel'))
let s:last_copy = {}

function! s:Selection(reg) abort
    return a:reg ==# '+' ? '--clipboard' : '--primary'
endfunction

function! s:Copy(reg, regtype, lines) abort
    let l:text = join(a:lines, "\n") . (a:regtype ==# 'V' ? "\n" : '')
    silent call system(s:xsel . ' --input ' . s:Selection(a:reg), l:text)
    if v:shell_error
        echoerr 'X clipboard copy failed; check DISPLAY and SSH forwarding'
        return
    endif
    let s:last_copy[a:reg] = {'text': l:text, 'type': a:regtype, 'lines': copy(a:lines)}
endfunction

function! s:Paste(reg) abort
    silent let l:text = system(s:xsel . ' --output ' . s:Selection(a:reg))
    if v:shell_error
        echoerr 'X clipboard paste failed; check DISPLAY and SSH forwarding'
        return v:null
    endif

    " X selections carry text; retain Vim's register type for our own yanks.
    if has_key(s:last_copy, a:reg) && s:last_copy[a:reg].text ==# l:text
        return [s:last_copy[a:reg].type, copy(s:last_copy[a:reg].lines)]
    endif
    let l:lines = split(l:text, "\n", 1)
    if l:text =~# "\n$"
        call remove(l:lines, -1)
        return ['V', l:lines]
    endif
    return ['v', l:lines]
endfunction

let v:clipproviders['dotfiles_xsel'] = {
            \ 'copy': {'+': function('s:Copy'), '*': function('s:Copy')},
            \ 'paste': {'+': function('s:Paste'), '*': function('s:Paste')},
            \ }

" The provider still accesses X through xsel; only Vim's eager native X setup
" is excluded. Preserve any unnamed/unnamedplus register preferences.
let &clipboard = substitute(&clipboard, '\(^\|,\)exclude:.*$', '', '')
let &clipboard .= (empty(&clipboard) ? '' : ',') . 'exclude:.*'
let &clipmethod = 'dotfiles_xsel'
