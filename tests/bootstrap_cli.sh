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

grep -q '^  dwm[[:space:]]' "$tmp_dir/test.out" || fail 'test profile must include suckless tools'

run_plan suckless-only nothing --only dwm
grep -q '^  dwm[[:space:]]' "$tmp_dir/suckless-only.out" || fail 'dwm component must be independently selectable'
grep -q '^  dwm[[:space:]]\+pinned custom source + system integration$' "$tmp_dir/suckless-only.out" \
    || fail 'suckless plan must describe maintained sources'
grep -q "Suckless sources: $HOME/soft" "$tmp_dir/suckless-only.out" \
    || fail 'suckless sources must default to ~/soft'
while read -r tool revision repo_url; do
    [[ -z "$tool" || "$tool" == \#* ]] && continue
    grep -q "^[[:space:]]*$tool[[:space:]]\+$revision$" "$tmp_dir/suckless-only.out" \
        || fail "$tool pinned commit missing from plan"
done < "$repo_dir/config/suckless.lock"
SRC_DIR="$tmp_dir/custom-sources" run_plan suckless-location nothing --only dwm
grep -q "Suckless sources: $tmp_dir/custom-sources" "$tmp_dir/suckless-location.out" \
    || fail 'suckless source location override was ignored'
printf 'dwm invalid -\n' > "$tmp_dir/invalid-suckless.lock"
if SUCKLESS_LOCK_FILE="$tmp_dir/invalid-suckless.lock" \
    "$bootstrap" nothing --only dwm --dry-run > "$tmp_dir/invalid-suckless.out" 2>&1; then
    fail 'invalid suckless commit list was accepted'
fi
grep -q 'Invalid or duplicate entry for dwm' "$tmp_dir/invalid-suckless.out" \
    || fail 'invalid suckless commit refusal was unclear'
grep -q '(no components selected)' "$tmp_dir/nothing.out" || fail 'nothing profile must be empty'

for profile in desktop server; do
    grep -q '^  leaf[[:space:]]\+pinned upstream binary$' "$tmp_dir/$profile.out" \
        || fail "$profile profile must include sudo-free Leaf"
done

run_plan leaf-only nothing --only leaf
grep -q '^  leaf[[:space:]]\+pinned upstream binary$' "$tmp_dir/leaf-only.out" \
    || fail 'leaf component was not independently selectable'

cli_tools=(zoxide eza dust tlrc duf procs)
for profile in desktop server; do
    for component in "${cli_tools[@]}"; do
        grep -q "^  $component[[:space:]]\+pinned source release$" "$tmp_dir/$profile.out" \
            || fail "$profile profile must include sudo-free $component"
    done
done

run_plan cli-tools-only nothing --only zoxide,eza,dust,tlrc,duf,procs
awk '/^  [a-z]/ {print $1}' "$tmp_dir/cli-tools-only.out" > "$tmp_dir/cli-tools-order.out"
printf '%s\n' go "${cli_tools[@]}" > "$tmp_dir/cli-tools-expected.out"
cmp -s "$tmp_dir/cli-tools-order.out" "$tmp_dir/cli-tools-expected.out" \
    || fail 'CLI tools must select only themselves and their Go prerequisite in provider order'

run_plan cli-tools-skip server --skip zoxide,eza,dust,tlrc,duf,procs
if grep -Eq '^  (zoxide|eza|dust|tlrc|duf|procs)[[:space:]]' "$tmp_dir/cli-tools-skip.out"; then
    fail 'CLI tools could not be skipped'
fi

run_plan duf-only nothing --only duf
grep -q '^  go[[:space:]]' "$tmp_dir/duf-only.out" || fail 'duf must select the Go toolchain'
if "$bootstrap" nothing --only duf --skip go --dry-run > "$tmp_dir/duf-prerequisite-error.out" 2>&1; then
    fail 'duf accepted an explicitly skipped Go prerequisite'
fi
grep -q 'duf requires go' "$tmp_dir/duf-prerequisite-error.out" \
    || fail 'duf missing prerequisite refusal was unclear'

# Every registry entry is independently selectable, including future additions.
"$bootstrap" --list > "$tmp_dir/components.out"
while read -r component; do
    run_plan "component-$component" nothing --only "$component"
    grep -q "^  $component[[:space:]]" "$tmp_dir/component-$component.out" \
        || fail "$component registry entry cannot be selected"
done < <(awk '/^Components / { listing=1; next } /^Groups:/ { listing=0 } listing {print $1}' "$tmp_dir/components.out")

if grep -q 'wipe-suckless' "$tmp_dir/components.out"; then fail 'removed wipe-suckless is still listed'; fi
if "$bootstrap" nothing --only wipe-suckless --dry-run > "$tmp_dir/wipe.out" 2>&1; then
    fail 'removed wipe-suckless component was accepted'
fi
grep -q 'Unknown component: wipe-suckless' "$tmp_dir/wipe.out" || fail 'removed component refusal was unclear'

run_plan science-group nothing --only science --skip julia,qd
grep -q '^  gmp[[:space:]]' "$tmp_dir/science-group.out" || fail 'science group did not expand'
if grep -Eq '^  (julia|qd)[[:space:]]' "$tmp_dir/science-group.out"; then fail 'skip did not remove group members'; fi
run_plan desktop-apps nothing --only desktop-apps
for component in krita messengers media; do
    grep -q "^  $component[[:space:]]" "$tmp_dir/desktop-apps.out" || fail 'desktop-apps group did not expand'
done

run_plan prerequisite nothing --only zettelkasten
grep -q '^  core[[:space:]]' "$tmp_dir/prerequisite.out" || fail 'required core was not selected'
if "$bootstrap" nothing --only zettelkasten --skip core --dry-run > "$tmp_dir/prerequisite-error.out" 2>&1; then
    fail 'explicitly skipped prerequisite was accepted'
fi
grep -q 'zettelkasten requires core' "$tmp_dir/prerequisite-error.out" || fail 'missing prerequisite refusal was unclear'

run_plan empty-only desktop --only=
grep -q '(no components selected)' "$tmp_dir/empty-only.out" || fail 'explicit empty --only retained profile defaults'
if "$bootstrap" nothing --only --dry-run > "$tmp_dir/missing-value.out" 2>&1; then
    fail 'missing --only value was accepted'
fi
grep -q -- '--only requires a value' "$tmp_dir/missing-value.out" || fail 'missing value refusal was unclear'

# The plan follows the registered provider order regardless of argument order.
run_plan ordered nothing --only lsp,julia,vim,node,polymake,singular,finiteflow32,msolve,git-lfs,go
awk '/^  [a-z]/ {print $1}' "$tmp_dir/ordered.out" > "$tmp_dir/order.out"
printf '%s\n' go git-lfs vim node julia msolve finiteflow32 singular polymake lsp > "$tmp_dir/expected-order.out"
cmp -s "$tmp_dir/order.out" "$tmp_dir/expected-order.out" || fail 'plan ignored provider order'

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

mkdir "$tmp_dir/symlink-home"
HOME="$tmp_dir/symlink-home" \
XDG_CONFIG_HOME="$tmp_dir/symlink-home/config" \
DOTFILES_DIR="$repo_dir" \
    "$repo_dir/makesymlinks.sh" --dry server > "$tmp_dir/server-symlinks.out"
grep -q 'config/leaf/config.toml' "$tmp_dir/server-symlinks.out" \
    || fail 'server profile must link Leaf configuration'

HOME="$tmp_dir/symlink-home" XDG_CONFIG_HOME="$tmp_dir/symlink-home/config" DOTFILES_DIR="$repo_dir" \
    "$repo_dir/makesymlinks.sh" --dry nothing --fontconfig --neovim --user-dirs > "$tmp_dir/targeted-symlinks.out"
for asset in fontconfig/fonts.conf nvim user-dirs.dirs user-dirs.conf; do
    grep -q "$asset" "$tmp_dir/targeted-symlinks.out" || fail "$asset targeted link missing"
done
if find "$tmp_dir/symlink-home" -mindepth 1 -print -quit | grep -q .; then
    fail 'makesymlinks --dry created configuration directories'
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

HOME="$tmp_dir/empty-home" XDG_STATE_HOME="$tmp_dir/empty-home/state" \
    "$bootstrap" --list > "$tmp_dir/list-no-write.out"
if find "$tmp_dir/empty-home" -mindepth 1 -print -quit | grep -q .; then fail 'listing wrote to HOME'; fi

(cd "$tmp_dir" && "$bootstrap" nothing --only leaf --dry-run) > "$tmp_dir/other-directory.out"
grep -q '^  leaf[[:space:]]' "$tmp_dir/other-directory.out" || fail 'bootstrap depends on current directory'

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

bash "$repo_dir/tests/bootstrap_runner.sh"
bash "$repo_dir/tests/bootstrap_cli_tools.sh"

printf 'bootstrap CLI checks passed\n'
