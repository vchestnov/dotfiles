" Fugitive diff/log output uses git filetype regardless of the source file.
setlocal wrap linebreak

let b:undo_ftplugin = get(b:, 'undo_ftplugin', '') . ' | setlocal wrap< linebreak<'
