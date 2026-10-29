" Apply soft wrapping and screen-line navigation to status and inline diffs.
call Prose()

" A leading | would print the current line when Fugitive reloads the filetype.
let b:undo_ftplugin = get(b:, 'undo_ftplugin', 'exe') . ' | call NoProse()'
