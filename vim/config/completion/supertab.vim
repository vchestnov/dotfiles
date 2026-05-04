if exists('g:dotfiles_completion_supertab_loaded')
    finish
endif
let g:dotfiles_completion_supertab_loaded = 1

" let g:asyncomplete_enable_for_all = 0
" <Tab> to use vim's native insert completion via SuperTab
let g:SuperTabDefaultCompletionType = '<c-p>'
" shared completion menu
set completeopt=menuone,noselect

" <C-space> is preserved for asyncomplete's LSP completion
" inoremap <C-Space> <C-x><C-o>
" if !has('nvim')
"     inoremap <C-@> <C-x><C-o>
" endif
