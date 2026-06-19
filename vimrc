set nocompatible
filetype off

" -----------------------------------------------------------------------------
" Dotfiles switches
" -----------------------------------------------------------------------------
let mapleader = ' '

let g:dotfiles_disable_wolfram_lsp = get(g:, 'dotfiles_disable_wolfram_lsp', 0)
let g:dotfiles_wolfram_completion_enabled = get(g:, 'dotfiles_wolfram_completion_enabled', 1)
let g:wolfram_definition_query_runtime_path = get(g:, 'wolfram_definition_query_runtime_path', 0)

" Keep LSP off by default, start it manually with :LspOn
" Vim session with LSP from startup run
"   vim --cmd 'let g:dotfiles_lsp_auto_enable = 1' my_file_here 
let g:dotfiles_lsp_auto_enable = get(g:, 'dotfiles_lsp_auto_enable', 0)
let g:lsp_auto_enable = g:dotfiles_lsp_auto_enable

" Lightweight clangd defaults, chatgpt suggested, boh
"   let g:dotfiles_clangd_background_index = 1
"   let g:dotfiles_clangd_tidy = 1
let g:dotfiles_clangd_background_index = get(g:, 'dotfiles_clangd_background_index', 0)
let g:dotfiles_clangd_tidy = get(g:, 'dotfiles_clangd_tidy', 0)

" -----------------------------------------------------------------------------
" Helper for split config files
" -----------------------------------------------------------------------------
let s:dotfiles_vim_config_dir = fnamemodify(resolve(expand('<sfile>:p')), ':h') . '/vim/config'

function! s:SourceConfig(relpath) abort
    let l:file = s:dotfiles_vim_config_dir . '/' . a:relpath
    if filereadable(l:file)
        execute 'source ' . fnameescape(l:file)
    else
        echom 'Missing vim config: ' . l:file
    endif
endfunction

" Source LSP options before plug#end(), so vim-lsp/vim-lsp-settings see them
" even in sessions started with g:dotfiles_lsp_auto_enable = 1
call s:SourceConfig('lsp.vim')

" -----------------------------------------------------------------------------
" vim-plug bootstrap
" -----------------------------------------------------------------------------
if has('nvim')
    let s:plug_site = stdpath('data') . '/site'
else
    let s:plug_site = expand('~/.vim')
endif

if empty(glob(s:plug_site . '/autoload/plug.vim'))
    silent execute '!curl -fLo ' . shellescape(s:plug_site . '/autoload/plug.vim') .
        \ ' --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
    autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

call plug#begin(expand('~/.vim/plugged'))
    Plug 'tomasr/molokai'
    Plug 'altercation/vim-colors-solarized'
    Plug 'NLKNguyen/papercolor-theme'
    Plug 'morhetz/gruvbox'

    Plug 'preservim/nerdtree'
    Plug 'tpope/vim-commentary'
    Plug 'tpope/vim-surround'
    Plug 'tpope/vim-fugitive'
    Plug 'airblade/vim-gitgutter'
    Plug 'godlygeek/tabular'
    Plug 'bling/vim-airline'
    Plug 'vim-airline/vim-airline-themes'
    Plug 'jpalardy/vim-slime'
    Plug 'konfekt/fastfold'
    Plug 'wellle/targets.vim'
    Plug 'junegunn/fzf'
    Plug 'junegunn/fzf.vim'
    Plug 'machakann/vim-highlightedyank'

    " Completion: SuperTab for Vim-native completion, asyncomplete for LSP
    Plug 'ervandew/supertab'
    Plug 'prabirshrestha/asyncomplete.vim'
    Plug 'prabirshrestha/asyncomplete-lsp.vim'

    " LSP client and server (auto-)configuration
    Plug 'prabirshrestha/vim-lsp'
    Plug 'mattn/vim-lsp-settings'
call plug#end()

syntax on
filetype plugin indent on

call s:SourceConfig('appearance.vim')
call s:SourceConfig('buffers.vim')
call s:SourceConfig('fzf.vim')
call s:SourceConfig('wolfram.vim')
call s:SourceConfig('slime.vim')
call s:SourceConfig('completion/supertab.vim')
call s:SourceConfig('completion/asyncomplete.vim')

" -----------------------------------------------------------------------------
" General options
" -----------------------------------------------------------------------------
set hidden
set nowrap
set tabstop=4
set shiftwidth=4
set expandtab
set autoindent
set copyindent
set number relativenumber
set showmatch
set cpoptions+=M
set magic
set backspace=eol,start,indent
set smartcase
set hlsearch
set incsearch
set laststatus=2
set ttimeoutlen=50
set formatoptions+=ct
set textwidth=79
set showcmd
set splitbelow splitright

" Shared completion menu:
"   SuperTab drives normal completion via <Tab>;
"   asyncomplete is triggered with <C-Space> for LSP suggestions
set completeopt=menuone,noselect,nearest
set wildmenu
set wildmode=full
" less priority in filename completion and file lookups
set suffixes+=.bak,~,.swp,.o,.obj,.pyc

" Popup-menu navigation with ctrl-j/k
inoremap <expr> <C-j> pumvisible() ? "\<C-n>" : "\<C-j>"
inoremap <expr> <C-k> pumvisible() ? "\<C-p>" : "\<C-k>"
inoremap <expr> <CR>  pumvisible() ? "\<C-y>" : "\<CR>"

" Visual-search selected text
vnoremap // y/\V<C-r>=escape(@", '/\')<CR><CR>

" Window navigation with ctrl
nnoremap <C-h> :wincmd h<CR>
nnoremap <C-j> :wincmd j<CR>
nnoremap <C-k> :wincmd k<CR>
nnoremap <C-l> :wincmd l<CR>

" Trim trailing whitespace
function! s:TrimWhitespace() abort
    let l:save = winsaveview()
    silent! %s/\s\+$//e
    call winrestview(l:save)
endfunction
nnoremap <F5> :call <SID>TrimWhitespace()<CR>

" Safer :Remove wrapper
command! -complete=file -nargs=1 Remove
    \ echo 'Remove: ' . <q-args> . ' ' . (delete(<q-args>) == 0 ? 'SUCCEEDED' : 'FAILED')

" -----------------------------------------------------------------------------
" Filetypes and filetype-local settings
" -----------------------------------------------------------------------------
augroup dotfiles_filetypes
    " clear autocmds in this group to avoid re-registering autocmds when
    " re-sourcing vimrc
    autocmd!
    autocmd BufNewFile,BufRead *.frm,*.prc setfiletype form
    autocmd BufNewFile,BufRead *.wl setfiletype mma
    " force override matlab -> mma
    autocmd BufNewFile,BufRead *.m set filetype=mma
    autocmd BufNewFile,BufRead *.sing setfiletype cpp
    autocmd BufNewFile,BufRead *.rr setfiletype asir
    autocmd BufNewFile,BufRead *.tex setfiletype tex
    autocmd BufNewFile,BufRead *.md setfiletype markdown
augroup END

augroup dotfiles_comments
    autocmd!
    autocmd FileType form setlocal commentstring=*\ %s
    autocmd FileType mma  setlocal commentstring=(*%s*)
augroup END

augroup dotfiles_tex
    autocmd!
    autocmd FileType tex setlocal nocursorline nornu number relativenumber
augroup END

" Soft-wrap helper for prose buffers
function! Prose() abort
    setlocal wrap linebreak textwidth=0 expandtab
    nnoremap <buffer> j gj
    nnoremap <buffer> k gk
endfunction

" Marker folds used in FORM files
augroup dotfiles_marker_folds
    autocmd!
    autocmd BufNewFile,BufRead *.frm,*.prc,*.h setlocal foldmethod=marker foldmarker=#[,#]
augroup END

" Custom folds for sectioned shell scripts (e.g. bootstrap.sh)
function! DotfilesFoldShellSectionHeaders(lnum) abort
    let l:line = getline(a:lnum)
    if l:line =~# '^#\s*\(SECTION \d\+:\|INTRO\|SETUP\|SUMMARY\|OUTRO\)'
        return '>1'
    endif
    return '='
endfunction

augroup dotfiles_shell_folds
    autocmd!
    autocmd FileType sh setlocal foldmethod=expr
    autocmd FileType sh setlocal foldexpr=DotfilesFoldShellSectionHeaders(v:lnum)
    autocmd FileType sh setlocal foldtext=getline(v:foldstart)
    autocmd FileType sh setlocal foldlevel=0
augroup END

" -----------------------------------------------------------------------------
" Plugin-specific small settings
" -----------------------------------------------------------------------------
let g:airline#extensions#tabline#enabled = 1
let g:airline#extensions#tabline#fnamemod = ':t'
let g:airline_theme = 'minimalist'
let g:highlightedyank_highlight_duration = 200

function! s:NERDTreeQuitIfLastWindow() abort
    redir => l:buffers_output
    silent buffers
    redir END

    let l:window_found = 0
    let l:pattern = '^\s*\(\d\+\)\(.....\) "\(.*\)"\s\+line \(\d\+\)$'

    for l:line in split(l:buffers_output, "\n")
        let l:match = matchlist(l:line, l:pattern)
        if !empty(l:match) && l:match[2] =~# '..a..'
            let l:window_found = 1
            break
        endif
    endfor

    if !l:window_found
        quitall
    endif
endfunction

augroup dotfiles_nerdtree
    autocmd!
    autocmd WinEnter * call s:NERDTreeQuitIfLastWindow()
augroup END

" -----------------------------------------------------------------------------
" SSH agent refresh helper for remote Vim sessions
" -----------------------------------------------------------------------------
function! RefreshSSHAuthSock() abort
    if !executable('bash')
        echom 'RefreshSSHAuthSock: bash not found'
        return
    endif

    let l:script = expand('~/.local/src/ssh-find-agent/ssh-find-agent.sh')
    if !filereadable(l:script)
        echom 'RefreshSSHAuthSock: script not found: ' . l:script
        return
    endif

    let l:inner = '. ' . shellescape(l:script) . ' >/dev/null 2>&1; ' .
        \ 'ssh-find-agent -a >/dev/null 2>&1; ' .
        \ 'printf %s "$SSH_AUTH_SOCK"'
    let l:raw = substitute(system('bash -lc ' . shellescape(l:inner)), '\n\+$', '', '')
    let l:sock = matchstr(l:raw, '/tmp/ssh-[^[:space:]]\+')

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

" -----------------------------------------------------------------------------
" XDG state/cache locations
" -----------------------------------------------------------------------------
let s:xdg_state = empty($XDG_STATE_HOME) ? expand('~/.local/state') : $XDG_STATE_HOME
let s:xdg_cache = empty($XDG_CACHE_HOME) ? expand('~/.cache') : $XDG_CACHE_HOME

call mkdir(s:xdg_state . '/vim', 'p')
call mkdir(s:xdg_cache . '/vim/swap', 'p')
call mkdir(s:xdg_cache . '/vim/backup', 'p')
call mkdir(s:xdg_cache . '/vim/undo', 'p')

execute 'set viminfo+=n' . fnameescape(s:xdg_state . '/vim/viminfo')
execute 'set directory=' . fnameescape(s:xdg_cache . '/vim/swap') . '//'
execute 'set backupdir=' . fnameescape(s:xdg_cache . '/vim/backup') . '//'
execute 'set undodir=' . fnameescape(s:xdg_cache . '/vim/undo') . '//'
if has('persistent_undo')
    set undofile
endif
