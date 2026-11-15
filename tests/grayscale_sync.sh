#!/usr/bin/env bash
set -Eeuo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
test_dir=$(mktemp -d)
trap 'rm -rf -- "$test_dir"' EXIT

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

export GRAYSCALE_TEST_ROOT="$test_dir"
export GRAYSCALE_APPEARANCE="$repo_dir/vim/config/appearance.vim"
export GRAYSCALE_TEST_COLOR='0,1,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,1'
export GRAYSCALE_TEST_GRAY='913110047,0,3071760610,0,310096639,0,913110047,0,3071760610,0,310096639,0,913110047,0,3071760610,0,310096639,0'
custom_matrix='0,1,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,2'
mkdir -p "$test_dir/bin" "$test_dir/scripts" "$test_dir/runtime/colors"
cp "$repo_dir/scripts/toggle-monitor-grayscale" "$repo_dir/scripts/test-monitor-grayscale-ctm" "$test_dir/scripts/"
toggle="$test_dir/scripts/toggle-monitor-grayscale"
trial="$test_dir/scripts/test-monitor-grayscale-ctm"

# Every xrandr call uses fixtures. No check can change the real display or signal
# a compositor, including when Vim invokes the actual repository entry point.
cat > "$test_dir/bin/xrandr" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
if [[ $# == 1 && $1 == --props ]]; then
    [[ ${GRAYSCALE_TEST_QUERY_FAIL:-0} == 0 ]] || exit 9
    printf 'Screen 0: current 3440 x 2640\n'
    for output in eDP-1 HDMI-1; do
        printf '%s connected 1920x1200+0+0 (normal)\n' "$output"
        matrix=$(cat "$GRAYSCALE_TEST_ROOT/$output")
        [[ $matrix != unsupported ]] || continue
        IFS=, read -r -a words <<< "$matrix"
        printf '\tCTM:'
        for i in "${!words[@]}"; do
            if (( i == 16 )); then printf '\n\t\t'; fi
            # xrandr prints 32-bit integers as signed values on this system.
            word=${words[$i]}
            if (( word >= 2147483648 )); then word=$(( word - 4294967296 )); fi
            printf ' %s' "$word"
        done
        printf '\n\tCONNECTOR_ID: 507\n   1920x1200 60.00*+\n'
    done
    printf 'DP-1 disconnected (normal)\nDP-2 connected (normal)\n'
    exit 0
fi
if [[ $# != 5 || $1 != --output || $3 != --set || $4 != CTM ]]; then
    printf 'Unexpected xrandr call: %s\n' "$*" >&2
    exit 2
fi
printf '%s %s\n' "$2" "$5" >> "$GRAYSCALE_TEST_ROOT/mutations"
if [[ ${GRAYSCALE_TEST_FAIL_OUTPUT:-} == "$2" && $5 == "$GRAYSCALE_TEST_GRAY" ]]; then
    printf 'Simulated CTM apply failure\n' >&2
    exit 9
fi
printf '%s\n' "$5" > "$GRAYSCALE_TEST_ROOT/$2"
EOF
cat > "$test_dir/bin/forbid" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
printf '%s\n' "$0 $*" >> "$GRAYSCALE_TEST_ROOT/forbidden"
exit 99
EOF
chmod +x "$test_dir/bin/xrandr" "$test_dir/bin/forbid"
for tool in picom pkill pgrep nvidia-settings ddcutil; do
    ln -s forbid "$test_dir/bin/$tool"
done
export PATH="$test_dir/bin:$PATH"
export DISPLAY=:grayscale-test

set_matrices() {
    printf '%s\n' "$1" > "$test_dir/eDP-1"
    printf '%s\n' "$2" > "$test_dir/HDMI-1"
}
expect_status() {
    local expected=$1 actual
    set_matrices "$2" "${3:-$2}"
    actual=$("$toggle" --status) || fail 'status query failed'
    [[ $actual == "$expected" ]] || fail "expected $expected, got $actual"
}

expect_status color "$GRAYSCALE_TEST_COLOR"
expect_status grayscale "$GRAYSCALE_TEST_GRAY"
expect_status color "$GRAYSCALE_TEST_GRAY" "$GRAYSCALE_TEST_COLOR"
expect_status color "$custom_matrix"
[[ $("$toggle" status) == $'eDP-1: custom\nHDMI-1: custom' ]] || fail 'detailed status failed'
set_matrices "$GRAYSCALE_TEST_GRAY" "$GRAYSCALE_TEST_COLOR"
[[ $("$toggle" --status eDP-1) == grayscale ]] || fail 'selected-output status failed'
if "$toggle" --status unknown > "$test_dir/invalid.out" 2>&1; then
    fail 'status query accepted an unknown output'
fi
if GRAYSCALE_TEST_QUERY_FAIL=1 "$toggle" --status > "$test_dir/invalid.out" 2>&1; then
    fail 'failed display query reported success'
fi
[[ ! -e "$test_dir/mutations" ]] || fail 'read-only status changed display state'

# Minimal themes isolate appearance behavior from installed plugins.
printf 'let g:colors_name = "molokai"\n' > "$test_dir/runtime/colors/molokai.vim"
printf 'let g:colors_name = "monochrome"\n' > "$test_dir/runtime/colors/monochrome.vim"
printf 'let g:colors_name = "remembered"\n' > "$test_dir/runtime/colors/remembered.vim"
set_matrices "$GRAYSCALE_TEST_GRAY" "$GRAYSCALE_TEST_GRAY"
cat > "$test_dir/sync.vim" <<'EOF'
set nocompatible
let &runtimepath = $GRAYSCALE_TEST_ROOT . '/runtime,' . &runtimepath
let g:test_theme_events = 0
autocmd ColorScheme * let g:test_theme_events += 1
execute 'source ' . fnameescape($GRAYSCALE_APPEARANCE)
Colorcall remembered
let g:test_theme_events_before_start = g:test_theme_events

function! CheckGreyscaleSync() abort
  " This runs after the actual VimEnter sync, not a simulated startup event.
  call assert_equal(1, g:greyscale_mode, 'startup detects grayscale')
  call assert_equal('remembered', g:greyscale_prev_scheme)
  call assert_equal('monochrome', g:colors_name, 'grayscale selects monochrome')
  call assert_true(g:test_theme_events > g:test_theme_events_before_start,
        \ 'automatic sync allows theme/plugin ColorScheme hooks')

  call writefile([$GRAYSCALE_TEST_COLOR], $GRAYSCALE_TEST_ROOT . '/eDP-1')
  doautocmd FocusGained
  call assert_equal(0, g:greyscale_mode, 'focus detects color')
  call assert_equal('remembered', g:colors_name, 'previous scheme restored')

  GreyscaleToggle
  doautocmd CursorHold
  call assert_equal(1, g:greyscale_mode, 'idle preserves manual override')
  call assert_equal('monochrome', g:colors_name, 'manual mode selects monochrome')
  GreyscaleSync
  call assert_equal(0, g:greyscale_mode, 'explicit sync follows display')

  call writefile([$GRAYSCALE_TEST_GRAY],
        \ $GRAYSCALE_TEST_ROOT . '/eDP-1')
  doautocmd CursorHoldI
  call assert_equal(1, g:greyscale_mode, 'insert idle detects grayscale')
  GreyscaleToggle
  doautocmd FocusGained
  call assert_equal(0, g:greyscale_mode, 'focus preserves manual override')

  call writefile([$GRAYSCALE_TEST_COLOR], $GRAYSCALE_TEST_ROOT . '/eDP-1')
  doautocmd VimResume
  call writefile([$GRAYSCALE_TEST_GRAY],
        \ $GRAYSCALE_TEST_ROOT . '/eDP-1')
  doautocmd FocusGained
  call assert_equal(1, g:greyscale_mode, 'display transition resumes sync')

  call writefile([$GRAYSCALE_TEST_COLOR], $GRAYSCALE_TEST_ROOT . '/eDP-1')
  doautocmd FocusGained
  call assert_equal(0, g:greyscale_mode, 'color CTM restores the theme')

  let g:greyscale_auto_sync = 0
  call writefile([$GRAYSCALE_TEST_GRAY],
        \ $GRAYSCALE_TEST_ROOT . '/eDP-1')
  doautocmd FocusGained
  call assert_equal(0, g:greyscale_mode, 'auto sync can be disabled')
  GreyscaleSync
  call assert_equal(1, g:greyscale_mode, 'explicit sync works with auto disabled')

  if !empty(v:errors)
    call writefile(v:errors, $GRAYSCALE_TEST_ROOT . '/vim-errors')
    cquit
  endif
  qall!
endfunction
autocmd VimEnter * call CheckGreyscaleSync()
EOF
if ! DISPLAY=:grayscale-test PICOM_GREYSCALE=0 vim -Nu NONE -i NONE -n -es \
    -V1"$test_dir/vim.log" -S "$test_dir/sync.vim" > "$test_dir/vim.out" 2>&1; then
    cat "$test_dir/vim.log" >&2
    if [[ -f "$test_dir/vim-errors" ]]; then cat "$test_dir/vim-errors" >&2; fi
    fail 'Vim startup and display transition checks failed'
fi

cat > "$test_dir/fallback.vim" <<'EOF'
set nocompatible
let &runtimepath = $GRAYSCALE_TEST_ROOT . '/runtime,' . &runtimepath
execute 'source ' . fnameescape($GRAYSCALE_APPEARANCE)
doautocmd VimEnter
call assert_equal(1, g:greyscale_mode, 'legacy environment hint still works')
call assert_equal('monochrome', g:colors_name, 'legacy hint selects monochrome')
if !empty(v:errors)
  call writefile(v:errors, $GRAYSCALE_TEST_ROOT . '/vim-errors')
  cquit
endif
qall!
EOF
if ! DISPLAY= PICOM_GREYSCALE=1 vim -Nu NONE -i NONE -n -es \
    -S "$test_dir/fallback.vim"; then
    if [[ -f "$test_dir/vim-errors" ]]; then cat "$test_dir/vim-errors" >&2; fi
    fail 'legacy environment hint failed'
fi
[[ ! -e "$test_dir/mutations" ]] || fail 'read-only sync changed display state'

# Main entry point toggles without arguments; the trial wrapper still defaults
# to a reversible trial. Apply failures roll back all attempted outputs.
set_matrices "$GRAYSCALE_TEST_COLOR" "$GRAYSCALE_TEST_COLOR"
"$toggle" > "$test_dir/toggle.out"
[[ $("$toggle" --status) == grayscale ]] || fail 'default CTM toggle failed'
"$toggle" > "$test_dir/toggle.out"
[[ $("$toggle" --status) == color ]] || fail 'default color toggle failed'
"$toggle" auto > "$test_dir/toggle.out"
[[ $("$toggle" --status) == grayscale ]] || fail 'legacy auto alias failed'
"$toggle" off > "$test_dir/toggle.out"
"$toggle" on eDP-1 > "$test_dir/toggle.out"
[[ $(cat "$test_dir/eDP-1") == "$GRAYSCALE_TEST_GRAY" ]] || fail 'selected output did not change'
[[ $(cat "$test_dir/HDMI-1") == "$GRAYSCALE_TEST_COLOR" ]] || fail 'unselected output changed'
"$toggle" toggle > "$test_dir/toggle.out"
[[ $("$toggle" --status) == grayscale ]] || fail 'mixed-output toggle failed'

for args in 'on unknown' 'on DP-2' 'on eDP-1 eDP-1' 'trial --seconds 0' 'on --seconds 1'; do
    : > "$test_dir/mutations"
    read -r -a argv <<< "$args"
    if "$toggle" "${argv[@]}" > "$test_dir/invalid.out" 2>&1; then
        fail "invalid arguments accepted: $args"
    fi
    [[ ! -s "$test_dir/mutations" ]] || fail 'invalid input changed a display'
done
set_matrices "$GRAYSCALE_TEST_COLOR" unsupported
if "$toggle" on > "$test_dir/invalid.out" 2>&1; then
    fail 'unsupported output accepted'
fi
[[ ! -s "$test_dir/mutations" ]] || fail 'unsupported output caused a partial apply'

set_matrices "$custom_matrix" "$GRAYSCALE_TEST_COLOR"
if GRAYSCALE_TEST_FAIL_OUTPUT=HDMI-1 "$toggle" on > "$test_dir/failed.out" 2>&1; then
    fail 'partial apply failure reported success'
fi
[[ $(cat "$test_dir/eDP-1") == "$custom_matrix" ]] || fail 'partial failure lost original CTM'
[[ $(cat "$test_dir/HDMI-1") == "$GRAYSCALE_TEST_COLOR" ]] || fail 'failed output was not restored'

"$trial" --seconds 1 > "$test_dir/trial.out"
[[ $(cat "$test_dir/eDP-1") == "$custom_matrix" ]] || fail 'trial lost original custom CTM'
[[ $(cat "$test_dir/HDMI-1") == "$GRAYSCALE_TEST_COLOR" ]] || fail 'trial did not restore color'
ln -s "$trial" "$test_dir/bin/ctm-trial-link"
"$test_dir/bin/ctm-trial-link" status > "$test_dir/trial.out"
grep -q '^eDP-1: custom$' "$test_dir/trial.out" || fail 'symlinked trial wrapper failed'
[[ ! -e "$test_dir/forbidden" ]] || fail 'CTM invoked a legacy backend'

# Send actual keyboard input through a controlling terminal. Sending SIGINT only
# to the script PID would miss terminal input bugs in the interactive trial.
python3 - <<'PY'
import errno
import os
from pathlib import Path
import pty
import select
import signal
import termios
import time

root = Path(os.environ['GRAYSCALE_TEST_ROOT'])
for entry, key, expected, raw_control in [
    ('toggle-monitor-grayscale', b'\x03', 130, False),
    ('test-monitor-grayscale-ctm', b'\x03', 130, False),
    ('toggle-monitor-grayscale', b'\x03', 130, True),
    ('toggle-monitor-grayscale', b'\r', 0, False),
    ('toggle-monitor-grayscale', b'q', 0, False),
]:
    originals = {name: (root / name).read_text() for name in ('eDP-1', 'HDMI-1')}
    command = [str(root / 'scripts' / entry)]
    if entry == 'toggle-monitor-grayscale':
        command.append('trial')
    command.extend(['--seconds', '30'])
    pid, terminal = pty.fork()
    if pid == 0:
        if raw_control:
            attrs = termios.tcgetattr(0)
            attrs[3] &= ~termios.ISIG
            termios.tcsetattr(0, termios.TCSANOW, attrs)
        os.execv(command[0], command)
    received = bytearray()
    finished = False
    def receive():
        ready, _, _ = select.select([terminal], [], [], 0.02)
        if ready:
            try:
                received.extend(os.read(terminal, 65536))
            except OSError as error:
                if error.errno != errno.EIO:
                    raise
    try:
        deadline = time.monotonic() + 3
        while b'Press Enter, q, or Ctrl+C' not in received and time.monotonic() < deadline:
            receive()
        assert b'Press Enter, q, or Ctrl+C' in received, received
        os.write(terminal, key)
        deadline = time.monotonic() + 3
        while time.monotonic() < deadline:
            done, status = os.waitpid(pid, os.WNOHANG)
            if done:
                finished = True
                break
            receive()
        assert finished, ('trial did not stop', entry, key, received)
        assert os.waitstatus_to_exitcode(status) == expected, (status, received)
        restored = termios.tcgetattr(terminal)[3]
        assert restored & termios.ECHO and restored & termios.ICANON, 'terminal input mode not restored'
        assert bool(restored & termios.ISIG) == (not raw_control), 'terminal signal mode not restored'
        for name, original in originals.items():
            assert (root / name).read_text() == original, ('CTM not restored', name)
    finally:
        if not finished:
            os.kill(pid, signal.SIGKILL)
            os.waitpid(pid, 0)
        os.close(terminal)
print('Terminal Ctrl+C, Enter, and q restoration checks passed.')
PY
printf 'CTM grayscale status, toggling, rollback, trial, and Vim sync checks passed.\n'
