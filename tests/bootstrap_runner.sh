#!/usr/bin/env bash
set -Eeuo pipefail

# Exercise the real dispatcher and error trap with installers that do no host work.
repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

cat > "$tmp_dir/fixture.sh" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR=$BOOTSTRAP_TEST_REPO
source "$SCRIPT_DIR/bootstrap/paths.sh"
source "$SCRIPT_DIR/bootstrap/lib.sh"
source "$SCRIPT_DIR/bootstrap/registry.sh"
source "$SCRIPT_DIR/bootstrap/runner.sh"
BOOTSTRAP_PROFILE=nothing
preflight() { :; }
install_ok() { printf 'ok\n' >> "$HOME/events"; }
install_skip() { skip_component 'optional fixture unavailable'; }
install_partial() { component_incomplete 'optional fixture integration failed'; }
install_bad() { false; printf 'continued after failure\n' >> "$HOME/events"; }
install_later() { printf 'later\n' >> "$HOME/events"; }
register_component ok --installer install_ok --file fixture.sh --method fixture
register_component skip --installer install_skip --file fixture.sh --method fixture
register_component partial --installer install_partial --file fixture.sh --method fixture
register_component bad --installer install_bad --file fixture.sh --method fixture
register_component later --installer install_later --file fixture.sh --method fixture
case "$1" in
    success) SELECTED_COMPONENTS=(ok later) ;;
    partial) SELECTED_COMPONENTS=(ok skip partial later) ;;
    failure) SELECTED_COMPONENTS=(ok bad later) ;;
esac
execute_plan
EOF

run_case() {
    local name=$1
    mkdir -p "$tmp_dir/$name"
    HOME="$tmp_dir/$name" \
    XDG_CONFIG_HOME="$tmp_dir/$name/config" \
    XDG_DATA_HOME="$tmp_dir/$name/data" \
    XDG_CACHE_HOME="$tmp_dir/$name/cache" \
    XDG_STATE_HOME="$tmp_dir/$name/state" \
    BOOTSTRAP_TEST_REPO="$repo_dir" \
        bash "$tmp_dir/fixture.sh" "$name" > "$tmp_dir/$name.log" 2>&1
}

run_case success
state="$tmp_dir/success/state/bootstrap/last-run"
grep -qx 'status=success' "$state" || fail 'runner did not report success'
grep -qx 'completed_components=ok later' "$state" || fail 'successful components missing from report'
[[ "$(cat "$tmp_dir/success/events")" == $'ok\nlater' ]] || fail 'runner changed plan order'

run_case partial
state="$tmp_dir/partial/state/bootstrap/last-run"
grep -qx 'status=partial' "$state" || fail 'runner reported optional omissions as success'
grep -qx 'skipped_components=skip' "$state" || fail 'skipped component missing from report'
grep -qx 'incomplete_components=partial' "$state" || fail 'incomplete component missing from report'
grep -qx 'completed_components=ok later' "$state" || fail 'runner did not continue after optional omissions'

if run_case failure; then fail 'runner ignored a failed command'; fi
state="$tmp_dir/failure/state/bootstrap/last-run"
grep -qx 'status=failed' "$state" || fail 'runner did not record failure'
grep -qx 'exit_code=1' "$state" || fail 'runner lost failed command status'
grep -qx 'failed_component=bad' "$state" || fail 'runner lost failing component name'
grep -qx 'completed_components=ok' "$state" || fail 'runner reported uncompleted components as successful'
[[ "$(cat "$tmp_dir/failure/events")" == ok ]] || fail 'runner continued inside/after a failed installer'

# Check argument boundaries and replacement of generated configuration symlinks.
HOME="$tmp_dir/helpers" BOOTSTRAP_TEST_REPO="$repo_dir" bash <<'EOF'
set -Eeuo pipefail
source "$BOOTSTRAP_TEST_REPO/bootstrap/lib.sh"
mkdir -p "$HOME"
make() { printf '%s\n' "$@" >> "$HOME/make-arguments"; }
BUILD_JOBS=2 build_and_install fixture "PREFIX=$HOME/path with spaces"
grep -qxF "PREFIX=$HOME/path with spaces" "$HOME/make-arguments"
[[ "$(grep -cxF "PREFIX=$HOME/path with spaces" "$HOME/make-arguments")" == 2 ]]
printf 'original\n' > "$HOME/repository-config"
ln -s repository-config "$HOME/generated-config"
write_generated_file "$HOME/generated-config" <<< 'generated'
[[ ! -L "$HOME/generated-config" ]]
[[ "$(cat "$HOME/repository-config")" == original ]]
[[ "$(cat "$HOME/generated-config")" == generated ]]

# Local Git fixtures check release tags and checkout preservation without a network.
git init -q --initial-branch=main "$HOME/upstream"
git -C "$HOME/upstream" config user.name 'Bootstrap fixture'
git -C "$HOME/upstream" config user.email 'fixture@example.invalid'
printf 'first\n' > "$HOME/upstream/source"
git -C "$HOME/upstream" add source
git -C "$HOME/upstream" commit -qm first
git -C "$HOME/upstream" tag release-fixture
clone_or_update "$HOME/upstream" "$HOME/checkout" release-fixture
clone_or_update "$HOME/upstream" "$HOME/checkout" release-fixture
[[ "$(git -C "$HOME/checkout" rev-parse HEAD)" == "$(git -C "$HOME/upstream" rev-parse release-fixture)" ]]
printf 'uncommitted\n' > "$HOME/checkout/source"
printf 'untracked\n' > "$HOME/checkout/untracked"
before=$(git -C "$HOME/checkout" status --porcelain)
clone_or_update "$HOME/upstream" "$HOME/checkout" main
[[ "$(git -C "$HOME/checkout" status --porcelain)" == "$before" ]]
[[ "$(git -C "$HOME/checkout" branch --show-current)" == '' ]]
EOF

printf 'bootstrap runner checks passed\n'
