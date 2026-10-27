" Forward and inverse search in Zathura. Compile with -synctex=1 first.
if exists('b:did_dotfiles_tex_synctex')
  finish
endif
let b:did_dotfiles_tex_synctex = 1

" Keep viewer jobs alive when switching or closing source buffers.
let s:view_jobs = get(s:, 'view_jobs', [])

function! s:ViewError(channel, message) abort
  echohl ErrorMsg
  echom 'TexView: ' . a:message
  echohl None
endfunction

function! s:HasSyncTex(pdf) abort
  let stem = fnamemodify(a:pdf, ':r')
  return filereadable(stem . '.synctex.gz') || filereadable(stem . '.synctex')
endfunction

function! s:FindProjectPdfs(source) abort
  if !executable('synctex')
    return []
  endif

  let directory = fnamemodify(a:source, ':h')
  let position = printf('%d:%d:%s', line('.'), col('.'), a:source)
  " Query the data without running a viewer configured in SYNCTEX_VIEWER.
  let command = 'SYNCTEX_VIEWER= synctex view -i ' . shellescape(position) . ' -o '
  while 1
    let matches = []
    for name in readdir(directory)
      let pdf = directory . '/' . name
      if name !~# '\.pdf$' || !filereadable(pdf) || !s:HasSyncTex(pdf)
        continue
      endif
      " A matching SyncTeX result confirms that this PDF contains the source.
      let output = system(command . shellescape(pdf))
      if v:shell_error == 0 && output =~# '\(^\|\n\)Page:\d\+'
        call add(matches, pdf)
      endif
    endfor
    if !empty(matches) || isdirectory(directory . '/.git') || filereadable(directory . '/.git')
      return matches
    endif
    let parent = fnamemodify(directory, ':h')
    if parent ==# directory
      return []
    endif
    let directory = parent
  endwhile
endfunction

function! s:InverseSearchCommand() abort
  if !has('clientserver')
    call s:ViewError(0, 'inverse search requires Vim with +clientserver support')
    return ''
  endif
  try
    if empty(v:servername)
      call remote_startserver('DOTFILES_TEX_' . getpid())
    endif
  catch
    call s:ViewError(0, 'could not enable inverse search: ' . v:exception)
    return ''
  endtry
  if empty(v:servername)
    call s:ViewError(0, 'could not enable inverse search; Vim needs a working display or socket server')
    return ''
  endif

  let command = [v:progpath]
  if has('socketserver') && v:servername =~# '^/'
    call extend(command, ['--clientserver', 'socket'])
  endif
  " Zathura parses arguments before substituting the source path and numbers.
  " :drop reuses an existing window or preserves changes in another buffer.
  call extend(command, ['--servername', v:servername, '--remote-silent',
        \ '+call cursor(%{line}, max([1, %{column}])) | execute "normal! zvzz"', '%{input}'])
  return join(map(command, 'shellescape(v:val)'), ' ')
endfunction

function! s:ZathuraBusCall(arguments) abort
  let command = ['busctl', '--user', '--json=short', '--timeout=2'] + a:arguments
  let output = system(join(map(command, 'shellescape(v:val)'), ' '))
  if v:shell_error != 0
    throw 'busctl: ' . trim(output)
  endif
  return json_decode(output)
endfunction

function! s:PairExistingViewers(pdf, inverse) abort
  if !executable('busctl')
    call s:ViewError(0, 'pairing an existing viewer needs busctl; close the PDF window and run :TexView again')
    return
  endif
  try
    let names = s:ZathuraBusCall(['call', 'org.freedesktop.DBus',
          \ '/org/freedesktop/DBus', 'org.freedesktop.DBus', 'ListNames']).data[0]
    for name in names
      if name !~# '^org\.pwmt\.zathura\.PID-'
        continue
      endif
      let document = s:ZathuraBusCall(['get-property', name,
            \ '/org/pwmt/zathura', 'org.pwmt.zathura', 'filename']).data
      if empty(document) || resolve(document) !=# resolve(a:pdf)
        continue
      endif
      let setting = 'set synctex-editor-command ' . shellescape(a:inverse)
      let result = s:ZathuraBusCall(['call', name, '/org/pwmt/zathura',
            \ 'org.pwmt.zathura', 'ExecuteCommand', 's', setting])
      if !result.data[0]
        throw 'Zathura rejected the inverse-search command'
      endif
    endfor
  catch
    call s:ViewError(0, 'could not pair an existing viewer: ' . v:exception
          \ . '; close the PDF window and run :TexView again')
  endtry
endfunction

function! s:TexView(...) abort
  if !executable('zathura')
    echoerr 'TexView: zathura is not on PATH'
    return
  endif
  if !exists('*job_start')
    echoerr 'TexView: this Vim needs +job support'
    return
  endif

  let source = expand('%:p')
  if empty(source)
    echoerr 'TexView: save the source file first'
    return
  endif

  " An explicit PDF is remembered for subsequent searches in this buffer.
  if a:0
    let b:tex_pdf = fnamemodify(expand(a:1), ':p')
  endif

  let root = source
  " Included files may point to their main document with % !TeX root = ...
  for text in getline(1, min([50, line('$')]))
    let hint = matchlist(text, '\c^\s*%\s*!\s*TeX\s\+root\s*=\s*\(.\{-}\)\s*$')
    if !empty(hint) && !empty(hint[1])
      let root = fnamemodify(source, ':h') . '/' . hint[1]
      if hint[1] =~# '^/'
        let root = hint[1]
      endif
      break
    endif
  endfor
  let pdf = get(b:, 'tex_pdf', fnamemodify(root, ':r') . '.pdf')
  if !filereadable(pdf) && root ==# source && !exists('b:tex_pdf')
    let matches = s:FindProjectPdfs(source)
    if len(matches) > 1
      echoerr 'TexView: multiple PDFs match this source; use :TexView path/to/main.pdf: '
            \ . join(matches, ', ')
      return
    elseif len(matches) == 1
      let pdf = matches[0]
    endif
  endif
  if !filereadable(pdf)
    echoerr 'TexView: PDF missing: ' . pdf . ' (compile first, or use :TexView path/to/main.pdf)'
    return
  endif
  if !s:HasSyncTex(pdf)
    echoerr 'TexView: SyncTeX data missing; recompile with -synctex=1'
    return
  endif

  " A list passes paths directly, including spaces and shell metacharacters.
  let command = ['zathura']
  let inverse = s:InverseSearchCommand()
  if !empty(inverse)
    call s:PairExistingViewers(pdf, inverse)
    call extend(command, ['--synctex-editor-command', inverse])
  endif
  call extend(command, ['--synctex-forward',
        \ printf('%d:%d:%s', line('.'), col('.'), source), pdf])
  call filter(s:view_jobs, 'job_status(v:val) ==# "run"')
  let job = job_start(command, {
        \ 'in_io': 'null',
        \ 'out_io': 'null',
        \ 'err_cb': function('s:ViewError'),
        \ 'stoponexit': '',
        \ })
  if job_status(job) ==# 'fail'
    echoerr 'TexView: could not start zathura'
    return
  endif
  call add(s:view_jobs, job)
endfunction

command! -buffer -nargs=? -complete=file TexView call <SID>TexView(<f-args>)
nnoremap <silent> <buffer> <leader>lv :TexView<CR>

let b:undo_ftplugin = get(b:, 'undo_ftplugin', '')
      \ . ' | silent! delcommand TexView | execute "silent! nunmap <buffer> <leader>lv"'
      \ . ' | unlet! b:did_dotfiles_tex_synctex b:tex_pdf'
