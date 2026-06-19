if exists('g:dotfiles_completion_asyncomplete_loaded')
    finish
endif
let g:dotfiles_completion_asyncomplete_loaded = 1

" asyncomplete is present in all buffers, but it does not pop up by itself.
" This keeps it available for LSP completion without competing with SuperTab.
let g:asyncomplete_enable_for_all = get(g:, 'asyncomplete_enable_for_all', 1)
let g:asyncomplete_auto_popup = get(g:, 'asyncomplete_auto_popup', 0)
let g:asyncomplete_auto_completeopt = get(g:, 'asyncomplete_auto_completeopt', 0)
let g:asyncomplete_matchfuzzy = get(g:, 'asyncomplete_matchfuzzy', 0)

function! s:AsyncompleteSourcePriority(source_name) abort
    return get(asyncomplete#get_source_info(a:source_name), 'priority', 0)
endfunction

function! s:CompareAsyncompleteSources(left, right) abort
    let l:left_priority = s:AsyncompleteSourcePriority(a:left)
    let l:right_priority = s:AsyncompleteSourcePriority(a:right)

    if l:left_priority == l:right_priority
        return a:left ==# a:right ? 0 : (a:left <# a:right ? -1 : 1)
    endif

    return l:left_priority > l:right_priority ? -1 : 1
endfunction

function! s:AsyncompleteFilterItems(source_name, matches, startcol, base) abort
    let l:source = asyncomplete#get_source_info(a:source_name)

    if has_key(l:source, 'filter')
        return call(l:source['filter'], [a:matches, a:startcol, a:base])
    endif

    let l:items = []
    let l:startcols = []

    if empty(a:base)
        let l:items = copy(a:matches['items'])
    elseif get(g:, 'asyncomplete_matchfuzzy', 0) && exists('*matchfuzzypos')
        let l:items = matchfuzzypos(a:matches['items'], a:base, {'key': 'word'})[0]
    else
        for l:item in a:matches['items']
            if stridx(get(l:item, 'word', ''), a:base) == 0
                call add(l:items, l:item)
            endif
        endfor
    endif

    let l:startcols = repeat([a:startcol], len(l:items))
    return [l:items, l:startcols]
endfunction

function! s:SortBySourcePriorityPreprocessor(options, matches) abort
    let l:items = []
    let l:startcols = []
    let l:sources = sort(keys(a:matches), function('s:CompareAsyncompleteSources'))

    for l:source_name in l:sources
        let l:matches = a:matches[l:source_name]
        let l:startcol = l:matches['startcol']
        let l:base = a:options['typed'][l:startcol - 1:]
        let l:result = s:AsyncompleteFilterItems(l:source_name, l:matches, l:startcol, l:base)

        let l:items += l:result[0]
        let l:startcols += l:result[1]
    endfor

    if empty(l:items)
        return
    endif

    let a:options['startcol'] = min(l:startcols)
    call asyncomplete#preprocess_complete(a:options, l:items)
endfunction

if empty(get(g:, 'asyncomplete_preprocessor', []))
    let g:asyncomplete_preprocessor = [function('s:SortBySourcePriorityPreprocessor')]
endif

" Explicit LSP/asyncomplete trigger.
imap <silent> <C-Space> <Plug>(asyncomplete_force_refresh)
if !has('nvim')
    imap <silent> <C-@> <Plug>(asyncomplete_force_refresh)
endif

augroup dotfiles_asyncomplete
    autocmd!
    if get(g:, 'dotfiles_wolfram_completion_enabled', 0)
        autocmd User asyncomplete_setup
            \ if exists('*DotfilesWolframRegisterAsyncompleteSource') |
            \     call DotfilesWolframRegisterAsyncompleteSource() |
            \ endif
    endif
augroup END
