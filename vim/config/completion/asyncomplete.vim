if exists('g:dotfiles_completion_asyncomplete_loaded')
    finish
endif
let g:dotfiles_completion_asyncomplete_loaded = 1

let g:asyncomplete_enable_for_all = 1
let g:asyncomplete_auto_popup = 0
let g:asyncomplete_auto_completeopt = 0
set completeopt=menuone

function! s:CheckBackSpace() abort
    let l:col = col('.') - 1
    return !l:col || getline('.')[l:col - 1] =~# '\s'
endfunction

inoremap <expr> <Tab> pumvisible() ? "\<C-n>" :
    \ <SID>CheckBackSpace() ? "\<Tab>" :
    \ asyncomplete#force_refresh()
inoremap <expr> <S-Tab> pumvisible() ? "\<C-p>" : "\<S-Tab>"
imap <C-Space> <Plug>(asyncomplete_force_refresh)
if !has('nvim')
    imap <C-@> <Plug>(asyncomplete_force_refresh)
endif

augroup dotfiles_asyncomplete
    autocmd!
    autocmd User asyncomplete_setup call s:RegisterAsyncompleteBufferSource()
    if get(g:, 'dotfiles_wolfram_completion_enabled', 0)
        autocmd User asyncomplete_setup call DotfilesWolframRegisterAsyncompleteSource()
    endif
augroup END

function! s:RegisterAsyncompleteBufferSource() abort
    let l:source = {
        \ 'name': 'buffer',
        \ 'allowlist': ['*'],
        \ 'events': ['BufEnter', 'BufWinEnter', 'BufWritePost', 'BufDelete', 'BufUnload', 'BufWipeout', 'TerminalOpen'],
        \ 'on_event': function('s:OnAsyncompleteBufferEvent'),
        \ 'completor': function('s:AsyncompleteAllBuffersCompletor'),
        \ }
    call asyncomplete#register_source(l:source)

    call s:WarmAsyncompleteBufferWords()
endfunction

function! s:AsyncompleteBufferMaxSize() abort
    return get(g:, 'asyncomplete_buffer_max_buffer_size', 5000000)
endfunction

function! s:AsyncompleteBufferBuftype(bufnr) abort
    return getbufvar(a:bufnr, '&buftype')
endfunction

function! s:AsyncompleteBufferIsTerminal(bufnr) abort
    return s:AsyncompleteBufferBuftype(a:bufnr) ==# 'terminal'
endfunction

function! s:AsyncompleteBufferShouldInclude(bufnr) abort
    if !bufloaded(a:bufnr)
        return 0
    endif

    if s:AsyncompleteBufferIsTerminal(a:bufnr)
        return 1
    endif

    return buflisted(a:bufnr) && s:AsyncompleteBufferBuftype(a:bufnr) ==# ''
endfunction

function! s:AsyncompleteBufferShouldSkip(bufnr) abort
    if !s:AsyncompleteBufferShouldInclude(a:bufnr)
        return 1
    endif

    let l:max_buffer_size = s:AsyncompleteBufferMaxSize()
    if l:max_buffer_size == -1
        return 0
    endif

    let l:byte_size = len(join(getbufline(a:bufnr, 1, '$'), "\n"))
    return l:byte_size > l:max_buffer_size
endfunction

function! s:RefreshAsyncompleteBufferWords(bufnr) abort
    if s:AsyncompleteBufferShouldSkip(a:bufnr)
        if has_key(s:asyncomplete_buffer_words, a:bufnr)
            call remove(s:asyncomplete_buffer_words, a:bufnr)
        endif
        return
    endif

    let l:words = {}
    let l:text = join(getbufline(a:bufnr, 1, '$'), "\n")

    for l:word in split(l:text, '\W\+')
        if len(l:word) > 1
            let l:words[l:word] = 1
        endif
    endfor

    let s:asyncomplete_buffer_words[a:bufnr] = l:words
endfunction

function! s:WarmAsyncompleteBufferWords() abort
    let s:asyncomplete_buffer_words = {}

    for l:info in getbufinfo()
        if s:AsyncompleteBufferShouldInclude(l:info.bufnr)
            call s:RefreshAsyncompleteBufferWords(l:info.bufnr)
        endif
    endfor
endfunction

function! s:RefreshAsyncompleteTerminalBufferWords() abort
    if !exists('s:asyncomplete_buffer_words')
        let s:asyncomplete_buffer_words = {}
    endif

    for l:info in getbufinfo()
        if s:AsyncompleteBufferIsTerminal(l:info.bufnr)
            call s:RefreshAsyncompleteBufferWords(l:info.bufnr)
        endif
    endfor
endfunction

function! s:OnAsyncompleteBufferEvent(opt, ctx, event) abort
    if !exists('s:asyncomplete_buffer_words')
        let s:asyncomplete_buffer_words = {}
    endif

    let l:bufnr = str2nr(expand('<abuf>'))
    if l:bufnr <= 0
        let l:bufnr = a:ctx['bufnr']
    endif

    if index(['BufDelete', 'BufUnload', 'BufWipeout'], a:event) >= 0
        if has_key(s:asyncomplete_buffer_words, l:bufnr)
            call remove(s:asyncomplete_buffer_words, l:bufnr)
        endif
        return
    endif

    call s:RefreshAsyncompleteBufferWords(l:bufnr)
endfunction

function! s:AsyncompleteAllBuffersCompletor(opt, ctx) abort
    if !exists('s:asyncomplete_buffer_words')
        call s:WarmAsyncompleteBufferWords()
    endif

    " Terminal output changes asynchronously, so rescan terminal buffers at
    " completion time instead of relying only on buffer events.
    call s:RefreshAsyncompleteTerminalBufferWords()
    call s:RefreshAsyncompleteBufferWords(a:ctx['bufnr'])

    let l:kw = matchstr(a:ctx['typed'], '\k\+$')
    let l:kwlen = len(l:kw)
    if l:kwlen == 0
        return
    endif

    let l:seen = {}
    for l:words in values(s:asyncomplete_buffer_words)
        for l:word in keys(l:words)
            if stridx(l:word, l:kw) == 0 && tolower(l:word) !=# tolower(l:kw)
                let l:seen[l:word] = 1
            endif
        endfor
    endfor

    if empty(l:seen)
        return
    endif

    let l:matches = []
    for l:word in sort(keys(l:seen))
        call add(l:matches, {
            \ 'word': l:word,
            \ 'dup': 1,
            \ 'icase': 1,
            \ 'menu': '[buffer]',
            \ })
    endfor

    call asyncomplete#complete(a:opt['name'], a:ctx, a:ctx['col'] - l:kwlen, l:matches)
endfunction
