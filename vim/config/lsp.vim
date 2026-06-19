if exists('g:dotfiles_lsp_config_loaded')
    finish
endif
let g:dotfiles_lsp_config_loaded = 1

" This must also be set before vim-lsp is loaded; vimrc does that.  Keeping it
" here makes the file self-documenting and harmless if it is sourced directly.
let g:dotfiles_lsp_auto_enable = get(g:, 'dotfiles_lsp_auto_enable', 0)
let g:lsp_auto_enable = g:dotfiles_lsp_auto_enable
let g:dotfiles_lsp_enabled = get(g:, 'dotfiles_lsp_enabled', g:lsp_auto_enable)

" Lightweight defaults.  These avoid the noisiest/background-heavy features.
let g:lsp_diagnostics_enabled = get(g:, 'lsp_diagnostics_enabled', 1)
let g:lsp_document_code_action_signs_enabled = get(g:, 'lsp_document_code_action_signs_enabled', 0)
let g:lsp_preview_keep_focus = get(g:, 'lsp_preview_keep_focus', 1)
let g:lsp_fold_enabled = get(g:, 'lsp_fold_enabled', 0)
let g:lsp_document_highlight_enabled = get(g:, 'lsp_document_highlight_enabled', 0)
let g:lsp_semantic_enabled = get(g:, 'lsp_semantic_enabled', 0)
let g:lsp_inlay_hints_enabled = get(g:, 'lsp_inlay_hints_enabled', 0)

let s:lsp_completion_config = get(g:, 'dotfiles_lsp_completion_config', {
    \ 'filter': {'name': 'prefix'},
    \ 'sort': {'max': 300},
    \ })

function! s:WithLspCompletionConfig(config) abort
    return extend(deepcopy(s:lsp_completion_config), deepcopy(a:config), 'force')
endfunction

" Let vim-lsp-settings handle standard servers.  Keep clangd light unless the
" heavier flags are requested before startup.
let s:clangd_cmd = ['clangd', '--query-driver=/usr/bin/c++,/usr/bin/g++']
if get(g:, 'dotfiles_clangd_background_index', 0)
    call add(s:clangd_cmd, '--background-index')
endif
if get(g:, 'dotfiles_clangd_tidy', 0)
    call add(s:clangd_cmd, '--clang-tidy')
endif

let g:lsp_settings = get(g:, 'lsp_settings', {})

let s:clangd_settings = get(g:lsp_settings, 'clangd', {})
let s:clangd_settings['cmd'] = s:clangd_cmd
let s:clangd_settings['config'] = s:WithLspCompletionConfig(get(s:clangd_settings, 'config', {}))
let g:lsp_settings['clangd'] = s:clangd_settings

let s:julia_settings = get(g:lsp_settings, 'julia-language-server', {})
let s:julia_settings['disabled'] = v:true
let g:lsp_settings['julia-language-server'] = s:julia_settings

function! s:OnLspBufferEnabled() abort
    setlocal omnifunc=lsp#complete
    if exists('+tagfunc')
        setlocal tagfunc=lsp#tagfunc
    endif

    nmap <buffer> gd <plug>(lsp-definition)
    nmap <buffer> gD <plug>(lsp-declaration)
    nmap <buffer> gi <plug>(lsp-implementation)
    nmap <buffer> gr <plug>(lsp-references)
    nmap <buffer> K  <plug>(lsp-hover)
    nmap <buffer> <leader>rn <plug>(lsp-rename)
    nmap <buffer> <leader>ca <plug>(lsp-code-action)
    nmap <buffer> [d <plug>(lsp-previous-diagnostic)
    nmap <buffer> ]d <plug>(lsp-next-diagnostic)
    nmap <buffer> <leader>ds <plug>(lsp-document-symbol-search)
    nmap <buffer> <leader>ws <plug>(lsp-workspace-symbol-search)

    nnoremap <buffer> <leader>ld :LspToggleDiagnostics<CR>
endfunction

function! s:RegisterManualLspServers() abort
    if get(g:, 'dotfiles_lsp_registered_manual_servers', 0)
        return
    endif
    let g:dotfiles_lsp_registered_manual_servers = 1

    " Custom wrapper, separate from vim-lsp-settings' Julia server.
    if executable('julia-lsp')
        call lsp#register_server({
            \ 'name': 'julia-lsp',
            \ 'cmd': {server_info -> ['julia-lsp']},
            \ 'allowlist': ['julia'],
            \ 'root_uri_patterns': ['Project.toml', 'Manifest.toml', '.git/'],
            \ 'config': s:WithLspCompletionConfig({}),
            \ 'priority': 100,
            \ })
    endif

    if !get(g:, 'dotfiles_disable_wolfram_lsp', 0) && executable('wolfram-lsp')
        call lsp#register_server({
            \ 'name': 'wolfram-lsp',
            \ 'cmd': {server_info -> ['wolfram-lsp']},
            \ 'allowlist': ['mma'],
            \ 'root_uri_patterns': ['PacletInfo.wl', '.git/'],
            \ 'config': s:WithLspCompletionConfig({}),
            \ 'priority': 100,
            \ })
    endif
endfunction

function! s:LspOn() abort
    let g:lsp_auto_enable = 1
    let g:dotfiles_lsp_enabled = 1
    call lsp#enable()
    echo 'LSP enabled'
endfunction

function! s:LspOff() abort
    let g:lsp_auto_enable = 0
    let g:dotfiles_lsp_enabled = 0
    silent! call lsp#disable()

    " lsp#disable() prevents further work; this also tries to stop already
    " running server processes when the helper is available.
    if exists('*lsp#get_server_names')
        for l:server in lsp#get_server_names()
            silent! call lsp#stop_server(l:server)
        endfor
    else
        silent! LspStopServer
    endif

    echo 'LSP disabled'
endfunction

function! s:LspToggle() abort
    if get(g:, 'dotfiles_lsp_enabled', 0)
        call s:LspOff()
    else
        call s:LspOn()
    endif
endfunction

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

augroup dotfiles_lsp
    autocmd!
    autocmd User lsp_setup call s:RegisterManualLspServers()
    autocmd User lsp_buffer_enabled call s:OnLspBufferEnabled()
augroup END

command! LspOn call s:LspOn()
command! LspOff call s:LspOff()
command! LspHardOff call s:LspOff()
command! LspToggle call s:LspToggle()
command! LspToggleDiagnostics call s:ToggleLspDiagnostics()
