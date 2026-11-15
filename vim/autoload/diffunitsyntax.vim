" Load the plugin's implementation behind this local compatibility wrapper.
let s:this_file = resolve(expand('<sfile>:p'))
let s:upstream = filter(
      \ globpath(&runtimepath, 'autoload/diffunitsyntax.vim', 0, 1),
      \ 'resolve(v:val) !=# s:this_file')
if empty(s:upstream)
    throw 'diffunitsyntax: upstream autoload file not found'
endif
execute 'source ' . fnameescape(s:upstream[0])
let s:Render = funcref('diffunitsyntax#DiffUnitSyntax')

function! diffunitsyntax#DiffUnitSyntax() abort
    " Version 3.3 can mistake its own old syntax for a base diff group on redraw.
    for group in getcompletion('diffunitsyntax', 'highlight')
        silent! execute 'syntax clear ' . group
    endfor
    call s:Render()
endfunction
