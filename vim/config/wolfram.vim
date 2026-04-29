if exists('g:dotfiles_wolfram_config_loaded')
    finish
endif
let g:dotfiles_wolfram_config_loaded = 1

if !exists('g:wolfram_definition_search_paths')
    let g:wolfram_definition_search_paths = ['~/.local/share/Wolfram/ApplicationData/Applications']
endif
if !exists('g:wolfram_definition_query_runtime_path')
    let g:wolfram_definition_query_runtime_path = 1
endif
if !exists('g:wolfram_definition_path_exclude_patterns')
    let g:wolfram_definition_path_exclude_patterns = [
        \ '/Documentation/',
        \ '/SystemFiles/Data/',
        \ '/SystemFiles/Links/',
        \ ]
endif

function! s:WolframRuntimePathsCacheFile() abort
    let l:cache_root = expand($XDG_CACHE_HOME !=# '' ? $XDG_CACHE_HOME : '~/.cache')
    let l:cache_dir = l:cache_root . '/vim'
    call mkdir(l:cache_dir, 'p')
    return l:cache_dir . '/wolfram-runtime-paths.txt'
endfunction

function! s:WolframSymbolsCacheFile(paths) abort
    let l:cache_root = expand($XDG_CACHE_HOME !=# '' ? $XDG_CACHE_HOME : '~/.cache')
    let l:cache_dir = l:cache_root . '/vim'
    call mkdir(l:cache_dir, 'p')
    return l:cache_dir . '/wolfram-symbols-' . s:WolframSymbolsCacheKey(a:paths) . '.txt'
endfunction

function! s:WolframPathQueryCode() abort
    return join([
        \ 'userInit = FileNameJoin[{$UserBaseDirectory, "Kernel", "init.m"}]',
        \ 'If[FileExistsQ[userInit], Get[userInit]]',
        \ 'WriteString[$Output, "__WOLFRAM_PATH_BEGIN__\n"]',
        \ 'Scan[If[StringQ[#], WriteString[$Output, # <> "\n"]] &, $Path]',
        \ 'WriteString[$Output, "__WOLFRAM_PATH_END__\n"]',
        \ 'Exit[]',
        \ ], '; ')
endfunction

function! s:WolframPathStartsWith(path, prefix) abort
    return stridx(a:path, a:prefix) == 0
endfunction

function! s:WolframPathRelevant(path) abort
    let l:path = fnamemodify(a:path, ':p')
    let l:home = fnamemodify($HOME, ':p')

    if l:path ==# l:home
        return 0
    endif

    for l:pattern in get(g:, 'wolfram_definition_path_exclude_patterns', [])
        if l:path =~# l:pattern
            return 0
        endif
    endfor

    return 1
endfunction

function! s:WolframPathRank(path) abort
    let l:path = fnamemodify(a:path, ':p')
    let l:dev = fnamemodify($HOME . '/dev/', ':p')
    let l:soft = fnamemodify($HOME . '/soft/', ':p')
    let l:user_apps = fnamemodify($HOME . '/.Wolfram/Applications/', ':p')
    let l:user_autoload = fnamemodify($HOME . '/.Wolfram/Autoload/', ':p')
    let l:user_kernel = fnamemodify($HOME . '/.Wolfram/Kernel/', ':p')
    let l:xdg_apps = fnamemodify($HOME . '/.local/share/Wolfram/ApplicationData/Applications/', ':p')

    if s:WolframPathStartsWith(l:path, l:dev) || s:WolframPathStartsWith(l:path, l:soft)
        return 10
    endif
    if s:WolframPathStartsWith(l:path, l:user_apps) || s:WolframPathStartsWith(l:path, l:xdg_apps)
        return 20
    endif
    if s:WolframPathStartsWith(l:path, l:user_autoload)
        return 30
    endif
    if s:WolframPathStartsWith(l:path, l:user_kernel)
        return 40
    endif
    if l:path =~# '/AddOns/\%(Applications\|Packages\|Autoload\|ExtraPackages\)/'
        return 50
    endif
    if l:path =~# '/SystemFiles/\%(Kernel/Packages\|Autoload\)/'
        return 60
    endif
    return 90
endfunction

function! s:CompareWolframPaths(left, right) abort
    let l:left_rank = s:WolframPathRank(a:left)
    let l:right_rank = s:WolframPathRank(a:right)

    if l:left_rank == l:right_rank
        return a:left ==# a:right ? 0 : (a:left <# a:right ? -1 : 1)
    endif

    return l:left_rank < l:right_rank ? -1 : 1
endfunction

function! s:CurateWolframRuntimePaths(paths) abort
    let l:curated = []

    for l:path in a:paths
        let l:expanded = fnamemodify(expand(l:path), ':p')
        if isdirectory(l:expanded) && s:WolframPathRelevant(l:expanded) && index(l:curated, l:expanded) < 0
            call add(l:curated, l:expanded)
        endif
    endfor

    call sort(l:curated, function('s:CompareWolframPaths'))
    return l:curated
endfunction

function! s:BuildWolframRgCommand(pattern, paths, color_mode) abort
    let l:cmd = 'rg --column --line-number --no-heading --smart-case --color=' . a:color_mode . ' --glob "*.m" --glob "*.wl" ' . shellescape(a:pattern)

    for l:path in a:paths
        let l:cmd .= ' ' . shellescape(l:path)
    endfor

    return l:cmd
endfunction

function! s:BuildWolframSymbolRgCommand(paths) abort
    let l:pattern = '^\s*[A-Za-z$`][A-Za-z0-9$`]*(\s*::usage\s*=|\s*\[.*\]\s*(:=|=)|\s*(:=|=))'
    let l:cmd = 'rg --no-filename --no-heading --color=never --glob "*.m" --glob "*.wl" ' . shellescape(l:pattern)

    for l:path in a:paths
        let l:cmd .= ' ' . shellescape(l:path)
    endfor

    return l:cmd
endfunction

function! s:WolframExtractDefinitionSymbol(line) abort
    return matchstr(a:line, '^\s*\zs[A-Za-z$`][A-Za-z0-9$`]*\ze\%(\s*::usage\s*=\|\s*\[.\{-}\]\s*\%(:=\|=\)\|\s*\%(:=\|=\)\)')
endfunction

function! s:WolframAddCompletionSymbol(symbols, symbol) abort
    if empty(a:symbol)
        return
    endif

    let a:symbols[a:symbol] = 1

    if stridx(a:symbol, '`') >= 0
        let l:tail = substitute(a:symbol, '^.*`', '', '')
        if !empty(l:tail)
            let a:symbols[l:tail] = 1
        endif
    endif
endfunction

function! s:LoadWolframCompletionSymbols(lines) abort
    let l:symbols = {}

    for l:line in a:lines
        call s:WolframAddCompletionSymbol(l:symbols, trim(l:line))
    endfor

    return sort(keys(l:symbols))
endfunction

function! s:WolframSymbolsCacheKey(paths) abort
    let l:hash = 5381

    for l:char in split(join(map(copy(a:paths), 'fnamemodify(v:val, ":p")'), "\n"), '\zs')
        let l:hash = (l:hash * 33 + char2nr(l:char)) % 2147483647
    endfor

    return printf('%08x', l:hash)
endfunction

function! s:WolframRuntimePaths() abort
    let l:paths = []
    let l:raw_paths = []
    let l:start = -1
    let l:end = -1
    let l:code = s:WolframPathQueryCode()
    let l:cmd = ''
    let l:cache_file = s:WolframRuntimePathsCacheFile()

    if exists('s:wolfram_runtime_paths')
        return copy(s:wolfram_runtime_paths)
    endif

    if filereadable(l:cache_file)
        let l:paths = s:CurateWolframRuntimePaths(readfile(l:cache_file))
        call writefile(l:paths, l:cache_file)
        let s:wolfram_runtime_paths = l:paths
        return copy(s:wolfram_runtime_paths)
    endif

    if !get(g:, 'wolfram_definition_query_runtime_path', 1)
        return []
    endif

    if executable('WolframKernel')
        let l:cmd = 'WolframKernel -noprompt -nopaclet -nostartuppaclets -noicon -run ' . shellescape(l:code)
    elseif executable('wolfram')
        let l:cmd = 'wolfram -noprompt -nopaclet -nostartuppaclets -noicon -run ' . shellescape(l:code)
    elseif executable('wolframscript')
        let l:cmd = 'wolframscript -code ' . shellescape(l:code)
    elseif executable('math')
        let l:cmd = 'math -noprompt -run ' . shellescape(l:code)
    else
        let s:wolfram_runtime_paths = []
        return []
    endif

    let l:output = systemlist(l:cmd)
    if v:shell_error != 0
        let s:wolfram_runtime_paths = []
        return []
    endif

    let l:start = index(l:output, '__WOLFRAM_PATH_BEGIN__')
    let l:end = index(l:output, '__WOLFRAM_PATH_END__')
    if l:start >= 0 && l:end > l:start
        let l:raw_paths = l:output[l:start + 1 : l:end - 1]
    endif

    let l:paths = s:CurateWolframRuntimePaths(l:raw_paths)

    call writefile(l:paths, l:cache_file)
    let s:wolfram_runtime_paths = l:paths
    return copy(s:wolfram_runtime_paths)
endfunction

function! s:WolframSearchPaths() abort
    let l:paths = []
    let l:project_root = finddir('.git', expand('%:p:h') . ';')

    if !empty(l:project_root)
        call add(l:paths, fnamemodify(l:project_root, ':h'))
    elseif expand('%:p:h') !=# ''
        call add(l:paths, expand('%:p:h'))
    endif

    for l:path in s:WolframRuntimePaths()
        if index(l:paths, l:path) < 0
            call add(l:paths, l:path)
        endif
    endfor

    for l:path in get(g:, 'wolfram_definition_search_paths', [])
        let l:expanded = expand(l:path)
        if isdirectory(l:expanded) && index(l:paths, l:expanded) < 0
            call add(l:paths, l:expanded)
        endif
    endfor

    return l:paths
endfunction

function! s:BuildWolframCompletionSymbols(paths) abort
    if empty(a:paths) || !executable('rg')
        return []
    endif

    let l:lines = systemlist(s:BuildWolframSymbolRgCommand(a:paths))
    if v:shell_error != 0
        return []
    endif

    let l:symbols = {}
    for l:line in l:lines
        call s:WolframAddCompletionSymbol(l:symbols, s:WolframExtractDefinitionSymbol(l:line))
    endfor

    return sort(keys(l:symbols))
endfunction

function! s:WolframCompletionSymbols() abort
    let l:paths = s:WolframSearchPaths()
    let l:cache_key = s:WolframSymbolsCacheKey(l:paths)
    let l:cache_file = s:WolframSymbolsCacheFile(l:paths)

    if !exists('s:wolfram_completion_symbols')
        let s:wolfram_completion_symbols = {}
    endif

    if has_key(s:wolfram_completion_symbols, l:cache_key)
        return copy(s:wolfram_completion_symbols[l:cache_key])
    endif

    if filereadable(l:cache_file)
        let s:wolfram_completion_symbols[l:cache_key] = s:LoadWolframCompletionSymbols(readfile(l:cache_file))
        return copy(s:wolfram_completion_symbols[l:cache_key])
    endif

    let s:wolfram_completion_symbols[l:cache_key] = s:BuildWolframCompletionSymbols(l:paths)
    if !empty(s:wolfram_completion_symbols[l:cache_key])
        call writefile(s:wolfram_completion_symbols[l:cache_key], l:cache_file)
    endif

    return copy(s:wolfram_completion_symbols[l:cache_key])
endfunction

function! s:ClearWolframCompletionSymbols() abort
    let l:cache_root = expand($XDG_CACHE_HOME !=# '' ? $XDG_CACHE_HOME : '~/.cache')
    let l:cache_dir = l:cache_root . '/vim'

    unlet! s:wolfram_completion_symbols
    for l:cache_file in glob(l:cache_dir . '/wolfram-symbols-*.txt', 0, 1)
        call delete(l:cache_file)
    endfor
endfunction

function! s:WolframRefreshCompletionSymbols() abort
    call s:ClearWolframCompletionSymbols()

    let l:symbols = s:WolframCompletionSymbols()
    echo 'Refreshed Wolfram symbol cache (' . len(l:symbols) . ' entries)'
endfunction

function! s:WolframAsyncompleteCompletor(opt, ctx) abort
    let l:symbols = s:WolframCompletionSymbols()
    let l:kw = matchstr(a:ctx['typed'], '[$[:alnum:]`]\+$')
    let l:kwlen = len(l:kw)

    if empty(l:symbols) || l:kwlen < get(a:opt, 'min_chars', 0)
        return
    endif

    let l:startcol = a:ctx['col'] - l:kwlen
    let l:matches = []

    for l:symbol in l:symbols
        if stridx(l:symbol, l:kw) == 0
            call add(l:matches, {
                \ 'word': l:symbol,
                \ 'dup': 1,
                \ 'menu': '[wolfram]',
                \ })
        endif
    endfor

    call asyncomplete#complete(a:opt['name'], a:ctx, l:startcol, l:matches)
endfunction

function! s:WolframRgLineToLocation(line) abort
    let l:clean = substitute(a:line, '\e\[[0-9;]*m', '', 'g')
    let l:match = matchlist(l:clean, '^\(.\{-}\):\(\d\+\):\(\d\+\):')

    if empty(l:match)
        return {}
    endif

    return {
        \ 'filename': l:match[1],
        \ 'lnum': str2nr(l:match[2]),
        \ 'col': str2nr(l:match[3]),
        \ }
endfunction

function! s:OpenWolframLocation(location) abort
    if empty(a:location)
        return
    endif

    execute 'edit ' . fnameescape(a:location.filename)
    execute a:location.lnum
    call cursor(a:location.lnum, a:location.col)
    normal! zvzz
endfunction

function! s:WolframDefinitionSink(lines) abort
    if empty(a:lines)
        return
    endif

    call s:OpenWolframLocation(s:WolframRgLineToLocation(a:lines[0]))
endfunction

function! s:WolframDefinitionSpec(command) abort
    return fzf#vim#with_preview({
        \ 'source': a:command,
        \ 'sink*': function('s:WolframDefinitionSink'),
        \ 'options': [
        \   '--ansi',
        \   '--prompt', 'WolframDef> ',
        \   '--delimiter', ':',
        \   '--select-1',
        \   '--exit-0',
        \ ],
        \ })
endfunction

function! s:WolframRefreshPaths() abort
    let l:cache_file = s:WolframRuntimePathsCacheFile()

    unlet! s:wolfram_runtime_paths
    if filereadable(l:cache_file)
        call delete(l:cache_file)
    endif
    call s:ClearWolframCompletionSymbols()

    let l:paths = s:WolframRuntimePaths()
    echo 'Refreshed Wolfram $Path cache (' . len(l:paths) . ' entries) and cleared symbol cache'
endfunction

function! s:WolframGotoDefinition() abort
    let l:symbol = expand('<cword>')
    let l:paths = s:WolframSearchPaths()
    let l:symbol_pattern = ''
    let l:pattern = ''
    let l:cmd = ''

    if empty(l:symbol)
        echoerr 'No Wolfram symbol under cursor'
        return
    endif

    if empty(l:paths)
        echoerr 'No Wolfram definition search paths are configured'
        return
    endif

    let l:symbol_pattern = escape(l:symbol, '\.^$~[]*+?()|{}')
    let l:pattern = '^\s*' . l:symbol_pattern . '(\s*::usage\s*=|\s*\[.*\]\s*(:=|=)|\s*(:=|=))'

    if exists('g:loaded_fzf') && exists('g:loaded_fzf_vim')
        let l:cmd = s:BuildWolframRgCommand(l:pattern, l:paths, 'always')
        call fzf#run(fzf#wrap('wolfram-definitions', s:WolframDefinitionSpec(l:cmd)))
        return
    endif

    let l:cmd = s:BuildWolframRgCommand(l:pattern, l:paths, 'never')
    let l:matches = systemlist(l:cmd)

    if v:shell_error != 0 || empty(l:matches)
        echo 'No Wolfram definition found for ' . l:symbol
        return
    endif

    call setqflist([], 'r', {
        \ 'title': 'Wolfram definitions for ' . l:symbol,
        \ 'lines': l:matches,
        \ 'efm': '%f:%l:%c:%m',
        \ })

    if len(l:matches) == 1
        cfirst
    else
        copen
    endif
endfunction

function! DotfilesWolframRegisterAsyncompleteSource() abort
    call asyncomplete#register_source({
        \ 'name': 'wolfram',
        \ 'allowlist': ['mma'],
        \ 'completor': function('s:WolframAsyncompleteCompletor'),
        \ 'min_chars': 2,
        \ 'refresh_pattern': '[$[:alnum:]`]\+$',
        \ })
endfunction

command! WolframGotoDefinition call s:WolframGotoDefinition()
command! WolframRefreshPaths call s:WolframRefreshPaths()
command! WolframRefreshSymbols call s:WolframRefreshCompletionSymbols()
