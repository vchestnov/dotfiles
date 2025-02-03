" TODO add possibility for indent-based folding after expr
" see also
" https://www.vimfromscratch.com/articles/vim-folding
function! MathematicaFolds()
    let thisline = getline(v:lnum)

    if match(thisline, '^(\* ::Section') >= 0
        return ">1"
    elseif match(thisline, '^(\* ::Subsection') >= 0
        return ">2"
    elseif match(thisline, '^(\* ::Subsubsection') >= 0
        return ">3"
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

setlocal foldmethod=expr
setlocal foldexpr=MathematicaFolds()
setlocal foldtext=MathematicaFoldText()
