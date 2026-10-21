if exists('g:dotfiles_completion_asyncomplete_loaded')
    finish
endif
let g:dotfiles_completion_asyncomplete_loaded = 1

" asyncomplete is present in all buffers, but it does not pop up by itself.
" This keeps it available for LSP completion without competing with SuperTab.
let g:asyncomplete_enable_for_all = get(g:, 'asyncomplete_enable_for_all', 1)
let g:asyncomplete_auto_popup = get(g:, 'asyncomplete_auto_popup', 0)
let g:asyncomplete_auto_completeopt = get(g:, 'asyncomplete_auto_completeopt', 0)
let g:asyncomplete_matchfuzzy = get(g:, 'asyncomplete_matchfuzzy', 1)

" Explicit LSP/asyncomplete trigger.
imap <silent> <C-Space> <Plug>(asyncomplete_force_refresh)
if !has('nvim')
    imap <silent> <C-@> <Plug>(asyncomplete_force_refresh)
endif

augroup dotfiles_asyncomplete
    autocmd!
    if get(g:, 'dotfiles_wolfram_completion_enabled', 0)
        autocmd User asyncomplete_setup
            \ if exists('*DotfilesWolframRegisterAsyncompleteSource') |
            \     call DotfilesWolframRegisterAsyncompleteSource() |
            \ endif
    endif
augroup END
