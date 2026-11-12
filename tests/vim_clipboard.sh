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
mkdir "$tmp_dir/bin"
cat > "$tmp_dir/bin/xsel" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
printf 'call\n' >> "$VIM_TEST_XSEL_CALLS"
exec "$VIM_TEST_REAL_XSEL" "$@"
EOF
chmod 0755 "$tmp_dir/bin/xsel"

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
call assert_equal('dotfiles_xsel', v:clipmethod)
call assert_equal('unnamedplus,exclude:.*', &clipboard)
call assert_false(filereadable($VIM_TEST_XSEL_CALLS), 'clipboard helper ran during startup')

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

if !empty(v:errors)
    call writefile(v:errors, $VIM_TEST_ERRORS)
    cquit 1
endif
qa!
EOF

if ! xvfb-run -a -s '-screen 0 640x480x24 -nolisten tcp' \
    env PATH="$tmp_dir/bin:$PATH" SSH_CONNECTION=fixture SSH_TTY=/dev/fixture \
    VIM_TEST_REAL_XSEL="$xsel_bin" VIM_TEST_XSEL_CALLS="$tmp_dir/xsel-calls" \
    VIM_TEST_CLIPBOARD="$repo_dir/vim/config/clipboard.vim" VIM_TEST_ERRORS="$tmp_dir/errors" \
    "$vim_bin" -N -u "$tmp_dir/vimrc" -n -i NONE -es \
    -V1"$tmp_dir/vim.log" -S "$tmp_dir/check.vim"; then
    if [[ -f "$tmp_dir/errors" ]]; then cat "$tmp_dir/errors" >&2; fi
    tail -n 25 "$tmp_dir/vim.log" >&2
    exit 1
fi

printf 'Vim X clipboard integration checks passed\n'
