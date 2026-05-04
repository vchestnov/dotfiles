set nocompatible
filetype off

let g:dotfiles_disable_wolfram_lsp = 1
let g:wolfram_definition_query_runtime_path = 0
let g:dotfiles_asyncomplete_fuzzy_buffer_fallback = 1

let g:dotfiles_completion_backend = get(g:, 'dotfiles_completion_backend', 'asyncomplete')
let g:dotfiles_wolfram_completion_enabled = get(g:, 'dotfiles_wolfram_completion_enabled', 0)
let g:dotfiles_disable_wolfram_lsp = get(g:, 'dotfiles_disable_wolfram_lsp', 0)
let g:dotfiles_asyncomplete_fuzzy_buffer_fallback = get(g:, 'dotfiles_asyncomplete_fuzzy_buffer_fallback', 0)
let mapleader=" "
" if g:dotfiles_completion_backend ==# 'asyncomplete'
"     let g:SuperTabMappingForward = '<nul>'
"     let g:SuperTabMappingBackward = '<s-nul>'
" endif

" Check if vim-plug is installed, and install it if missing
" let data_dir = has('nvim') ? stdpath('data') . '/site' : '~/.vim'
if has('nvim')
    let data_dir = call(function('stdpath'), ['data']) . '/site'
else
    let data_dir = '~/.vim'
endif
if empty(glob(data_dir . '/autoload/plug.vim'))
  silent execute '!curl -fLo '.data_dir.'/autoload/plug.vim --create-dirs  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

call plug#begin('~/.vim/plugged')
Plug 'tomasr/molokai'

Plug 'scrooloose/nerdtree'

" Plug 'scrooloose/nerdcommenter'
Plug 'tpope/vim-commentary'

Plug 'ervandew/supertab'
Plug 'prabirshrestha/asyncomplete.vim'
Plug 'prabirshrestha/asyncomplete-lsp.vim'
Plug 'prabirshrestha/asyncomplete-buffer.vim'
Plug 'prabirshrestha/vim-lsp'
Plug 'mattn/vim-lsp-settings'
Plug 'tpope/vim-surround'

Plug 'godlygeek/tabular'

Plug 'tpope/vim-git'
Plug 'tpope/vim-fugitive'
Plug 'airblade/vim-gitgutter'

Plug 'bling/vim-airline'
Plug 'vim-airline/vim-airline-themes'

Plug 'jpalardy/vim-slime'
Plug 'konfekt/fastfold'

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

let s:dotfiles_vim_config_dir = fnamemodify(resolve(expand('<sfile>:p')), ':h') . '/vim/config'
execute 'source ' . fnameescape(s:dotfiles_vim_config_dir . '/appearance.vim')
execute 'source ' . fnameescape(s:dotfiles_vim_config_dir . '/buffers.vim')
execute 'source ' . fnameescape(s:dotfiles_vim_config_dir . '/fzf.vim')
execute 'source ' . fnameescape(s:dotfiles_vim_config_dir . '/wolfram.vim')
execute 'source ' . fnameescape(s:dotfiles_vim_config_dir . '/lsp.vim')
execute 'source ' . fnameescape(s:dotfiles_vim_config_dir . '/slime.vim')

if g:dotfiles_completion_backend ==# 'asyncomplete'
    execute 'source ' . fnameescape(s:dotfiles_vim_config_dir . '/completion/asyncomplete.vim')
elseif g:dotfiles_completion_backend ==# 'supertab'
    execute 'source ' . fnameescape(s:dotfiles_vim_config_dir . '/completion/supertab.vim')
else
    echoerr 'Unknown dotfiles completion backend: ' . g:dotfiles_completion_backend
endif

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

autocmd BufNewFile,BufRead *.prc set filetype=form
autocmd BufNewFile,BufRead *.m,*.wl set filetype=mma
autocmd BufNewFile,BufRead *.sing set filetype=cpp
autocmd BufNewFile,BufRead *.rr set filetype=asir
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

command! -complete=file -nargs=1 Remove :echo 'Remove: '.'<f-args>'.' '.(delete(<f-args>) == 0 ? 'SUCCEEDED' : 'FAILED')

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

autocmd BufNewFile,BufRead *.md set filetype=markdown
"" https://github.com/Konfekt/FastFold
"nmap zuz <Plug>(FastFoldUpdate)
"let g:fastfold_savehook = 1
""let g:fastfold_fold_command_suffixes =  ['x','X','a','A','o','O','c','C']
""let g:fastfold_fold_movement_commands = [']z', '[z', 'zj', 'zk']
"let g:fastfold_fold_command_suffixes =  []
"let g:fastfold_fold_movement_commands = []

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

set viminfo+=n$XDG_STATE_HOME/vim/viminfo
set directory=$XDG_CACHE_HOME/vim/swap//
set backupdir=$XDG_CACHE_HOME/vim/backup//
set undodir=$XDG_CACHE_HOME/vim/undo//
