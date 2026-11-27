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

function! s:TmuxX11() abort
    if empty($TMUX) || !executable('tmux')
        return []
    endif
    " Read values as data: show-environment -s would require evaluating code.
    let l:tmux = shellescape(exepath('tmux')) . ' show-environment '
    let l:display = systemlist(l:tmux . 'DISPLAY 2>/dev/null')
    if v:shell_error || len(l:display) != 1 || l:display[0] !~# '^DISPLAY=.'
        return []
    endif
    let l:authority = systemlist(l:tmux . 'XAUTHORITY 2>/dev/null')
    if v:shell_error || len(l:authority) != 1
        return []
    endif
    if l:authority[0] ==# '-XAUTHORITY'
        let l:path = v:null
    elseif l:authority[0] =~# '^XAUTHORITY='
        let l:path = strpart(l:authority[0], strlen('XAUTHORITY='))
    else
        return []
    endif
    return [strpart(l:display[0], strlen('DISPLAY=')), l:path]
endfunction

function! s:SetX11(environment) abort
    let $DISPLAY = a:environment[0]
    if a:environment[1] is v:null
        unlet $XAUTHORITY
    else
        let $XAUTHORITY = a:environment[1]
    endif
endfunction

function! s:Xsel(arguments, ...) abort
    let l:command = s:xsel . ' ' . a:arguments
    let l:output = call('system', [l:command] + a:000)
    let l:status = v:shell_error
    if l:status
        " Reattaching updates tmux's environment, but not an existing Vim's.
        " Keep a working display; consult tmux only after an actual failure.
        let l:environment = s:TmuxX11()
        let l:previous = [$DISPLAY, exists('$XAUTHORITY') ? $XAUTHORITY : v:null]
        if !empty(l:environment) && l:environment !=# l:previous
            call s:SetX11(l:environment)
            try
                let l:output = call('system', [l:command] + a:000)
                let l:status = v:shell_error
            finally
                if l:status
                    call s:SetX11(l:previous)
                endif
            endtry
        endif
    endif
    return {'text': l:output, 'status': l:status}
endfunction

function! s:ClipboardError(operation, output) abort
    let l:detail = substitute(trim(a:output), '[\r\n]\+', '; ', 'g')
    echoerr 'X clipboard ' . a:operation . ' failed (DISPLAY=' . $DISPLAY . '): '
                \ . l:detail . '; check the live SSH forwarding connection'
endfunction

function! s:Copy(reg, regtype, lines) abort
    let l:text = join(a:lines, "\n") . (a:regtype ==# 'V' ? "\n" : '')
    let l:result = s:Xsel('--input ' . s:Selection(a:reg), l:text)
    if l:result.status
        call s:ClipboardError('copy', l:result.text)
        return
    endif
    let s:last_copy[a:reg] = {'text': l:text, 'type': a:regtype, 'lines': copy(a:lines)}
endfunction

function! s:Paste(reg) abort
    let l:result = s:Xsel('--output ' . s:Selection(a:reg))
    if l:result.status
        call s:ClipboardError('paste', l:result.text)
        return v:null
    endif
    let l:text = l:result.text

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
