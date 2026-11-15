#!/usr/bin/env bash
set -Eeuo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
test_dir=$(mktemp -d)
trap 'rm -rf -- "$test_dir"' EXIT
export MONITOR_TEST_DIR=$test_dir
mkdir "$test_dir/bin"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

# Every query, mode change, and menu is simulated; never access the real display.
cat > "$test_dir/bin/xrandr" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
if [[ $# == 1 && $1 == --query ]]; then
    [[ ${MONITOR_TEST_QUERY_FAIL:-0} == 0 ]] || exit 9
    cat "$MONITOR_TEST_DIR/snapshot"
else
    # The laptop may be referenced by --above, but never targeted by --output.
    previous=''
    for argument in "$@"; do
        if [[ $previous == --output && ( $argument == eDP-1 || $argument == Panel-1 ) ]]; then
            printf 'Unexpected laptop configuration: %s\n' "$*" >&2
            exit 90
        fi
        previous=$argument
    done
    printf '%s\n' "$@" >> "$MONITOR_TEST_DIR/actions"
    [[ ${MONITOR_TEST_APPLY_FAIL:-0} == 0 ]] || exit 8
fi
EOF
cat > "$test_dir/bin/dmenu" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
cat > "$MONITOR_TEST_DIR/menu"
[[ ${MONITOR_TEST_MENU_EXIT:-0} == 0 ]] || exit "$MONITOR_TEST_MENU_EXIT"
printf '%s\n' "${MONITOR_TEST_CHOICE:-}"
EOF
chmod +x "$test_dir/bin/xrandr" "$test_dir/bin/dmenu"
export PATH="$test_dir/bin:$PATH" DISPLAY=:monitor-test
monitor="$repo_dir/scripts/monitor"

fixture() {
    : > "$test_dir/actions"
    cat > "$test_dir/snapshot" <<'EOF'
Screen 0: minimum 8 x 8, current 1920 x 1080, maximum 32767 x 32767
eDP-1 connected primary 1920x1080+0+0 (normal left inverted right x axis y axis) 309mm x 174mm
   1920x1080     60.00*+
   1280x720      60.00
EOF
    cat >> "$test_dir/snapshot"
}

expect_enable() {
    local output=$1 mode=$2
    printf '%s\n' --output "$output" --mode "$mode" --above eDP-1 > "$test_dir/expected"
    cmp -s "$test_dir/expected" "$test_dir/actions" || fail "wrong layout for $output/$mode"
}

expect_failure() {
    : > "$test_dir/actions"
    if "$monitor" "$@" > "$test_dir/output" 2>&1; then
        fail "unexpected success: $*"
    fi
    [[ ! -s $test_dir/actions ]] || fail "invalid request changed the layout: $*"
}

"$monitor" --help > "$test_dir/output"
fixture <<'EOF'
DP-3 disconnected (normal left inverted right x axis y axis)
HDMI-1 connected (normal left inverted right x axis y axis)
   1920x1080     60.00+
   1280x720      60.00
EOF
"$monitor" on > "$test_dir/output"
expect_enable HDMI-1 1920x1080
: > "$test_dir/actions"
"$monitor" toggle > "$test_dir/output"
expect_enable HDMI-1 1920x1080
: > "$test_dir/actions"
"$monitor" > "$test_dir/output"
rg -q '^eDP-1: connected, active 1920x1080' "$test_dir/output" || fail 'missing laptop status'
rg -q '^HDMI-1: connected, disabled; preferred 1920x1080$' "$test_dir/output" || fail 'missing disabled status'
rg -q '^DP-3: disconnected$' "$test_dir/output" || fail 'missing disconnected status'
[[ ! -s $test_dir/actions ]] || fail 'status changed the layout'
expect_failure on --mode 3440x1440
expect_failure on --output DP-3
expect_failure on --output unknown
expect_failure on --output eDP-1
expect_failure on --internal unknown
expect_failure on --mode
expect_failure off --output HDMI-1
expect_failure menu --mode 1920x1080
expect_failure toggle --mode 1920x1080
expect_failure toggle --output HDMI-1
expect_failure arrange --mode 1920x1080
expect_failure arrange --output HDMI-1
expect_failure status --dry-run
expect_failure on --surprise
expect_failure surprise
DISPLAY='' expect_failure on
MONITOR_TEST_QUERY_FAIL=1 expect_failure on

for output in DP-3 HDMI-1; do
    fixture <<EOF
$output connected 3440x1440+0+0 (normal left inverted right x axis y axis)
   1920x1080     60.00
   3440x1440     59.97*+
EOF
    "$monitor" on > "$test_dir/output"
    expect_enable "$output" 3440x1440
    : > "$test_dir/actions"
    "$monitor" toggle > "$test_dir/output"
    printf '%s\n' --output "$output" --off > "$test_dir/expected"
    cmp -s "$test_dir/expected" "$test_dir/actions" || fail "toggle did not disable active $output"
    : > "$test_dir/actions"
    "$monitor" toggle --dry-run > "$test_dir/output"
    [[ ! -s $test_dir/actions ]] || fail 'toggle dry run changed the layout'
    rg -q -- "--output $output --off$" "$test_dir/output" || fail 'toggle preview did not select off'
    : > "$test_dir/actions"
    "$monitor" on --mode 1920x1080 > "$test_dir/output"
    expect_enable "$output" 1920x1080
    : > "$test_dir/actions"
    "$monitor" on --dry-run > "$test_dir/output"
    [[ ! -s $test_dir/actions ]] || fail 'dry run changed the layout'
    rg -q "^xrandr .*--output $output --mode 3440x1440 --above eDP-1$" "$test_dir/output" \
        || fail 'dry run did not show intended layout'
done

# Unknown monitor sizes use the advertised preferred mode, then the first mode.
fixture <<'EOF'
HDMI-2 connected (normal left inverted right x axis y axis)
   3840x2160     60.00
   2560x1440     60.00+
EOF
"$monitor" on > "$test_dir/output"
expect_enable HDMI-2 2560x1440
fixture <<'EOF'
HDMI-2 connected (normal left inverted right x axis y axis)
   2560x1440     60.00
   1280x720      60.00
EOF
"$monitor" on > "$test_dir/output"
expect_enable HDMI-2 2560x1440
fixture <<'EOF'
HDMI-2 connected (normal left inverted right x axis y axis)
EOF
expect_failure on
fixture <<'EOF'
HDMI-1 disconnected (normal left inverted right x axis y axis)
EOF
expect_failure on
expect_failure toggle
"$monitor" off > "$test_dir/output"
printf '%s\n' --output HDMI-1 --off > "$test_dir/expected"
cmp -s "$test_dir/expected" "$test_dir/actions" || fail 'off did not handle an unplugged output'

fixture <<'EOF'
HDMI-1 disconnected 3440x1440+0+0 (normal left inverted right x axis y axis)
EOF
"$monitor" toggle > "$test_dir/output"
printf '%s\n' --output HDMI-1 --off > "$test_dir/expected"
cmp -s "$test_dir/expected" "$test_dir/actions" || fail 'toggle did not clean up an unplugged active output'

fixture <<'EOF'
DP-3 connected (normal left inverted right x axis y axis)
   3440x1440     59.97+
HDMI-1 connected (normal left inverted right x axis y axis)
   1920x1080     60.00+
EOF
MONITOR_TEST_CHOICE=HDMI-1 "$monitor" on > "$test_dir/output"
expect_enable HDMI-1 1920x1080
: > "$test_dir/actions"
MONITOR_TEST_CHOICE='Enable DP-3' "$monitor" menu > "$test_dir/output"
expect_enable DP-3 3440x1440
: > "$test_dir/actions"
"$monitor" on --output DP-3 > "$test_dir/output"
expect_enable DP-3 3440x1440
: > "$test_dir/actions"
MONITOR_TEST_CHOICE='Laptop only' "$monitor" menu > "$test_dir/output"
printf '%s\n' --output DP-3 --off --output HDMI-1 --off > "$test_dir/expected"
cmp -s "$test_dir/expected" "$test_dir/actions" || fail 'menu off did not disable all externals'
: > "$test_dir/actions"
"$monitor" off --dry-run > "$test_dir/output"
MONITOR_TEST_CHOICE=Status "$monitor" menu > "$test_dir/output"
MONITOR_TEST_MENU_EXIT=1 "$monitor" menu > "$test_dir/output"
MONITOR_TEST_MENU_EXIT=1 "$monitor" on > "$test_dir/output"
MONITOR_TEST_CHOICE='' "$monitor" menu > "$test_dir/output"
[[ ! -s $test_dir/actions ]] || fail 'status, cancellation, or dry run changed the layout'
MONITOR_TEST_CHOICE='Enable unknown' expect_failure menu
MONITOR_TEST_MENU_EXIT=2 expect_failure menu

# A mixed setup must turn everything off, without opening a selection menu.
fixture <<'EOF'
DP-3 connected (normal left inverted right x axis y axis)
   3440x1440     59.97+
HDMI-1 connected 1920x1080+0+0 (normal left inverted right x axis y axis)
   1920x1080     60.00*+
EOF
MONITOR_TEST_MENU_EXIT=2 "$monitor" toggle > "$test_dir/output"
printf '%s\n' --output DP-3 --off --output HDMI-1 --off > "$test_dir/expected"
cmp -s "$test_dir/expected" "$test_dir/actions" || fail 'toggle did not disable a mixed setup'

# An explicit internal output also supports nonstandard laptop connector names.
sed 's/eDP-1/Panel-1/g' "$test_dir/snapshot" > "$test_dir/renamed"
mv "$test_dir/renamed" "$test_dir/snapshot"
expect_failure on --output HDMI-1
"$monitor" on --internal Panel-1 --output HDMI-1 > "$test_dir/output"
printf '%s\n' --output HDMI-1 --mode 1920x1080 --above Panel-1 > "$test_dir/expected"
cmp -s "$test_dir/expected" "$test_dir/actions" || fail 'internal output override was ignored'

: > "$test_dir/actions"
if MONITOR_TEST_APPLY_FAIL=1 "$monitor" on --internal Panel-1 --output HDMI-1 \
    > "$test_dir/output" 2>&1; then
    fail 'xrandr apply failure was ignored'
fi
rg -q 'could not apply' "$test_dir/output" || fail 'xrandr failure was not explained'
if rg -q 'layout applied' "$test_dir/output"; then fail 'failed layout was reported as applied'; fi

# Neither a custom laptop mode/position nor its advertised modes are modified.
cat > "$test_dir/snapshot" <<'EOF'
eDP-1 connected primary 1280x720+37+1440 (normal left inverted right x axis y axis)
HDMI-1 connected 3440x1440+0+0 (normal left inverted right x axis y axis)
   3440x1440     59.97*+
EOF
: > "$test_dir/actions"
"$monitor" on > "$test_dir/output"
expect_enable HDMI-1 3440x1440
for action in off toggle menu; do
    : > "$test_dir/actions"
    MONITOR_TEST_CHOICE='Laptop only' "$monitor" "$action" > "$test_dir/output"
    printf '%s\n' --output HDMI-1 --off > "$test_dir/expected"
    cmp -s "$test_dir/expected" "$test_dir/actions" || fail "$action configured more than the external output"
done

# A disabled laptop is never implicitly enabled, even for relative positioning.
cat > "$test_dir/snapshot" <<'EOF'
eDP-1 connected (normal left inverted right x axis y axis)
   1920x1080     60.00+
HDMI-1 connected (normal left inverted right x axis y axis)
   3440x1440     59.97+
EOF
expect_failure on
expect_failure toggle
"$monitor" off > "$test_dir/output"
printf '%s\n' --output HDMI-1 --off > "$test_dir/expected"
cmp -s "$test_dir/expected" "$test_dir/actions" || fail 'off tried to enable the laptop'

# With only the laptop output present, off is a no-op, including in dry runs.
fixture < /dev/null
"$monitor" off > "$test_dir/output"
"$monitor" off --dry-run > "$test_dir/output"
[[ ! -s $test_dir/actions ]] || fail 'off changed a laptop-only setup'

# Login arrangement preserves active modes and leaves disabled outputs alone.
fixture <<'EOF'
HDMI-1 connected 1280x720+1920+0 (normal left inverted right x axis y axis)
   3440x1440     59.97+
   1280x720      60.00*
DP-3 connected (normal left inverted right x axis y axis)
   1920x1080     60.00+
EOF
MONITOR_TEST_MENU_EXIT=2 "$monitor" arrange > "$test_dir/output"
printf '%s\n' --output HDMI-1 --above eDP-1 > "$test_dir/expected"
cmp -s "$test_dir/expected" "$test_dir/actions" || fail 'arrange changed modes or activated a disabled output'
: > "$test_dir/actions"
"$monitor" arrange --dry-run > "$test_dir/output"
rg -q '^xrandr --output HDMI-1 --above eDP-1$' "$test_dir/output" || fail 'incorrect arrange preview'
[[ ! -s $test_dir/actions ]] || fail 'arrange preview changed the layout'

# Several active screens are stacked deterministically without a login menu.
fixture <<'EOF'
DP-3 connected 3440x1440+1920+0 (normal left inverted right x axis y axis)
   3440x1440     59.97*+
HDMI-1 connected 1920x1080+5360+0 (normal left inverted right x axis y axis)
   1920x1080     60.00*+
EOF
MONITOR_TEST_MENU_EXIT=2 "$monitor" arrange > "$test_dir/output"
printf '%s\n' --output DP-3 --above eDP-1 --output HDMI-1 --above DP-3 > "$test_dir/expected"
cmp -s "$test_dir/expected" "$test_dir/actions" || fail 'arrange did not stack active external outputs'
sed 's/eDP-1/Panel-1/g' "$test_dir/snapshot" > "$test_dir/renamed"
mv "$test_dir/renamed" "$test_dir/snapshot"
: > "$test_dir/actions"
"$monitor" arrange --internal Panel-1 > "$test_dir/output"
printf '%s\n' --output DP-3 --above Panel-1 --output HDMI-1 --above DP-3 > "$test_dir/expected"
cmp -s "$test_dir/expected" "$test_dir/actions" || fail 'arrange ignored the internal output override'

fixture <<'EOF'
DP-3 connected (normal left inverted right x axis y axis)
   3440x1440     59.97+
HDMI-1 disconnected 1920x1080+1920+0 (normal left inverted right x axis y axis)
EOF
"$monitor" arrange > "$test_dir/output"
[[ ! -s $test_dir/actions ]] || fail 'arrange changed disabled or disconnected outputs'
fixture < /dev/null
"$monitor" arrange > "$test_dir/output"
[[ ! -s $test_dir/actions ]] || fail 'arrange changed a laptop-only setup'

cat > "$test_dir/snapshot" <<'EOF'
eDP-1 connected (normal left inverted right x axis y axis)
   1920x1080     60.00+
HDMI-1 connected 3440x1440+0+0 (normal left inverted right x axis y axis)
   3440x1440     59.97*+
EOF
expect_failure arrange

printf 'Monitor helper checks passed\n'
