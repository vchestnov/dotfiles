#!/usr/bin/env bash
set -Eeuo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT
vim_bin=$(command -v "${VIM_BIN:-vim}")

# Use a private X server; never replace the user's desktop clipboard.
for tool in xsel Xvfb xvfb-run; do
    command -v "$tool" >/dev/null || { printf 'Missing test dependency: %s\n' "$tool" >&2; exit 1; }
done
xsel_bin=$(command -v xsel)
mkdir -p "$tmp_dir/bin" "$tmp_dir/tmux-environment" "$tmp_dir/home with spaces"
cat > "$tmp_dir/bin/xsel" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
printf 'call\n' >> "$VIM_TEST_XSEL_CALLS"
if [[ "$DISPLAY" == :dotfiles-* ]]; then
    printf 'xsel: cannot open display %s\n' "$DISPLAY" >&2
    exit 1
fi
if [[ "${XAUTHORITY-}" == "$VIM_TEST_BAD_AUTHORITY" ]]; then
    printf 'Invalid MIT-MAGIC-COOKIE-1 key\n' >&2
    exit 1
fi
exec "$VIM_TEST_REAL_XSEL" "$@"
EOF
cat > "$tmp_dir/bin/tmux" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
printf 'call\n' >> "$VIM_TEST_TMUX_CALLS"
[[ $# == 2 && $1 == show-environment ]]
[[ -f "$VIM_TEST_TMUX_ENV/$2" ]] || exit 1
cat "$VIM_TEST_TMUX_ENV/$2"
EOF
chmod 0755 "$tmp_dir/bin/xsel" "$tmp_dir/bin/tmux"

cat > "$tmp_dir/guard.vim" <<'EOF'
let s:clipboard = &clipboard
let s:method = &clipmethod
if $VIM_TEST_OPT_OUT ==# '1'
    let g:dotfiles_remote_clipboard = 0
endif
execute 'source ' . fnameescape($VIM_TEST_CLIPBOARD)
call assert_equal(s:clipboard, &clipboard)
call assert_equal(s:method, &clipmethod)
if !empty(v:errors)
    call writefile(v:errors, $VIM_TEST_ERRORS)
    cquit 1
endif
qa!
EOF

for guard in local headless opt-out; do
    connection=fixture display=:fixture opt_out=0
    case "$guard" in
        local) connection='' ;;
        headless) display='' ;;
        opt-out) opt_out=1 ;;
    esac
    env SSH_CONNECTION="$connection" SSH_TTY='' DISPLAY="$display" VIM_TEST_OPT_OUT="$opt_out" \
        VIM_TEST_CLIPBOARD="$repo_dir/vim/config/clipboard.vim" VIM_TEST_ERRORS="$tmp_dir/errors" \
        "$vim_bin" -Nu NONE -n -i NONE -X -es -S "$tmp_dir/guard.vim"
done

cat > "$tmp_dir/vimrc" <<'EOF'
set nocompatible
let &clipboard = 'unnamedplus,exclude:cons\|linux'
execute 'source ' . fnameescape($VIM_TEST_CLIPBOARD)
EOF

cat > "$tmp_dir/check.vim" <<'EOF'
" Exercise the documented reload for Vim processes opened before an update.
unlet g:dotfiles_clipboard_config_loaded
execute 'source ' . fnameescape($VIM_TEST_CLIPBOARD)
call assert_equal('dotfiles_xsel', v:clipmethod)
call assert_equal('unnamedplus,exclude:.*', &clipboard)
call assert_false(filereadable($VIM_TEST_XSEL_CALLS), 'clipboard helper ran during startup')
call assert_false(filereadable($VIM_TEST_TMUX_CALLS), 'tmux ran during startup')
let s:display = $DISPLAY
let s:authority = $XAUTHORITY
" A private default authority file lets us test an explicitly unset XAUTHORITY.
call writefile(readfile(s:authority, 'b'), $HOME . '/.Xauthority', 'b')
call writefile(['DISPLAY=' . s:display], $VIM_TEST_TMUX_ENV . '/DISPLAY')
call writefile(['XAUTHORITY=' . s:authority], $VIM_TEST_TMUX_ENV . '/XAUTHORITY')

" Characterwise multiline text goes to CLIPBOARD and retains its Vim type.
call setreg('+', ['alpha λ', 'beta'], 'v')
call assert_equal("alpha λ\nbeta", system('xsel --output --clipboard'))
call assert_equal(['alpha λ', 'beta'], getreg('+', 1, 1))
call assert_equal('v', getregtype('+'))

" Linewise text, including a blank line, goes to the PRIMARY selection.
call setreg('*', ['one', ''], 'V')
call assert_equal("one\n\n", system('xsel --output --primary'))
call assert_equal(['one', ''], getreg('*', 1, 1))
call assert_equal('V', getregtype('*'))

" Blockwise yanks retain their width when pasted back into this Vim.
call setreg('+', ['abc', 'def'], "\<C-v>3")
call assert_equal("abc\ndef", system('xsel --output --clipboard'))
call assert_equal(['abc', 'def'], getreg('+', 1, 1))
call assert_equal("\<C-v>3", getregtype('+'))

" Changes made by another application must replace the cached selection.
silent call system('xsel --input --clipboard', "external\ntext")
call assert_equal(['external', 'text'], getreg('+', 1, 1))
call assert_equal('v', getregtype('+'))
silent call system('xsel --input --primary', "external\n\n")
call assert_equal(['external', ''], getreg('*', 1, 1))
call assert_equal('V', getregtype('*'))
silent call system('xsel --input --clipboard', '')
call assert_equal('', getreg('+'))

" Unnamedplus must continue to make ordinary yanks reach the X clipboard.
call setline(1, 'ordinary yank')
normal! yy
call assert_equal("ordinary yank\n", system('xsel --output --clipboard'))
call assert_false(filereadable($VIM_TEST_TMUX_CALLS), 'working clipboard queried tmux')

" A surviving Vim recovers a stale display on copy, retrying the same text once.
let s:calls = len(readfile($VIM_TEST_XSEL_CALLS))
let $DISPLAY = ':dotfiles-stale'
call setreg('+', ['recovered λ', 'copy'], 'V')
call assert_equal(2, len(readfile($VIM_TEST_XSEL_CALLS)) - s:calls)
call assert_equal(s:display, $DISPLAY)
call assert_equal("recovered λ\ncopy\n", system('xsel --output --clipboard'))
call assert_equal('V', getregtype('+'))

" Paste also recovers, including a changed authority file with the same display.
let $XAUTHORITY = $VIM_TEST_BAD_AUTHORITY
let s:calls = len(readfile($VIM_TEST_XSEL_CALLS))
let s:paste = call(v:clipproviders['dotfiles_xsel'].paste['+'], ['+'])
call assert_equal(['V', ['recovered λ', 'copy']], s:paste)
call assert_equal(2, len(readfile($VIM_TEST_XSEL_CALLS)) - s:calls)
call assert_equal(s:authority, $XAUTHORITY)

" tmux's removal marker must clear an old authority override, not set it empty.
call writefile(['-XAUTHORITY'], $VIM_TEST_TMUX_ENV . '/XAUTHORITY')
let $XAUTHORITY = $VIM_TEST_BAD_AUTHORITY
call setreg('*', ['default authority'], 'v')
call assert_false(exists('$XAUTHORITY'))
call assert_equal('default authority', system('xsel --output --primary'))

" Do not switch a working display merely because another client attached.
call writefile(['DISPLAY=:dotfiles-unrelated'], $VIM_TEST_TMUX_ENV . '/DISPLAY')
let s:tmux_calls = len(readfile($VIM_TEST_TMUX_CALLS))
call setreg('+', ['still working'], 'v')
call assert_equal(s:display, $DISPLAY)
call assert_equal(s:tmux_calls, len(readfile($VIM_TEST_TMUX_CALLS)))

" Unreachable, unchanged, absent, or malformed tmux environments fail cleanly.
for s:case in ['unreachable', 'unchanged', 'no-display', 'no-authority', 'malformed', 'no-tmux']
    let $DISPLAY = ':dotfiles-stale'
    unlet $XAUTHORITY
    let $TMUX = s:case ==# 'no-tmux' ? '' : 'fixture'
    call writefile(['DISPLAY=' . (s:case ==# 'unchanged' ? $DISPLAY : ':dotfiles-unreachable')],
                \ $VIM_TEST_TMUX_ENV . '/DISPLAY')
    call writefile(['-XAUTHORITY'], $VIM_TEST_TMUX_ENV . '/XAUTHORITY')
    if s:case ==# 'no-display'
        call writefile(['-DISPLAY'], $VIM_TEST_TMUX_ENV . '/DISPLAY')
    elseif s:case ==# 'no-authority'
        call delete($VIM_TEST_TMUX_ENV . '/XAUTHORITY')
    elseif s:case ==# 'malformed'
        call writefile(['XAUTHORITY=unexpected', 'extra line'], $VIM_TEST_TMUX_ENV . '/XAUTHORITY')
    endif
    for s:operation in ['copy', 'paste']
        let s:before = len(readfile($VIM_TEST_XSEL_CALLS))
        try
            if s:operation ==# 'copy'
                call call(v:clipproviders['dotfiles_xsel'].copy['+'], ['+', 'v', ['failed copy']])
            else
                call call(v:clipproviders['dotfiles_xsel'].paste['+'], ['+'])
            endif
            call assert_report(s:case . ': ' . s:operation . ' unexpectedly succeeded')
        catch
            call assert_match('X clipboard ' . s:operation . ' failed (DISPLAY=:dotfiles-stale)', v:exception)
            call assert_match('xsel: cannot open display', v:exception)
        endtry
        call assert_equal(s:case ==# 'unreachable' ? 2 : 1,
                    \ len(readfile($VIM_TEST_XSEL_CALLS)) - s:before, s:case)
        call assert_equal(':dotfiles-stale', $DISPLAY, 'failed recovery changed DISPLAY')
        call assert_false(exists('$XAUTHORITY'), 'failed recovery changed XAUTHORITY')
    endfor
endfor

" Authentication failures retain the original xsel diagnostic, too.
let $DISPLAY = s:display
let $XAUTHORITY = $VIM_TEST_BAD_AUTHORITY
try
    call call(v:clipproviders['dotfiles_xsel'].copy['+'], ['+', 'v', ['failed auth']])
    call assert_report('authentication failure unexpectedly succeeded')
catch
    call assert_match('Invalid MIT-MAGIC-COOKIE-1 key', v:exception)
endtry

if !empty(v:errors)
    call writefile(v:errors, $VIM_TEST_ERRORS)
    cquit 1
endif
qa!
EOF

if ! xvfb-run -a -s '-screen 0 640x480x24 -nolisten tcp' \
    env PATH="$tmp_dir/bin:$PATH" HOME="$tmp_dir/home with spaces" \
    SSH_CONNECTION=fixture SSH_TTY=/dev/fixture TMUX=fixture \
    VIM_TEST_REAL_XSEL="$xsel_bin" VIM_TEST_XSEL_CALLS="$tmp_dir/xsel-calls" \
    VIM_TEST_BAD_AUTHORITY="$tmp_dir/bad authority" \
    VIM_TEST_TMUX_ENV="$tmp_dir/tmux-environment" VIM_TEST_TMUX_CALLS="$tmp_dir/tmux-calls" \
    VIM_TEST_CLIPBOARD="$repo_dir/vim/config/clipboard.vim" VIM_TEST_ERRORS="$tmp_dir/errors" \
    "$vim_bin" -N -u "$tmp_dir/vimrc" -n -i NONE -es \
    -V1"$tmp_dir/vim.log" -S "$tmp_dir/check.vim"; then
    if [[ -f "$tmp_dir/errors" ]]; then cat "$tmp_dir/errors" >&2; fi
    tail -n 25 "$tmp_dir/vim.log" >&2
    exit 1
fi

printf 'Vim X clipboard integration checks passed\n'
