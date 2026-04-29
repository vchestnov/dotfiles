" FORM-specific commenting:
" - uses '*' as comment prefix
" - overrides gc to toggle comment markers linewise for FORM source

setlocal commentstring=*\ %s

function! s:CommentLineToggle(line) abort
  let l:line = getline(a:line)
  if l:line =~ '^\*'
    call setline(a:line, substitute(l:line, '^\*', '', ''))
  else
    call setline(a:line, '*' . l:line)
  endif
endfunction

function! s:CommentRange(start, end) abort
  for lnum in range(a:start, a:end)
    call s:CommentLineToggle(lnum)
  endfor
endfunction

function! s:CommentOpFunc(type) abort
  call s:CommentRange(line("'["), line("']"))
endfunction

nmap  <buffer> gc <Plug>(FormCommentOperator)
xmap  <buffer> gc :<C-u>call <SID>CommentRange(line("'<"), line("'>"))<CR>
omap  <buffer> gc :<C-u>set operatorfunc=<SID>CommentOpFunc<CR>g@
nnoremap <buffer> <silent> <Plug>(FormCommentOperator) :set operatorfunc=<SID>CommentOpFunc<CR>g@
