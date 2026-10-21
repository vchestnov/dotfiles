#!/usr/bin/env bash
set -Eeuo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$repo_dir/scripts/lib/suckless.sh"
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT
SRC_DIR="$tmp_dir/src"
BUILD_DIR="$tmp_dir/build"
export SRC_DIR BUILD_DIR
export SUCKLESS_LOCK_FILE="$tmp_dir/suckless.lock"

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

mkdir -p "$SRC_DIR/dwm"
git -C "$SRC_DIR/dwm" init -q --initial-branch=main
git -C "$SRC_DIR/dwm" config user.name 'Workflow fixture'
git -C "$SRC_DIR/dwm" config user.email 'fixture@example.invalid'
printf 'recorded source\n' > "$SRC_DIR/dwm/source.txt"
printf '/built\n' > "$SRC_DIR/dwm/.gitignore"
printf 'all: built\nbuilt: source.txt\n\tcp source.txt built\n' > "$SRC_DIR/dwm/Makefile"
git -C "$SRC_DIR/dwm" add source.txt Makefile .gitignore
git -C "$SRC_DIR/dwm" commit -qm 'fixture baseline'
pinned=$(git -C "$SRC_DIR/dwm" rev-parse HEAD)
printf 'dwm %s -\n' "$pinned" > "$SUCKLESS_LOCK_FILE"

# Building a pin must ignore working-tree edits and retain the branch/remotes.
git -C "$SRC_DIR/dwm" remote add upstream https://git.suckless.org/dwm
printf 'uncommitted edit\n' > "$SRC_DIR/dwm/source.txt"
status_before=$(git -C "$SRC_DIR/dwm" status --porcelain)
suckless_read_lock dwm "$SUCKLESS_LOCK_FILE"
suckless_ensure_source dwm "$SUCKLESS_REVISION" "$SUCKLESS_REPO_URL"
suckless_build_revision dwm "$SUCKLESS_REVISION" > "$tmp_dir/build.log"
[[ "$(cat "$SUCKLESS_BUILD_DIR/built")" == 'recorded source' ]] || fail 'build used dirty source'
[[ "$(git -C "$SRC_DIR/dwm" status --porcelain)" == "$status_before" ]] || fail 'build changed checkout'
[[ "$(git -C "$SRC_DIR/dwm" branch --show-current)" == main ]] || fail 'build switched branches'
[[ "$(git -C "$SRC_DIR/dwm" remote get-url upstream)" == https://git.suckless.org/dwm ]] \
    || fail 'build changed upstream'

if "$repo_dir/scripts/suckless" pin dwm > "$tmp_dir/dirty-pin.log" 2>&1; then
    fail 'pin accepted uncommitted edits'
fi
grep -q 'uncommitted files' "$tmp_dir/dirty-pin.log" || fail 'dirty pin refusal was unclear'

printf 'new committed source\n' > "$SRC_DIR/dwm/source.txt"
git -C "$SRC_DIR/dwm" add source.txt
git -C "$SRC_DIR/dwm" commit -qm 'fixture change'
new_revision=$(git -C "$SRC_DIR/dwm" rev-parse HEAD)
"$repo_dir/scripts/suckless" pin dwm > "$tmp_dir/pin.log"
grep -qx "dwm $new_revision -" "$SUCKLESS_LOCK_FILE" || fail 'pin did not record clean main'
[[ -z "$(git -C "$SRC_DIR/dwm" status --porcelain)" ]] || fail 'pin dirtied source checkout'

git -C "$SRC_DIR/dwm" switch -qc update/example
if "$repo_dir/scripts/suckless" pin dwm > "$tmp_dir/branch-pin.log" 2>&1; then
    fail 'pin accepted an unpromoted branch'
fi
grep -q 'Switch dwm to main' "$tmp_dir/branch-pin.log" || fail 'branch refusal was unclear'
git -C "$SRC_DIR/dwm" switch -q main

# Hosted pins must exist on origin/main, and bootstrap can clone them locally.
git init -q --bare --initial-branch=main "$tmp_dir/hosted.git"
git -C "$SRC_DIR/dwm" remote add origin "$tmp_dir/hosted.git"
if "$repo_dir/scripts/suckless" pin dwm > "$tmp_dir/unpushed.log" 2>&1; then
    fail 'pin accepted an unpublished hosted commit'
fi
grep -q 'Push dwm main to origin' "$tmp_dir/unpushed.log" || fail 'unpublished refusal was unclear'
git -C "$SRC_DIR/dwm" push -q -u origin main
"$repo_dir/scripts/suckless" pin dwm > "$tmp_dir/hosted-pin.log"
grep -qx "dwm $new_revision $tmp_dir/hosted.git" "$SUCKLESS_LOCK_FILE" || fail 'pin lost hosted URL'
SRC_DIR="$tmp_dir/fresh-sources"
suckless_ensure_source dwm "$new_revision" "$tmp_dir/hosted.git" > "$tmp_dir/clone.log" 2>&1
[[ "$(git -C "$SRC_DIR/dwm" rev-parse HEAD)" == "$new_revision" ]] || fail 'clone lost maintained commit'
[[ "$(git -C "$SRC_DIR/dwm" remote get-url origin)" == "$tmp_dir/hosted.git" ]] || fail 'clone lost origin'
[[ "$(git -C "$SRC_DIR/dwm" remote get-url upstream)" == https://git.suckless.org/dwm ]] || fail 'clone lacks upstream'
[[ "$(git -C "$SRC_DIR/dwm" config rerere.enabled)" == true ]] || fail 'clone lacks conflict resolution reuse'
[[ "$(git -C "$SRC_DIR/dwm" config pull.ff)" == only ]] || fail 'clone lacks safe pull settings'

if suckless_ensure_source st "$pinned" - > "$tmp_dir/missing.log" 2>&1; then
    fail 'missing unhosted repository was silently replaced'
fi
grep -q 'no hosted URL yet' "$tmp_dir/missing.log" || fail 'missing repository refusal was unclear'

printf 'dwm %s -' "$pinned" > "$SUCKLESS_LOCK_FILE"
suckless_read_lock dwm "$SUCKLESS_LOCK_FILE"
[[ "$SUCKLESS_REVISION" == "$pinned" ]] || fail 'commit list requires a trailing newline'

printf 'dwm invalid -\n' > "$SUCKLESS_LOCK_FILE"
if suckless_read_lock dwm "$SUCKLESS_LOCK_FILE" > "$tmp_dir/invalid.log" 2>&1; then
    fail 'invalid commit ID was accepted'
fi
printf 'dwm %s -\ndwm %s -\n' "$pinned" "$pinned" > "$SUCKLESS_LOCK_FILE"
if suckless_read_lock dwm "$SUCKLESS_LOCK_FILE" > "$tmp_dir/duplicate.log" 2>&1; then
    fail 'duplicate commit entries were accepted'
fi

printf 'suckless workflow checks passed\n'
