set nocompatible
filetype off

" Check if vim-plug is installed, and install it if missing
let data_dir = has('nvim') ? stdpath('data') . '/site' : '~/.vim'
if empty(glob(data_dir . '/autoload/plug.vim'))
  silent execute '!curl -fLo '.data_dir.'/autoload/plug.vim --create-dirs  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

call plug#begin('~/.vim/plugged')
Plug 'VundleVim/Vundle.vim'

Plug 'tomasr/molokai'

Plug 'scrooloose/nerdtree'

" Plug 'jeetsukumaran/vim-buffergator'
" Plug 'kien/ctrlp.vim'

" Plug 'scrooloose/nerdcommenter'
Plug 'tpope/vim-commentary'

Plug 'ervandew/supertab'
Plug 'tpope/vim-surround'

Plug 'godlygeek/tabular'
"Plug 'nathanaelkane/vim-indent-guides'

Plug 'tpope/vim-git'
Plug 'tpope/vim-fugitive'
Plug 'airblade/vim-gitgutter'

Plug 'bling/vim-airline'
Plug 'vim-airline/vim-airline-themes'

" Plug 'restore_view.vim'
Plug 'jpalardy/vim-slime'
Plug 'konfekt/fastfold'
"Plug 'lervag/vimtex'

Plug 'wellle/targets.vim'

Plug 'junegunn/fzf'
Plug 'junegunn/fzf.vim'

Plug 'altercation/vim-colors-solarized'
Plug 'NLKNguyen/papercolor-theme'
Plug 'morhetz/gruvbox'

Plug 'machakann/vim-highlightedyank'
call plug#end()

syntax on
filetype plugin indent on

function! NERDTreeQuit()
    redir => buffersoutput
    silent buffers
    redir END
    "                   1BufNo  2Mods.     3File           4LineNo
    let pattern = '^\s*\(\d\+\)\(.....\) "\(.*\)"\s\+line \(\d\+\)$'
    let windowfound = 0

    for bline in split(buffersoutput,"\n")
        let m = matchlist(bline, pattern)

        if (len(m) > 0)
                if (m[2] =~ '..a..')
                        let windowfound = 1
                    endif
            endif
    endfor

    if (!windowfound)
        quitall
    endif
endfunction
autocmd WinEnter * call NERDTreeQuit()

autocmd VimEnter * wincmd w


set hidden       " hides buffers, instead of closing them
set nowrap       " don't wrap lines
set tabstop=4    " a tab is 4 spaces
set shiftwidth=4 " when indenting with '>', use 4 spaces width
set expandtab    " on pressing tab, insert 4 spaces
set autoindent   " always set autoindent on
set copyindent   " copy the previous indentation on autoindenting
set number       " always show line numbers
set showmatch    " set show matching parenthesis

set cpoptions+=M

set magic
set backspace=eol,start,indent
set smartcase
set hlsearch
set incsearch

set laststatus=2
set ttimeoutlen=50

set formatoptions+=ct
set tw=79

function! PrefsttW()
  " Soft wrap settings
  set wrap
  set linebreak
  nnoremap j gj
  nnoremap k gk
  set tw=0
  " Indentation settings
  " set tabstop=2
  " set shiftwidth=2
  " set softtabstop=2
  set expandtab
endfunction

set t_Co=256
colorscheme molokai
" https://jonasjacek.github.io/colors/
hi Comment ctermfg=244
hi Visual  ctermbg=240
hi Search  ctermfg=54  ctermbg=208
hi Normal  ctermbg=none
hi Function ctermfg=156

hi DiffAdd    ctermfg=none ctermbg=22
hi DiffChange ctermfg=none ctermbg=236
" hi DiffChange ctermfg=255  ctermbg=236
" hi DiffDelete ctermfg=81  ctermbg=52
" hi DiffText   ctermfg=52  ctermbg=173
hi DiffDelete ctermfg=250  ctermbg=52
" hi DiffText   ctermfg=52   ctermbg=173
" hi DiffText   ctermfg=240   ctermbg=189
hi DiffText   ctermfg=231   ctermbg=54

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
    hi DiffText   ctermfg=231   ctermbg=54
  elseif a:scheme ==# 'gruvbox'
    set background=light
    " hi Visual ctermfg=235 ctermbg=214
    " Alternative lighter options:
    " hi Visual ctermfg=235 ctermbg=223  " Even lighter background
    hi Visual ctermfg=235 ctermbg=229  " Very light background
  elseif a:scheme ==# 'solarized'
    set background=light
  endif
endfunction

command! -nargs=1 Colorcall :call SwitchColorscheme(<q-args>)

" --- Greyscale toggle: a dark, high-contrast, red-free variant for grayscale compositors ---
let g:greyscale_mode = 0
let g:greyscale_prev_scheme = ''

function! s:ApplyHighlights(dict) abort
  for [grp, spec] in items(a:dict)
    execute 'hi' grp spec
  endfor
endfunction

" Hand-picked cterm grays + attrs. Focus on contrast, not hue.
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

" If you use LSP/diagnostics, make errors pop without red hue:
let s:diag_overrides = {
\ 'DiagnosticError':   'ctermfg=231 ctermbg=235 cterm=bold,underline',
\ 'DiagnosticWarn':    'ctermfg=231 ctermbg=238 cterm=bold',
\ 'DiagnosticInfo':    'ctermfg=252',
\ 'DiagnosticHint':    'ctermfg=246',
\ 'DiagnosticUnderlineError': 'cterm=underline',
\ 'DiagnosticUnderlineWarn':  'cterm=underline',
\ }

" function! GreyscaleOn() abort
"   if g:greyscale_mode | return | endif
"   let g:greyscale_prev_scheme = exists('g:colors_name') ? g:colors_name : ''
"   set background=dark
"   " Start from molokai (solid dark base), then override with grayscale-safe defs.
"   " Use your helper so your molokai tweaks apply first:
"   if exists(':Colorcall')
"     silent! execute 'Colorcall molokai'
"   else
"     silent! colorscheme molokai
"   endif
"   call s:ApplyHighlights(s:gray_overrides)
"   call s:ApplyHighlights(s:diag_overrides)
"   let g:greyscale_mode = 1
"   echo 'Greyscale mode: ON'
" endfunction

function! GreyscaleOff() abort
  if !g:greyscale_mode | return | endif
  " Restore previous scheme (and your custom per-scheme tweaks)
  if !empty(g:greyscale_prev_scheme) && exists(':Colorcall')
    execute 'Colorcall ' . g:greyscale_prev_scheme
  elseif !empty(g:greyscale_prev_scheme)
    execute 'colorscheme ' . g:greyscale_prev_scheme
  else
    " Fallback to your default path:
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

" Handy mapping
nnoremap <leader>tg :GreyscaleToggle<CR>

" Brighter punctuation/operators
let s:gray_symbol_overrides = {}
let s:gray_symbol_overrides.Operator    = 'ctermfg=255 cterm=bold'  " = + - * etc.
let s:gray_symbol_overrides.Delimiter   = 'ctermfg=253 cterm=bold'  " ; , ( ) { } etc.
let s:gray_symbol_overrides.SpecialChar = 'ctermfg=254 cterm=bold'  " ! @ # % ^ & etc.
let s:gray_symbol_overrides.NonText     = 'ctermfg=240'
let s:gray_symbol_overrides.SpecialKey  = 'ctermfg=240'

" Re-define GreyscaleOn to include the new symbol overrides
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

" --- Clean autocmd: no inline if/endif, so no trailing characters error ---
function! s:MaybeGreyscale() abort
  if exists('$PICOM_GREYSCALE') && $PICOM_GREYSCALE ==# '1'
    call GreyscaleOn()
  endif
endfunction

augroup GreyscaleAuto
  autocmd!
  autocmd VimEnter * call s:MaybeGreyscale()
augroup END

let mapleader=" "
" vim-commentary Settings
autocmd Filetype form setlocal commentstring=*\ %s
autocmd Filetype mma setlocal commentstring=(*%s*)

if &filetype ==# 'form'
  setlocal commentstring=*%s

  " Override gc in normal, visual, and operator-pending modes
  nmap  <buffer> gc <Plug>(FormCommentOperator)
  xmap  <buffer> gc :<C-u>call FormCommentRange(line("'<"), line("'>"))<CR>
  omap  <buffer> gc :<C-u>set operatorfunc=FormCommentOpFunc<CR>g@

  " Operator-pending entry point
  nnoremap <silent> <Plug>(FormCommentOperator) :set operatorfunc=FormCommentOpFunc<CR>g@
endif

function! FormCommentLineToggle(line)
  let l:line = getline(a:line)
  if l:line =~ '^\*'
    call setline(a:line, substitute(l:line, '^\*', '', ''))
  else
    call setline(a:line, '*' . l:line)
  endif
endfunction

function! FormCommentRange(start, end)
  for lnum in range(a:start, a:end)
    call FormCommentLineToggle(lnum)
  endfor
endfunction

function! FormCommentOpFunc(type)
  " if a:type ==# 'line'
    call FormCommentRange(line("'["), line("']"))
  " elseif a:type ==# 'char' || a:type ==# 'block'
  "   " Expand to whole lines for simplicity
  "   call FormCommentRange(line("'<"), line("'>"))
  " endif
endfunction


nmap <silent> <C-h> :wincmd h<CR>
nmap <silent> <C-j> :wincmd j<CR>
nmap <silent> <C-k> :wincmd k<CR>
nmap <silent> <C-l> :wincmd l<CR>

" Airline Settings
let g:airline#extensions#tabline#enabled = 1
let g:airline#extensions#tabline#fnamemod = ':t'
let g:airline_theme = 'minimalist'

let g:highlightedyank_highlight_duration = 200
set showcmd

" " CtrlP Settings
" let g:ctrlp_user_command = {
"             \ 'types': {
"             \ 1: ['.git', 'cd %s && git ls-files --exclude-standard --others --cached'],
"             \ 2: ['.hg', 'hg --cwd %s locate -I .'],
"             \ },
"             \ 'fallback': 'find %s -type f'
"             \ }

" " Use nearest .git dir
" let g:ctrlp_working_path_mode = 'r'

" nmap <leader>p :CtrlP<cr>

" " Buffer controls to go with Buffergator
" nmap <leader>b? :map <leader>b<cr>
" nmap <leader>bb :CtrlPBuffer<cr>
" nmap <leader>bl :ls<cr>:b<space>
" nmap <leader>bm :CtrlPMixed<cr>
" nmap <leader>bq :bp <BAR> bd #<cr>
" nmap <leader>bs :CtrlPMRU<cr>

""
"" Buffergator Options
""
"" Use the right side of the screen
"let g:buffergator_viewport_split_policy = 'R'

"" I want my own keymappings...
"let g:buffergator_suppress_keymaps = 1

"" Looper buffers
"let g:buffergator_mru_cycle_loop = 1

"" " Go to the previous buffer open
"" nmap <leader>jj :BuffergatorMruCyclePrev<cr>

"" " Go to the next buffer open
"" nmap <leader>kk :BuffergatorMruCycleNext<cr>

"" " View the entire list of buffers open
" nmap <leader>bl :BuffergatorOpen<cr>

" " Shared bindings
" nmap <leader>T :enew<cr>
" nmap <leader>bq :bp <BAR> bd #<cr>

autocmd BufNewFile,BufRead *.prc set filetype=form
autocmd BufNewFile,BufRead *.m,*.wl set filetype=mma
autocmd BufNewFile,BufRead *.sing set filetype=cpp
autocmd BufNewFile,BufRead *.rr set filetype=asir
" autocmd BufNewFile,BufRead *.rr set filetype=c
autocmd BufNewFile,BufRead *.tex set filetype=tex
" autocmd BufNewFile,BufRead *.h set filetype=form

" restore_view settings
set viewoptions=cursor,folds,slash,unix
" let g:skipview_file=['*\.vim']

autocmd BufNewFile,BufRead *.frm,*.prc,*.h set foldmethod=marker
autocmd BufNewFile,BufRead *.frm,*.prc,*.h set foldmarker=#[,#]
"autocmd BufNewFile,BufRead *.m set foldmethod=indent
autocmd BufNewFile,BufRead *.tex
    \ set nocursorline |
    \ set nornu |
    \ set number relativenumber |

"let g:vimtex_fold_enabled = 1
"let g:tex_fold_enabled = 1

command! -complete=file -nargs=1 Remove :echo 'Remove: '.'<f-args>'.' '.(delete(<f-args>) == 0 ? 'SUCCEEDED' : 'FAILED')

let g:ConqueTerm_SessionSupport = 1

""Highlight long lines with grey
""http://blog.ezyang.com/2010/03/vim-textwidth/
"augroup vimrc_autocmds
"    autocmd BufEnter *.m highlight OverLength ctermbg=darkgrey guibg=#592929
"    autocmd BufEnter *.m match OverLength /\%100v.*/
"augroup END

"Remove all trailing whitespace by pressing F5
fun! TrimWhitespace()
    let l:save = winsaveview()
    %s/\s\+$//e
    call winrestview(l:save)
endfun
nnoremap <F5> :call TrimWhitespace()<CR>


" Enable autocompletion
set wildmode=longest,list,full

" Splits open at the bottom and right
set splitbelow splitright

" Search for visual selected text
vnoremap // y/\V<C-R>=escape(@",'/\')<CR><CR>

" Relative line number
set number relativenumber

"augroup numbertoggle
"  autocmd!
"  autocmd BufEnter,FocusGained,InsertLeave * set relativenumber
"  autocmd BufLeave,FocusLost,InsertEnter   * set norelativenumber
"augroup END

" Toggle status line
" https://unix.stackexchange.com/a/140899
let s:hidden_all = 0
function! ToggleHiddenAll()
    if s:hidden_all  == 0
        let s:hidden_all = 1
        set noshowmode
        set noruler
        set laststatus=0
        set noshowcmd
    else
        let s:hidden_all = 0
        set showmode
        set ruler
        set laststatus=2
        set showcmd
    endif
endfunction

"nnoremap <S-h> :call ToggleHiddenAll()<CR>

autocmd BufNewFile,BufRead *.md set filetype=markdown
"" https://github.com/Konfekt/FastFold
"nmap zuz <Plug>(FastFoldUpdate)
"let g:fastfold_savehook = 1
""let g:fastfold_fold_command_suffixes =  ['x','X','a','A','o','O','c','C']
""let g:fastfold_fold_movement_commands = [']z', '[z', 'zj', 'zk']
"let g:fastfold_fold_command_suffixes =  []
"let g:fastfold_fold_movement_commands = []

" Vim-Slime config
let g:slime_target = "vimterminal"
let g:slime_paste_file = "/tmp/.slime_paste"
let g:slime_python_ipython = 1
let g:slime_mma_paste_index = 0
let g:slime_asir_paste_index = 0
function! _EscapeText_mma(text)
    let text = substitute(a:text, "\n*$", "", "")
    if count(text, "\n") >= 2
        let file = printf("/tmp/.seva.slime.%c.m", 97 + g:slime_mma_paste_index)
        let g:slime_mma_paste_index = (g:slime_mma_paste_index + 1) % 26
        call writefile(split(a:text, "\n"), file, "b")
        return ["Get[\"" . file . "\"]\n"]
    else
        return [text . "\n"]
    endif
endfunction
function! _EscapeText_mmaCodeInspect(text)
    echo "mmaCodeInspect"
    let text = substitute(a:text, "\n*$", "", "")
    if count(text, "\n") >= 2
        let file = printf("/tmp/.seva.slime.%c.m", 97 + g:slime_mma_paste_index)
        let g:slime_mma_paste_index = (g:slime_mma_paste_index + 1) % 26
        call writefile(split(a:text, "\n"), file, "b")
        " return ["Get[\"" . file . "\"]\n"]
        return ["ReadString[\"" . file . "\"] // CodeInspect\n"]
    else
        " return [text . "\n"]
        return ["\"" . text . "\" // CodeInspect\n"]
    endif
    " let text = substitute(a:text, "\n*$", "", "")
    " let file = printf("/tmp/.slime.%c.m", 97 + g:slime_mma_paste_index)
    " let g:slime_mma_paste_index = (g:slime_mma_paste_index + 1) % 26
    " call writefile(split(a:text, "\n"), file, "b")
    " call slime#send("ReadString[\"" . file . "\"] // CodeInspect\n")
endfunction
function! _EscapeText_asir(text)
    let text = substitute(a:text, "\n*$", "", "")
    if count(text, "\n") >= 2
        let file = printf("/tmp/.seva.slime.%c.rr", 97 + g:slime_asir_paste_index)
        let g:slime_asir_paste_index = (g:slime_asir_paste_index + 1) % 26
        call writefile(add(split(a:text, "\n"), "end\$"), file, "b")
        return ["load(\"" . file . "\");\n"]
    else
        return [text . "\n"]
    endif
endfunction

" The main command is :Repl <command>
function! ReplV(first, ...)
    " let size = get(a:, 1, 150)
    let l:size = a:first =~ '^[0-9]*$' ? str2nr(a:first) : 0
    " echo l:size
    if !(l:size)
       let l:size = 150
       let l:command = join([a:first] + a:000)
    else
        let l:command = join(a:000)
    endif
    " echo l:size
    " echo l:command
    " " this doesn't work
    " set termwinsize="0x" . string(size)
    " set termwinsize = 0x150
    let oldbuf = bufnr("%")
    " exec "vert rightb term ++close " . a:args
    " exec "vert rightb term ++cols=" . size . " ++close " . a:args
    exec "vert botright term ++cols=" . l:size . " ++close " . l:command
    let g:slime_target = "vimterminal"
    call setbufvar(oldbuf, "slime_config", {"bufnr": bufnr("%")})
    exec ":vertical resize " . l:size
    " exec ":vertical resize 150"
    exec ":set winfixwidth"
    " exec ":vertical resize 80"
    exec ":wincmd p"
endfunction

function! ReplH(args, ...)
    let size = get(a:, 1, 30)
    let size = str2nr(size)
    if !(size)
       let size = 30
    endif
    " set termwinsize=30x0
    let oldbuf = bufnr("%")
    " exec "rightb term ++close " . a:args
    exec "rightb term ++rows=" . size . " ++close " . a:args
    let g:slime_target = "vimterminal"
    call setbufvar(oldbuf, "slime_config", {"bufnr": bufnr("%")})
    exec ":5wincmd -"
    exec ":vertical resize " . size
    " exec ":resize 30"
    exec ":wincmd p"
endfunction
command! -nargs=* Repl call ReplV(<q-args>)
" command! -nargs=* ReplV call ReplV(<q-args>)
" command! -nargs=* ReplH call ReplH(<q-args>)
command! -nargs=* ReplV call ReplV(<f-args>)
command! -nargs=* ReplH call ReplH(<f-args>)

" Repl interaction key bindings:
"   F1 to send the current paragraph (or selected text)
"   F2 to send the current word
xmap <F1> <Plug>SlimeRegionSend
nmap <F1> <Plug>SlimeParagraphSend
nmap <F2> vaw<F1>

" " https://vi.stackexchange.com/a/16709
" " this causes a crash when used together with FZF
" augroup termIgnore
"     autocmd!
"     autocmd TerminalOpen * set nobuflisted
" augroup END

" https://vi.stackexchange.com/a/37045
function! s:bswitch_normal(count, direction)
    " This function switches to the previous or next normal buffer excluding
    " all special buffers like quickfix or terminals
    " Modified version of https://vi.stackexchange.com/a/16710/37509
    let l:count = a:count
    let l:cmd = (a:direction ==# 'previous') ? 'bprevious' : 'bnext'
    let l:start_buffer = bufnr('%')
    while 1
        execute 'keepalt ' . l:cmd
        if &buftype == ''
            let l:count -= 1
            if l:count <= 0
                break
            endif
        endif
        " Prevent infinite loops if no buffer is a normal buffer
        if bufnr('%') == l:start_buffer && l:count == a:count
            break
        endif
    endwhile
    if bufnr('%') != l:start_buffer
        " Jump back to the start buffer once to set the alternate buffer
        execute 'buffer ' . l:start_buffer
        buffer #
    endif
endfunction


" function! s:bswitch_normal(count, direction)
"     " This function switches to the previous or next normal buffer excluding
"     " all special buffers like quickfix or terminals
"     let l:normal_buffers = filter(
"                 \ range(1, bufnr('$')),
"                 \ 'buflisted(v:val) && getbufvar(v:val, "&buftype") == ""'
"                 \ )
"     if a:direction ==# 'previous'
"         call reverse(l:normal_buffers)
"     endif
"     let l:next_buffer_index = 0
"     " while
"     "   `l:next_buffer_index` is not out of range and
"     "   direction is 'next'      =>  buffer number <= active buffer number and
"     "   direction is 'previous'  =>  buffer number >= active buffer number
"     " `a => b` is expressed with `!a || b`
"     while l:next_buffer_index < len(l:normal_buffers) &&
"                 \ (a:direction ==# 'previous' || l:normal_buffers[l:next_buffer_index] <= bufnr('%')) &&
"                 \ (a:direction !=# 'previous' || l:normal_buffers[l:next_buffer_index] >= bufnr('%'))
"         let l:next_buffer_index += 1
"     endwhile
"     let l:next_buffer_index = (l:next_buffer_index + a:count - 1) % len(l:normal_buffers)
"     execute 'buffer ' . l:normal_buffers[l:next_buffer_index]
" endfunction

" Taken from `:help SID`
function! s:SID()
    return matchstr(expand('<SID>'), '<SNR>\zs\d\+\ze_')
endfunction

nnoremap <silent> <leader>bp :<C-u>execute 'call <SNR>' . <SID>SID() . '_bswitch_normal(' . v:count1 . ', "previous")'<CR>
nnoremap <silent> <leader>bn :<C-u>execute 'call <SNR>' . <SID>SID() . '_bswitch_normal(' . v:count1 . ', "next")'<CR>

" Enable enhanced command-line completion
set wildmenu
" Make tab completion complete the extension too
" set wildmode=longest:full,full
set wildmode=full

" Deprioritize LaTeX auxiliary files during tab completion
set suffixes=.aux,.log,.dvi,.bak,.bbl,.blg,.out,.toc,.fdb_latexmk,.fls,.synctex.gz,.pdf
" Add extensions to be checked when searching for files
set suffixesadd=.tex,.bib,.sty

" Enable custom folding for shell scripts
augroup ShellScriptFolds
    autocmd!
    autocmd FileType sh setlocal foldmethod=expr
    autocmd FileType sh setlocal foldexpr=FoldShellSectionHeaders(v:lnum)
    autocmd FileType sh setlocal foldtext=getline(v:foldstart)
    autocmd FileType sh setlocal foldlevel=0
augroup END

function! FoldShellSectionHeaders(lnum)
  let line = getline(a:lnum)

  " If the line matches the SECTION header, it's a new fold level
  if line =~ '^#\s*\(SECTION \d\+:\|INTRO\|SETUP\|SUMMARY\|OUTRO\)'
    return '>1'
  endif

  " Otherwise, use previous fold level
  return '='
endfunction

" Refresh SSH_AUTH_SOCK in Vim using ssh-find-agent on fire-chief-ash
function! RefreshSSHAuthSock() abort
    " if system('hostname') !~# 'fire-chief-ash'
    "     return
    " endif
    if !executable('bash')
        echom 'RefreshSSHAuthSock: bash not found'
        return
    endif

    " Path to ssh-find-agent script
    let l:script = expand('~/.local/src/ssh-find-agent/ssh-find-agent.sh')

    " Check if script exists before sourcing it
    if !filereadable(l:script)
        echom 'RefreshSSHAuthSock: script not found: ' . l:script
        return
    endif

    " Run ssh-find-agent in a fresh bash and print the resulting SSH_AUTH_SOCK
    let l:cmd =
        \ 'bash -lc ''' .
        \ '. ' . fnameescape(l:script) . ' >/dev/null 2>&1; ' .
        \ 'ssh-find-agent -a >/dev/null 2>&1; ' .
        \ 'printf %s "$SSH_AUTH_SOCK"' .
        \ ''''

    " Run the command
    let l:raw = system(l:cmd)
    " Strip trailing newlines
    let l:raw = substitute(l:raw, '\n\+$', '', '')

    " Extract something that looks like an ssh-agent socket path
    " Example: /tmp/ssh-XXXX/agent.12345
    let l:sock = matchstr(l:raw, '/tmp/ssh-[^[:space:]]\+')

    " Optional: stricter validation of the agent path shape
    if !empty(l:sock) && l:sock !~# '^/tmp/ssh-.\+/agent\.\d\+$'
        echom 'RefreshSSHAuthSock: ignoring suspicious socket path: ' . l:sock
        let l:sock = ''
    endif

    if empty(l:sock)
        echom 'RefreshSSHAuthSock: no valid socket found in output: ' . l:raw
        return
    endif

    let $SSH_AUTH_SOCK = l:sock
    echom 'SSH_AUTH_SOCK set to ' . l:sock
endfunction

command! RefreshSSHAuthSock call RefreshSSHAuthSock()

command! MathematicaClean call s:MathematicaClean()
function! s:MathematicaClean() abort
  " " 1) Uncomment whole-line Mathematica comments that are NOT cell markers
  " "    (* code *)  -> code
  " "    (*(* c *)*) -> (* c *)
  " silent! g/^\s*(\*.\{-}\*)\s*$/ if getline('.') !~# '^\s*(\*\s*::' | s/^\s*(\*\(.\{-}\)\*)\s*$/\1/ | endif

  " 2) Delete Input marker lines (including ::Input::Initialization:: etc.)
  silent! g/^\s*(\*\s*::Input::.\{-}::\s*\*)\s*$/d

  " 3) For remaining cell markers, remove only the Initialization token, keep Closed/Open state
  silent! g/^\s*(\*\s*::/ s/::Initialization//g

  " 4) Normalize spacing for real comment lines (not markers):
  "    (*foo*) -> (* foo *)
  silent! g/^\s*(\*[^:]/ s/(\*\s*/(* / | s/\s*\*)/ *)/
endfunction


set viminfo+=n$XDG_STATE_HOME/vim/viminfo
set directory=$XDG_CACHE_HOME/vim/swap//
set backupdir=$XDG_CACHE_HOME/vim/backup//
set undodir=$XDG_CACHE_HOME/vim/undo//
