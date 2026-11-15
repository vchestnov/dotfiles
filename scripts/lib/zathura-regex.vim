" Batch Vim regexp matching; all input is JSON data, never Ex commands.
set encoding=utf-8 nomodeline magic noignorecase undolevels=-1
set iskeyword=@,48-57,_,192-255

function! s:Collect() abort
  let text = submatch(0)
  let byte = line2byte(line('.')) - 1 + col('.') - 1
  let start = strchars(strpart(s:page, 0, byte))
  " Vim can match the implicit newline at EOF; PDF text has no such character.
  let end = min([strchars(s:page), start + strchars(text)])
  if end > start
    call add(s:matches, [start, end])
  endif
  if len(s:matches) > 100000
    throw 'Too many matches on one page; narrow the expression'
  endif
  return text
endfunction

let s:output = {'matches': []}
try
  let s:input = json_decode(join(readfile(argv(0)), "\n"))
  " Compile even for empty documents so malformed expressions report an error.
  call matchstrpos('', s:input.pattern)
  for s:page in s:input.pages
    silent %delete _
    call setline(1, split(s:page, "\n", 1))
    call cursor(1, 1)
    let s:matches = []
    " A real buffer preserves Vim's line anchors and multiline regexp semantics.
    " The empty substitute pattern reads @/ as data; it is never an Ex command.
    let @/ = s:input.pattern
    silent keepjumps %s//\=s:Collect()/ge
    call add(s:output.matches, s:matches)
  endfor
catch
  let s:output = {'error': v:exception}
endtry
call writefile([json_encode(s:output)], argv(1))
qa!
