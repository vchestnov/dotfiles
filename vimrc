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
"Plug 'konfekt/fastfold'
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
  elseif a:scheme ==# 'solarized'
    set background=light
  endif
endfunction

command! -nargs=1 Colorcall :call SwitchColorscheme(<q-args>)


let mapleader=" "
" vim-commentary Settings
autocmd Filetype form setlocal commentstring=*\ %s
autocmd Filetype mma setlocal commentstring=(*%s*)

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
" autocmd BufNewFile,BufRead *.rr set filetype=asir
autocmd BufNewFile,BufRead *.rr set filetype=c
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
        let file = printf("/tmp/.slime.%c.m", 97 + g:slime_mma_paste_index)
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
        let file = printf("/tmp/.slime.%c.m", 97 + g:slime_mma_paste_index)
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
        let file = printf("/tmp/.slime.%c.rr", 97 + g:slime_asir_paste_index)
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
