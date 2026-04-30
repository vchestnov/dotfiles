if exists('g:dotfiles_lsp_config_loaded')
    finish
endif
let g:dotfiles_lsp_config_loaded = 1

let g:lsp_diagnostics_enabled = 1
let g:lsp_document_code_action_signs_enabled = 0
let g:lsp_preview_keep_focus = 1
let g:lsp_fold_enabled = 0
let g:lsp_settings = {
\ 'clangd': {
\   'cmd': ['clangd', '--background-index', '--clang-tidy', '--query-driver=/usr/bin/c++,/usr/bin/g++'],
\ },
\ 'julia-language-server': {
\   'disabled': v:true,
\ },
\}

function! s:ToggleLspDiagnostics() abort
    let l:bufnr = bufnr('%')

    if get(b:, 'dotfiles_lsp_diagnostics_disabled', 0)
        call lsp#enable_diagnostics_for_buffer(l:bufnr)
        let b:dotfiles_lsp_diagnostics_disabled = 0
        echo 'LSP diagnostics enabled'
    else
        call lsp#disable_diagnostics_for_buffer(l:bufnr)
        let b:dotfiles_lsp_diagnostics_disabled = 1
        echo 'LSP diagnostics disabled'
    endif
endfunction

function! s:OnLspBufferEnabled() abort
    setlocal omnifunc=lsp#complete
    if exists('+tagfunc')
        setlocal tagfunc=lsp#tagfunc
    endif

    nmap <buffer> gd <plug>(lsp-definition)
    nmap <buffer> gD <plug>(lsp-declaration)
    nmap <buffer> gi <plug>(lsp-implementation)
    nmap <buffer> gr <plug>(lsp-references)
    nmap <buffer> K <plug>(lsp-hover)
    nmap <buffer> <leader>rn <plug>(lsp-rename)
    nmap <buffer> <leader>ca <plug>(lsp-code-action)
    nmap <buffer> [d <plug>(lsp-previous-diagnostic)
    nmap <buffer> ]d <plug>(lsp-next-diagnostic)
    nmap <buffer> <leader>ds <plug>(lsp-document-symbol-search)
    nmap <buffer> <leader>ws <plug>(lsp-workspace-symbol-search)
    nnoremap <buffer> <leader>ld :LspToggleDiagnostics<CR>
    if &filetype ==# 'mma'
        nnoremap <buffer> <leader>wd :WolframGotoDefinition<CR>
    endif
endfunction

function! s:RegisterLspServers() abort
    if get(g:, 'dotfiles_lsp_registered', 0)
        return
    endif
    let g:dotfiles_lsp_registered = 1

    if executable('pylsp')
        call lsp#register_server({
            \ 'name': 'pylsp',
            \ 'cmd': {server_info->['pylsp']},
            \ 'allowlist': ['python'],
            \ })
    endif

    if executable('julia-lsp')
        call lsp#register_server({
            \ 'name': 'julia-lsp',
            \ 'cmd': {server_info->['julia-lsp']},
            \ 'allowlist': ['julia'],
            \ 'root_uri_patterns': ['Project.toml', 'Manifest.toml', '.git/'],
            \ })
    endif

    if !get(g:, 'dotfiles_disable_wolfram_lsp', 0) && executable('wolfram-lsp')
        call lsp#register_server({
            \ 'name': 'wolfram-lsp',
            \ 'cmd': {server_info->['wolfram-lsp']},
            \ 'allowlist': ['mma'],
            \ 'root_uri_patterns': ['PacletInfo.wl', '.git/'],
            \ })
    endif
endfunction

augroup lsp_setup
    autocmd!
    autocmd User lsp_setup call s:RegisterLspServers()
    autocmd User lsp_buffer_enabled call s:OnLspBufferEnabled()
augroup END

command! LspToggleDiagnostics call s:ToggleLspDiagnostics()
