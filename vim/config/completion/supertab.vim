if exists('g:dotfiles_completion_supertab_loaded')
    finish
endif
let g:dotfiles_completion_supertab_loaded = 1

let g:asyncomplete_enable_for_all = 0
let g:SuperTabDefaultCompletionType = '<c-p>'
set completeopt=menuone,noselect

inoremap <C-Space> <C-x><C-o>
if !has('nvim')
    inoremap <C-@> <C-x><C-o>
endif
