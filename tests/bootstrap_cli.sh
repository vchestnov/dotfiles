#!/usr/bin/env bash
set -Eeuo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
bootstrap="$repo_dir/bootstrap.sh"
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

run_plan() {
    local name=$1
    shift
    "$bootstrap" "$@" --dry-run > "$tmp_dir/$name.out"
}

for profile in desktop server nothing test; do
    run_plan "$profile" "$profile"
    grep -q "Profile: $profile" "$tmp_dir/$profile.out" || fail "$profile profile missing"
done

grep -q '^  go[[:space:]]' "$tmp_dir/test.out" || fail 'test profile must include go'
grep -q '^  git-lfs[[:space:]]' "$tmp_dir/test.out" || fail 'test profile must include git-lfs'
grep -q '(no components selected)' "$tmp_dir/nothing.out" || fail 'nothing profile must be empty'

if grep -Eq '^  (system-base|fonts|desktop-tools|dwm|tex|gpg|macaulay2)[[:space:]]' "$tmp_dir/server.out"; then
    fail 'server profile contains a sudo-only component'
fi

if grep -Eq '^  (krita|messengers|media|system-upgrade|remove-nautilus|reset-user-dirs|wipe-suckless)[[:space:]]' "$tmp_dir/desktop.out"; then
    fail 'desktop profile contains an optional or risky component'
fi

run_plan targeted nothing --only core,go --enable media --skip core
grep -q '^  go[[:space:]]' "$tmp_dir/targeted.out" || fail 'targeted plan lost go'
grep -q '^  media[[:space:]]' "$tmp_dir/targeted.out" || fail 'targeted plan lost media'
grep -q '^  core[[:space:]]' "$tmp_dir/targeted.out" && fail 'skip did not remove core'

if "$bootstrap" nothing --enable remove-nautilus --yes > "$tmp_dir/risky.out" 2>&1; then
    fail 'risky noninteractive plan ran without --allow-risky'
fi
grep -q 'require --allow-risky' "$tmp_dir/risky.out" || fail 'risky refusal was unclear'

if "$bootstrap" nothing --only does-not-exist --dry-run > "$tmp_dir/unknown.out" 2>&1; then
    fail 'unknown component was accepted'
fi

mkdir "$tmp_dir/empty-home"
HOME="$tmp_dir/empty-home" \
XDG_CONFIG_HOME="$tmp_dir/empty-home/config" \
XDG_DATA_HOME="$tmp_dir/empty-home/data" \
XDG_CACHE_HOME="$tmp_dir/empty-home/cache" \
XDG_STATE_HOME="$tmp_dir/empty-home/state" \
    "$bootstrap" desktop --dry-run > "$tmp_dir/no-write.out"
if find "$tmp_dir/empty-home" -mindepth 1 -print -quit | grep -q .; then
    fail 'dry-run wrote to HOME or an XDG directory'
fi

mkdir "$tmp_dir/empty-run"
HOME="$tmp_dir/empty-run" \
XDG_CONFIG_HOME="$tmp_dir/empty-run/config" \
XDG_DATA_HOME="$tmp_dir/empty-run/data" \
XDG_CACHE_HOME="$tmp_dir/empty-run/cache" \
XDG_STATE_HOME="$tmp_dir/empty-run/state" \
    "$bootstrap" nothing --yes > "$tmp_dir/empty-run.out"
grep -q '^status=success$' "$tmp_dir/empty-run/state/bootstrap/last-run" \
    || fail 'successful run status was not recorded under XDG_STATE_HOME'
grep -q '^selected_components=$' "$tmp_dir/empty-run/state/bootstrap/last-run" \
    || fail 'empty run reported components that were not selected'

printf 'bootstrap CLI checks passed\n'
