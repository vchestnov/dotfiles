if exists('g:dotfiles_completion_supertab_loaded')
    finish
endif
let g:dotfiles_completion_supertab_loaded = 1

" SuperTab owns <Tab> and uses Vim's native insert completion.
" asyncomplete is kept separate for LSP completion and is triggered explicitly with <C-Space>.
let g:SuperTabDefaultCompletionType = get(g:, 'SuperTabDefaultCompletionType', '<c-p>')
