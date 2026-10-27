if exists('g:dotfiles_appearance_config_loaded')
    finish
endif
let g:dotfiles_appearance_config_loaded = 1

" Colorscheme controls:
" - sets the default theme and core highlight overrides
" - provides :Colorcall to switch between dark/light themes on demand
" - follows toggle-monitor-grayscale's live display CTM state

" Monochrome leaves Vim's default grey gutter and fold backgrounds in place.
" Blend the gutter into the editor and keep closed folds on a dark grey.
function! s:MonochromeHighlights() abort
  for l:group in ['SignColumn', 'FoldColumn', 'GitGutterAdd', 'GitGutterChange', 'GitGutterDelete']
    if hlexists(l:group)
      execute 'highlight ' . l:group . ' ctermbg=NONE guibg=NONE'
    endif
  endfor
  " highlight Folded ctermbg=234 guibg=#1c1c1c
  highlight Folded ctermbg=234 guibg=#404040
endfunction

augroup dotfiles_monochrome
  autocmd!
  autocmd ColorScheme monochrome call <SID>MonochromeHighlights()
augroup END

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
" - uses monochrome with the gutter and fold adjustments above
" - remembers the previous colorscheme and restores it on toggle-off
let g:greyscale_mode = 0
let g:greyscale_prev_scheme = ''

function! GreyscaleOn() abort
  if g:greyscale_mode | return | endif
  let g:greyscale_prev_scheme = exists('g:colors_name') ? g:colors_name : ''
  Colorcall monochrome
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

" Query live state rather than storing a second copy in the environment or a file.
" Only react to display transitions, so a manual :GreyscaleToggle stays effective
" until the next display transition (or an explicit :GreyscaleSync).
let g:greyscale_auto_sync = get(g:, 'greyscale_auto_sync', 1)
" Set g:greyscale_auto_sync = 0 before loading vimrc to keep manual-only behavior.
let s:last_monitor_greyscale = -1
let s:monitor_toggle = fnamemodify(resolve(expand('<sfile>:p')), ':h:h:h')
      \ . '/scripts/toggle-monitor-grayscale'

function! s:MaybeGreyscale(force) abort
  if !g:greyscale_auto_sync && !a:force
    return
  endif

  let l:mode = ''
  if !empty($DISPLAY) && executable(s:monitor_toggle)
    let l:status = trim(system(shellescape(s:monitor_toggle) . ' --status'))
    if v:shell_error == 0 && index(['grayscale', 'color'], l:status) >= 0
      let l:mode = l:status
    endif
  endif

  " Retain the old startup hint for remote/headless sessions or missing scripts.
  if empty(l:mode)
    if s:last_monitor_greyscale == -1 && $PICOM_GREYSCALE ==# '1'
      let l:mode = 'grayscale'
    else
      return
    endif
  endif

  let l:greyscale = l:mode ==# 'grayscale'
  if !a:force && l:greyscale == s:last_monitor_greyscale
    return
  endif
  let s:last_monitor_greyscale = l:greyscale
  if l:greyscale
    silent call GreyscaleOn()
  else
    silent call GreyscaleOff()
  endif
endfunction

command! GreyscaleSync call s:MaybeGreyscale(1)

augroup GreyscaleAuto
  autocmd!
  autocmd VimEnter,FocusGained,VimResume,CursorHold,CursorHoldI * ++nested call s:MaybeGreyscale(0)
augroup END

" Also initialise when this config is first sourced into an existing Vim session.
if v:vim_did_enter
  call s:MaybeGreyscale(0)
endif
