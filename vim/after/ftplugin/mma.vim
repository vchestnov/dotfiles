setlocal suffixes+=.nb,.mx
setlocal suffixesadd+=.wl,.m
setlocal expandtab
setlocal shiftwidth=4
setlocal softtabstop=4
setlocal tabstop=4

" TODO add possibility for indent-based folding after expr
" see also
" https://www.vimfromscratch.com/articles/vim-folding
function! MathematicaFolds()
    let thisline = getline(v:lnum)

    if match(thisline, '^(\* ::Chapter') >= 0
        return ">1"
    elseif match(thisline, '^(\* ::Section') >= 0
        return ">2"
    elseif match(thisline, '^(\* ::Subsection') >= 0
        return ">3"
    elseif match(thisline, '^(\* ::Subsubsection') >= 0
        return ">4"
    else
        return "="
    endif
endfunction

function! MathematicaFoldText()
    let foldsize = (v:foldend - v:foldstart)
    let line = substitute(getline(v:foldstart + 1), '(\*\|\*)', '', 'g')
    let offset = 6
    "let line = getline(v:foldstart + 1)
    return repeat("+", v:foldlevel) . repeat(" ", offset - len(foldsize) - v:foldlevel) . foldsize . ': ' . line
endfunction

" Resolve the helper through the real checkout when ~/.vim is a symlink.
let s:mathematica_formatter = fnamemodify(resolve(expand('<sfile>:p')), ':h:h:h:h')
    \ . '/scripts/lib/mathematica-format.py'

function! s:MathematicaClean() abort
    if !executable('python3') || !filereadable(s:mathematica_formatter)
        echoerr 'MathematicaCleanup needs python3 and scripts/lib/mathematica-format.py'
        return
    endif

    let l:view = winsaveview()
    try
        " Prepare the text without changing the buffer if the helper fails.
        let l:lines = []
        for l:line in getline(1, '$')
            if l:line =~# '^\s*(\*\s*::Input::.\{-}::\s*\*)\s*$'
                continue
            endif
            if l:line =~# '^\s*(\*\s*::'
                let l:line = substitute(l:line, '::Initialization', '', 'g')
            endif
            if l:line =~# '^\s*(\*[^:]'
                let l:line = substitute(l:line, '(\*\s*', '(* ', '')
                let l:line = substitute(l:line, '\s*\*)', ' *)', '')
            endif
            call add(l:lines, l:line)
        endfor
        let l:request = {'lines': l:lines, 'tabstop': 4, 'shiftwidth': 4}
        let l:command = join(map([exepath('python3'), s:mathematica_formatter], 'shellescape(v:val)'), ' ')
        let l:output = system(l:command, json_encode(l:request))
        if v:shell_error != 0
            throw 'formatter failed: ' . trim(l:output)
        endif
        let l:formatted = json_decode(l:output)
        if type(l:formatted) != v:t_list
            throw 'formatter returned invalid output'
        endif
        if empty(l:formatted)
            let l:formatted = ['']
        endif

        setlocal expandtab shiftwidth=4 softtabstop=4 tabstop=4
        call setline(1, l:formatted)
        if line('$') > len(l:formatted)
            undojoin
            call deletebufline('%', len(l:formatted) + 1, '$')
        endif
    catch
        echoerr 'MathematicaCleanup: ' . v:exception
    finally
        call winrestview(l:view)
    endtry
endfunction

setlocal foldmethod=expr
setlocal foldexpr=MathematicaFolds()
setlocal foldtext=MathematicaFoldText()

nnoremap <buffer> <leader>wd :WolframGotoDefinition<CR>
command! -buffer MathematicaClean call <SID>MathematicaClean()
command! -buffer MathematicaCleanup call <SID>MathematicaClean()
command! -buffer MmaClean call <SID>MathematicaClean()
command! -buffer MmaCleanup call <SID>MathematicaClean()
