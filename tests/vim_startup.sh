#!/usr/bin/env bash
set -Eeuo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT
vim_bin=${VIM_BIN:-vim}

mkdir -p "$tmp_dir/bin" "$tmp_dir/runtime/colors"
printf "let g:colors_name = 'molokai'\n" > "$tmp_dir/runtime/colors/molokai.vim"
printf "let g:colors_name = 'monochrome'\n" > "$tmp_dir/runtime/colors/monochrome.vim"
cat > "$tmp_dir/bin/xrandr" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
[[ "$*" == --props ]]
printf 'query\n' >> "$VIM_TEST_QUERY_LOG"
cat <<'DISPLAY_STATUS'
HDMI-1 connected 1920x1080+0+0
    CTM: 0 1 0 0 0 0
         0 0 0 1 0 0
         0 0 0 0 0 1
DISPLAY_STATUS
EOF
chmod 0755 "$tmp_dir/bin/xrandr"

cat > "$tmp_dir/fixture.vim" <<'EOF'
let &runtimepath = $VIM_TEST_RUNTIME . ',' . &runtimepath
if !empty($VIM_TEST_OVERRIDE)
    let g:greyscale_auto_sync = str2nr($VIM_TEST_OVERRIDE)
endif
execute 'source ' . fnameescape($VIM_TEST_APPEARANCE)
call assert_equal(str2nr($VIM_TEST_EXPECT_AUTO), g:greyscale_auto_sync)
execute $VIM_TEST_EVENT
if !empty(v:errors)
    call writefile(v:errors, $VIM_TEST_ERRORS)
    cquit 1
endif
qa!
EOF

run_case() {
    local name=$1 connection=$2 terminal=$3 override=$4 event=$5 expected_auto=$6 expected_queries=$7
    local query_log="$tmp_dir/$name.queries" errors="$tmp_dir/$name.errors"
    : > "$query_log"
    PATH="$tmp_dir/bin:$PATH" \
    DISPLAY=:fixture SSH_CONNECTION="$connection" SSH_TTY="$terminal" PICOM_GREYSCALE='' \
    VIM_TEST_RUNTIME="$tmp_dir/runtime" \
    VIM_TEST_APPEARANCE="$repo_dir/vim/config/appearance.vim" \
    VIM_TEST_OVERRIDE="$override" VIM_TEST_EVENT="$event" VIM_TEST_EXPECT_AUTO="$expected_auto" \
    VIM_TEST_QUERY_LOG="$query_log" VIM_TEST_ERRORS="$errors" \
        "$vim_bin" -Nu NONE -n -i NONE -X -es -S "$tmp_dir/fixture.vim"
    if [[ "$(wc -l < "$query_log")" != "$expected_queries" ]]; then
        printf 'FAIL: %s made an unexpected number of display queries\n' "$name" >&2
        exit 1
    fi
}

run_case local '' '' '' 'doautocmd VimEnter' 1 1
run_case ssh-connection fixture '' '' 'doautocmd VimEnter' 0 0
run_case ssh-terminal '' /dev/fixture '' 'doautocmd VimEnter' 0 0
run_case remote-events fixture /dev/fixture '' 'doautocmd FocusGained | doautocmd CursorHold | doautocmd VimResume' 0 0
run_case remote-opt-in fixture /dev/fixture 1 'doautocmd VimEnter' 1 1
run_case local-opt-out '' '' 0 'doautocmd VimEnter' 0 0
run_case manual-sync fixture /dev/fixture '' 'GreyscaleSync' 0 1

printf 'Vim display-sync startup checks passed\n'
