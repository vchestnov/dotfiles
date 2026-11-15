" Make ordinary Vim sessions reachable from code references in PDF reports.
if exists('g:loaded_dotfiles_coderef')
  finish
endif
let g:loaded_dotfiles_coderef = 1

augroup dotfiles_coderef
  autocmd!
  autocmd VimEnter * call coderef#StartServer()
  autocmd BufWinLeave * call coderef#ClearHighlight()
augroup END

" Also allow enabling this in an already running session with :runtime.
if v:vim_did_enter
  call coderef#StartServer()
endif
