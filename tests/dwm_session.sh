#!/usr/bin/env bash
set -Eeuo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
test_dir=$(mktemp -d)
trap 'rm -rf -- "$test_dir"' EXIT
mkdir -p "$test_dir/bin" "$test_dir/home"
export DWM_SESSION_TEST_DIR=$test_dir

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

# Stub all desktop commands, including the final exec: no real X session or
# background service is accessed. A temporary HOME avoids sourcing host config.
cat > "$test_dir/bin/stub" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
case ${0##*/} in
    monitor)
        printf 'monitor:%s\n' "$*" >> "$DWM_SESSION_TEST_DIR/events"
        exit "${DWM_SESSION_TEST_FAIL:-0}"
        ;;
    ssh-agent)
        printf 'start:%s\n' "$*" >> "$DWM_SESSION_TEST_DIR/events"
        ;;
esac
EOF
chmod +x "$test_dir/bin/stub"
for program in monitor ssh-agent xrdb xset setxkbmap xsetroot xss-lock slstatus; do
    ln -s stub "$test_dir/bin/$program"
done

run_session() {
    : > "$test_dir/events"
    env HOME="$test_dir/home" PATH="$test_dir/bin:/usr/bin:/bin" \
        sh "$repo_dir/config/suckless/dwm-session" > "$test_dir/output" 2>&1
}

printf '%s\n' monitor:arrange start:dwm > "$test_dir/expected"
run_session
cmp -s "$test_dir/expected" "$test_dir/events" || fail 'display arrangement did not run before dwm'

DWM_SESSION_TEST_FAIL=9 run_session
cmp -s "$test_dir/expected" "$test_dir/events" || fail 'arrangement failure prevented dwm startup'
rg -q 'could not arrange displays; continuing' "$test_dir/output" || fail 'arrangement failure was hidden'

mv "$test_dir/bin/monitor" "$test_dir/bin/monitor.disabled"
run_session
printf '%s\n' start:dwm > "$test_dir/expected"
cmp -s "$test_dir/expected" "$test_dir/events" || fail 'missing monitor helper prevented dwm startup'

printf 'dwm session checks passed\n'
