" Navigation only: no argument-list changes, file writes, or evaluated paths.
function! coderef#StartServer() abort
  if !has('clientserver') || !empty(v:servername)
    return
  endif
  try
    call remote_startserver('DOTFILES_TEX_' . getpid())
  catch
    " Headless sessions may have no display/server backend. :TexView reports it.
  endtry
endfunction

function! s:Buffer(file) abort
  let file = resolve(fnamemodify(a:file, ':p'))
  for buffer in getbufinfo({'bufloaded': 1})
    if getbufvar(buffer.bufnr, '&buftype') ==# '' && !empty(buffer.name)
          \ && resolve(fnamemodify(buffer.name, ':p')) ==# file
      return buffer.bufnr
    endif
  endfor
  return -1
endfunction

function! coderef#Score(file) abort
  let buffer = s:Buffer(a:file)
  if buffer < 0
    return 0
  endif
  return bufnr('%') == buffer ? 3 : empty(win_findbuf(buffer)) ? 1 : 2
endfunction

function! coderef#ClearHighlight() abort
  if exists('w:coderef_timer')
    call timer_stop(w:coderef_timer)
    unlet w:coderef_timer
  endif
  if exists('w:coderef_match')
    if index(map(getmatches(), 'v:val.id'), w:coderef_match) >= 0
      call matchdelete(w:coderef_match)
    endif
    unlet w:coderef_match
  endif
endfunction

function! s:ExpireHighlight(window, match, timer) abort
  if !empty(getwininfo(a:window))
        \ && getwinvar(a:window, 'coderef_timer', -1) == a:timer
        \ && index(map(getmatches(a:window), 'v:val.id'), a:match) >= 0
    call matchdelete(a:match, a:window)
  endif
endfunction

function! s:Open(request) abort
  let file = fnamemodify(a:request.file, ':p')
  if !filereadable(file)
    throw 'Code reference: file not found: ' . file
  endif
  let buffer = s:Buffer(file)
  let windows = buffer < 0 ? [] : win_findbuf(buffer)
  if buffer != bufnr('%')
    if !empty(windows)
      call win_gotoid(windows[0])
    elseif buffer >= 0
      execute 'hide buffer ' . buffer
    else
      execute 'hide edit ' . fnameescape(file)
    endif
  endif
  call coderef#ClearHighlight()
  let first = a:request.line
  let last = get(a:request, 'end', first)
  if first < 1 || last < first || last > line('$')
    throw 'Code reference: line range is outside the file; update the report'
  endif
  " This only runs on a requested jump; writes and insert-mode exits do not move.
  call cursor(first, max([1, get(a:request, 'column', 1)]))
  normal! zvzz
  if get(a:request, 'code', 0)
    let pattern = '\%>' . (first - 1) . 'l\%<' . (last + 1) . 'l.*'
    let w:coderef_match = matchadd('IncSearch', pattern)
    echo printf('Code reference: %s, lines %d–%d', fnamemodify(file, ':t'), first, last)
  endif
  if exists('*foreground')
    call foreground()
  endif
  " remote-expr can leave the viewport stale until the next keyboard event.
  " Paint the jump and match now, then give the visible highlight four seconds.
  redraw
  if get(a:request, 'code', 0)
    let w:coderef_timer = timer_start(4000,
          \ function('s:ExpireHighlight', [win_getid(), w:coderef_match]))
  endif
  return 1
endfunction

function! coderef#Open(request) abort
  try
    return json_encode({'ok': s:Open(a:request)})
  catch
    return json_encode({'ok': 0, 'error': v:exception})
  endtry
endfunction
