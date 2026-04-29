if exists('g:dotfiles_buffers_config_loaded')
    finish
endif
let g:dotfiles_buffers_config_loaded = 1

" Normal-file buffer history and navigation helpers.
" <leader>bp and <leader>bn walk only listed file buffers and ignore
" terminals and all other special buffers.

let s:normal_buffer_history = []
let s:normal_buffer_history_index = -1
let s:normal_buffer_history_navigating = 0

function! s:IsNormalFileBuffer(bufnr) abort
    return bufexists(a:bufnr)
                \ && buflisted(a:bufnr)
                \ && getbufvar(a:bufnr, '&buftype') ==# ''
endfunction

function! s:PruneNormalBufferHistory() abort
    let l:new_history = []
    let l:new_index = -1

    for l:idx in range(len(s:normal_buffer_history))
        let l:bufnr = s:normal_buffer_history[l:idx]
        if s:IsNormalFileBuffer(l:bufnr)
            call add(l:new_history, l:bufnr)
            if l:idx <= s:normal_buffer_history_index
                let l:new_index = len(l:new_history) - 1
            endif
        endif
    endfor

    let s:normal_buffer_history = l:new_history
    let s:normal_buffer_history_index = empty(s:normal_buffer_history)
                \ ? -1
                \ : max([0, l:new_index])
endfunction

function! s:RecordNormalBufferVisit() abort
    if s:normal_buffer_history_navigating
        return
    endif

    let l:bufnr = bufnr('%')
    if !s:IsNormalFileBuffer(l:bufnr)
        return
    endif

    call s:PruneNormalBufferHistory()

    if s:normal_buffer_history_index >= 0 && s:normal_buffer_history_index < len(s:normal_buffer_history) - 1
        let s:normal_buffer_history = s:normal_buffer_history[:s:normal_buffer_history_index]
    endif

    if empty(s:normal_buffer_history) || s:normal_buffer_history[-1] != l:bufnr
        call add(s:normal_buffer_history, l:bufnr)
    endif
    let s:normal_buffer_history_index = len(s:normal_buffer_history) - 1
endfunction

function! s:SwitchNormalBuffer(count, direction) abort
    call s:PruneNormalBufferHistory()

    if empty(s:normal_buffer_history)
        return
    endif

    let l:step = a:direction ==# 'previous' ? -1 : 1
    let l:target_index = s:normal_buffer_history_index
    let l:remaining = a:count
    let l:current = bufnr('%')
    let l:on_history = l:target_index >= 0
                \ && l:target_index < len(s:normal_buffer_history)
                \ && s:normal_buffer_history[l:target_index] == l:current

    if l:target_index < 0 || l:target_index >= len(s:normal_buffer_history)
        let l:target_index = len(s:normal_buffer_history)
    endif

    while l:remaining > 0
        if l:on_history
            let l:target_index += l:step
        elseif a:direction ==# 'next'
            let l:target_index += 1
        endif
        let l:on_history = 1

        while l:target_index >= 0 && l:target_index < len(s:normal_buffer_history)
            let l:bufnr = s:normal_buffer_history[l:target_index]
            if s:IsNormalFileBuffer(l:bufnr) && l:bufnr != l:current
                break
            endif
            let l:target_index += l:step
        endwhile

        if l:target_index < 0 || l:target_index >= len(s:normal_buffer_history)
            return
        endif

        let l:remaining -= 1
    endwhile

    let s:normal_buffer_history_navigating = 1
    try
        let s:normal_buffer_history_index = l:target_index
        execute 'buffer ' . s:normal_buffer_history[l:target_index]
    finally
        let s:normal_buffer_history_navigating = 0
    endtry
endfunction

augroup DotfilesNormalBufferHistory
    autocmd!
    autocmd BufEnter * call <SID>RecordNormalBufferVisit()
augroup END

nnoremap <silent> <leader>bp :<C-u>call <SID>SwitchNormalBuffer(v:count1, 'previous')<CR>
nnoremap <silent> <leader>bn :<C-u>call <SID>SwitchNormalBuffer(v:count1, 'next')<CR>
