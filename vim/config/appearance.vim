if exists('g:dotfiles_appearance_config_loaded')
    finish
endif
let g:dotfiles_appearance_config_loaded = 1

" Colorscheme controls:
" - sets the default theme and core highlight overrides
" - provides :Colorcall to switch between dark/light themes on demand
" - provides grayscale mode for use with PICOM_GREYSCALE / grayscale compositors

set t_Co=256
colorscheme molokai

" Default highlight overrides for the base dark theme.
" https://jonasjacek.github.io/colors/
hi Comment ctermfg=244
hi Visual  ctermbg=240
hi Search  ctermfg=54  ctermbg=208
hi Normal  ctermbg=none
hi Function ctermfg=156

hi DiffAdd    ctermfg=none ctermbg=22
hi DiffChange ctermfg=none ctermbg=236
hi DiffDelete ctermfg=250  ctermbg=52
hi DiffText   ctermfg=231  ctermbg=54

function! SwitchColorscheme(scheme)
  execute 'colorscheme' a:scheme
  if a:scheme ==# 'molokai'
    hi Comment ctermfg=244
    hi Visual  ctermbg=240
    hi Search  ctermfg=54  ctermbg=208
    hi Normal  ctermbg=none
    hi Function ctermfg=156

    hi DiffAdd    ctermfg=none ctermbg=22
    hi DiffChange ctermfg=none ctermbg=236
    hi DiffDelete ctermfg=250  ctermbg=52
    hi DiffText   ctermfg=231  ctermbg=54
  elseif a:scheme ==# 'gruvbox'
    set background=light
    hi Visual ctermfg=235 ctermbg=229
  elseif a:scheme ==# 'solarized'
    set background=light
  endif
endfunction

command! -nargs=1 Colorcall :call SwitchColorscheme(<q-args>)

" Greyscale mode:
" - starts from molokai for a strong dark base
" - reapplies highlights in grayscale-safe tones
" - remembers the previous colorscheme and restores it on toggle-off
let g:greyscale_mode = 0
let g:greyscale_prev_scheme = ''

function! s:ApplyHighlights(dict) abort
  for [grp, spec] in items(a:dict)
    execute 'hi' grp spec
  endfor
endfunction

let s:gray_overrides = {
\ 'Normal':         'ctermfg=252 ctermbg=none',
\ 'Comment':        'ctermfg=244 cterm=NONE',
\ 'Identifier':     'ctermfg=252 cterm=bold',
\ 'Function':       'ctermfg=255 cterm=bold',
\ 'Statement':      'ctermfg=252 cterm=bold',
\ 'Type':           'ctermfg=253 cterm=bold',
\ 'Special':        'ctermfg=254',
\ 'Underlined':     'ctermfg=252 cterm=underline',
\ 'Todo':           'ctermfg=235 ctermbg=229 cterm=bold',
\ 'MatchParen':     'ctermfg=231 ctermbg=242 cterm=bold',
\ 'CursorLine':     'ctermbg=236',
\ 'CursorColumn':   'ctermbg=236',
\ 'LineNr':         'ctermfg=244',
\ 'CursorLineNr':   'ctermfg=252 cterm=bold',
\ 'VertSplit':      'ctermfg=238 ctermbg=none',
\ 'StatusLine':     'ctermfg=252 ctermbg=236 cterm=bold',
\ 'StatusLineNC':   'ctermfg=246 ctermbg=235',
\ 'Pmenu':          'ctermfg=252 ctermbg=236',
\ 'PmenuSel':       'ctermfg=235 ctermbg=252 cterm=bold',
\ 'Search':         'ctermfg=235 ctermbg=250 cterm=bold',
\ 'IncSearch':      'ctermfg=252 ctermbg=238 cterm=reverse',
\ 'Visual':         'ctermfg=252 ctermbg=238',
\ 'Directory':      'ctermfg=252 cterm=bold',
\ 'Title':          'ctermfg=255 cterm=bold',
\ 'Error':          'ctermfg=231 ctermbg=235 cterm=bold,underline',
\ 'ErrorMsg':       'ctermfg=231 ctermbg=235 cterm=bold,underline',
\ 'WarningMsg':     'ctermfg=231 ctermbg=238 cterm=bold',
\ 'MoreMsg':        'ctermfg=252 cterm=bold',
\ 'Question':       'ctermfg=252 cterm=bold',
\ 'Folded':         'ctermfg=248 ctermbg=237',
\ 'SignColumn':     'ctermbg=235',
\ 'DiffAdd':        'ctermfg=none ctermbg=236',
\ 'DiffChange':     'ctermfg=none ctermbg=237',
\ 'DiffDelete':     'ctermfg=250 ctermbg=235',
\ 'DiffText':       'ctermfg=231 ctermbg=240 cterm=bold',
\ }

let s:diag_overrides = {
\ 'DiagnosticError':   'ctermfg=231 ctermbg=235 cterm=bold,underline',
\ 'DiagnosticWarn':    'ctermfg=231 ctermbg=238 cterm=bold',
\ 'DiagnosticInfo':    'ctermfg=252',
\ 'DiagnosticHint':    'ctermfg=246',
\ 'DiagnosticUnderlineError': 'cterm=underline',
\ 'DiagnosticUnderlineWarn':  'cterm=underline',
\ }

let s:gray_symbol_overrides = {}
let s:gray_symbol_overrides.Operator    = 'ctermfg=255 cterm=bold'
let s:gray_symbol_overrides.Delimiter   = 'ctermfg=253 cterm=bold'
let s:gray_symbol_overrides.SpecialChar = 'ctermfg=254 cterm=bold'
let s:gray_symbol_overrides.NonText     = 'ctermfg=240'
let s:gray_symbol_overrides.SpecialKey  = 'ctermfg=240'

function! GreyscaleOn() abort
  if g:greyscale_mode | return | endif
  let g:greyscale_prev_scheme = exists('g:colors_name') ? g:colors_name : ''
  set background=dark
  if exists(':Colorcall')
    silent! execute 'Colorcall molokai'
  else
    silent! colorscheme molokai
  endif
  call s:ApplyHighlights(s:gray_overrides)
  call s:ApplyHighlights(s:gray_symbol_overrides)
  call s:ApplyHighlights(s:diag_overrides)
  let g:greyscale_mode = 1
  echo 'Greyscale mode: ON'
endfunction

function! GreyscaleOff() abort
  if !g:greyscale_mode | return | endif
  if !empty(g:greyscale_prev_scheme) && exists(':Colorcall')
    execute 'Colorcall ' . g:greyscale_prev_scheme
  elseif !empty(g:greyscale_prev_scheme)
    execute 'colorscheme ' . g:greyscale_prev_scheme
  else
    if exists(':Colorcall')
      execute 'Colorcall molokai'
    else
      colorscheme molokai
    endif
  endif
  let g:greyscale_mode = 0
  echo 'Greyscale mode: OFF'
endfunction

command! GreyscaleOn  call GreyscaleOn()
command! GreyscaleOff call GreyscaleOff()

function! GreyscaleToggle() abort
  if get(g:, 'greyscale_mode', 0)
    call GreyscaleOff()
  else
    call GreyscaleOn()
  endif
endfunction

command! GreyscaleToggle call GreyscaleToggle()
nnoremap <leader>tg :GreyscaleToggle<CR>

function! s:MaybeGreyscale() abort
  if exists('$PICOM_GREYSCALE') && $PICOM_GREYSCALE ==# '1'
    call GreyscaleOn()
  endif
endfunction

augroup GreyscaleAuto
  autocmd!
  autocmd VimEnter * call s:MaybeGreyscale()
augroup END
