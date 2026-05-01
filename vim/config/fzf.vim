if exists('g:dotfiles_fzf_config_loaded')
    finish
endif
let g:dotfiles_fzf_config_loaded = 1

" FZF helpers and mappings for file and buffer picking.
" :BDelete provides a visual multi-select buffer cleanup workflow.

function! s:CompareBufferLastUsed(left, right) abort
    let l:left = getbufinfo(a:left)[0]
    let l:right = getbufinfo(a:right)[0]

    if l:left.lastused == l:right.lastused
        return a:left ==# a:right ? 0 : (a:left < a:right ? -1 : 1)
    endif

    return l:left.lastused > l:right.lastused ? -1 : 1
endfunction

function! s:ListedBuffersByRecency() abort
    let l:buffers = filter(range(1, bufnr('$')), 'buflisted(v:val)')
    call sort(l:buffers, function('s:CompareBufferLastUsed'))
    return l:buffers
endfunction

function! s:BDeleteSelection() abort
    let l:buffers = s:ListedBuffersByRecency()
    if empty(l:buffers)
        echo 'No listed buffers to delete.'
        return
    endif

    let l:source = map(copy(l:buffers), 'fzf#vim#_format_buffer(v:val)')
    let l:spec = {
        \ 'source': l:source,
        \ 'sink*': function('s:BDeleteSink'),
        \ 'options': [
        \   '--multi',
        \   '--ansi',
        \   '-d', '\t',
        \   '--with-nth', '3..',
        \   '-n', '2,1..2',
        \   '--prompt', 'BDelete> ',
        \   '--header', 'TAB mark buffers, ENTER runs :bdelete on the selection'
        \ ],
        \ }
    call fzf#run(fzf#wrap('buffer-delete', l:spec))
endfunction

function! s:BDeleteSink(lines) abort
    if empty(a:lines)
        return
    endif

    let l:deleted = []
    let l:failed = []
    let l:seen = {}

    for l:line in a:lines
        let l:bufnr = str2nr(matchstr(l:line, '\[\zs\d\+\ze\]'))
        if l:bufnr <= 0 || has_key(l:seen, l:bufnr)
            continue
        endif
        let l:seen[l:bufnr] = 1

        try
            execute 'bdelete ' . l:bufnr
            call add(l:deleted, l:bufnr)
        catch /^Vim\%((\a\+)\)\=:E/
            call add(l:failed, printf('%d (%s)', l:bufnr, v:exception))
        endtry
    endfor

    if !empty(l:deleted)
        echo printf('Deleted buffers: %s', join(map(copy(l:deleted), 'string(v:val)'), ', '))
    endif

    if !empty(l:failed)
        echohl WarningMsg
        echo printf('Skipped buffers: %s', join(l:failed, '; '))
        echohl None
    endif
endfunction

function! s:RunRGQuery(query) abort
    let l:query = trim(a:query)
    if empty(l:query)
        return
    endif

    call fzf#vim#grep2(
        \ 'rg --column --line-number --no-heading --color=always --smart-case -- ',
        \ l:query,
        \ fzf#vim#with_preview(),
        \ 0)
endfunction

function! s:VisualSelectionText() abort
    let l:start = getpos("'<")
    let l:end = getpos("'>")
    let l:lines = getline(l:start[1], l:end[1])

    if empty(l:lines)
        return ''
    endif

    let l:lines[0] = l:lines[0][l:start[2] - 1 :]
    let l:lines[-1] = l:lines[-1][: l:end[2] - 1]
    return trim(join(l:lines, ' '))
endfunction

function! s:RunRGFromCursorWord() abort
    call s:RunRGQuery(expand('<cword>'))
endfunction

function! s:RunRGFromVisualSelection() abort
    call s:RunRGQuery(s:VisualSelectionText())
endfunction

function! s:ProjectWordRoot() abort
    let l:git_root = systemlist('git rev-parse --show-toplevel')
    if v:shell_error == 0 && !empty(l:git_root)
        return l:git_root[0]
    endif
    return getcwd()
endfunction

function! s:ProjectWordSourceCommand() abort
    return "rg --no-filename --no-line-number --color=never -o '[[:alpha:]_][[:alnum:]_]*' . | sort -u"
endfunction

function! s:ProjectWordSink(lines) abort
    if empty(a:lines)
        return
    endif
    call s:RunRGQuery(a:lines[0])
endfunction

function! s:ProjectWordPicker() abort
    let l:spec = {
        \ 'source': s:ProjectWordSourceCommand(),
        \ 'dir': s:ProjectWordRoot(),
        \ 'sink*': function('s:ProjectWordSink'),
        \ 'options': ['--prompt', 'RGW> '],
        \ }
    call fzf#run(fzf#wrap('project-word-rg', l:spec))
endfunction

command! -bar BDelete call s:BDeleteSelection()
command! -bar RGW call s:ProjectWordPicker()

nnoremap <silent> <leader>bb :Buffers<CR>
nnoremap <silent> <leader>bd :BDelete<CR>
nnoremap <silent> <leader>rg :<C-u>call <SID>RunRGFromCursorWord()<CR>
xnoremap <silent> <leader>rg :<C-u>call <SID>RunRGFromVisualSelection()<CR>
