#!/usr/bin/env bash
set -Eeuo pipefail

# Exercise source extraction and binary placement without downloads or compilers.
repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

export HOME="$tmp_dir/home with spaces"
export XDG_CONFIG_HOME="$HOME/config" XDG_DATA_HOME="$HOME/data"
export XDG_CACHE_HOME="$HOME/cache" XDG_STATE_HOME="$HOME/state"
export SRC_DIR="$HOME/sources" BIN_DIR="$HOME/bin" BUILD_DIR="$HOME/build"
export CARGO_HOME="$HOME/cargo" RUSTUP_HOME="$HOME/rustup"
export ZOXIDE_VERSION=1.2.3 EZA_VERSION=2.3.4 DUST_VERSION=3.4.5
export TLRC_VERSION=4.5.6 DUF_VERSION=5.6.7 PROCS_VERSION=6.7.8
SCRIPT_DIR=$repo_dir
source "$repo_dir/bootstrap/paths.sh"
source "$repo_dir/bootstrap/versions.sh"
source "$repo_dir/bootstrap/lib.sh"
source "$repo_dir/bootstrap/installers/cli-tools.sh"
source "$repo_dir/bootstrap/installers/rust.sh"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

ensure_cargo_toolchain() {
    [[ "$1" == "$CLI_RUST_TOOLCHAIN_VERSION" ]] || fail 'pinned Rust toolchain ignored'
    mkdir -p "$BIN_DIR"
}

rustup() {
    if [[ "$1" == run ]]; then
        [[ "$2" == "$CLI_RUST_TOOLCHAIN_VERSION" ]] || fail 'build ignored pinned Rust toolchain'
        shift 2
        "$@"
    else
        [[ "$*" == "toolchain install $CLI_RUST_TOOLCHAIN_VERSION --profile minimal --no-self-update" ]] \
            || fail 'unexpected Rust toolchain operation'
        printf '%s\n' "$*" >> "$tmp_dir/toolchains"
    fi
}

download_file() {
    local url=$1 dest=$2 fixture_dir="$tmp_dir/fixture"
    printf '%s\n' "$url" >> "$tmp_dir/downloads"
    mkdir -p "$fixture_dir"
    printf 'fixture\n' > "$fixture_dir/Cargo.toml"
    printf 'fixture\n' > "$fixture_dir/Cargo.lock"
    printf 'fixture\n' > "$fixture_dir/go.mod"
    tar -czf "$dest" -C "$tmp_dir" fixture
}

write_fixture_binary() {
    cat > "$1" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
[[ "$1" == --version ]]
printf 'fixture version\n'
EOF
    chmod +x "$1"
}

cargo() {
    local binary='' manifest='' features=''
    local locked=false release=false
    [[ "$1" == build ]] || fail 'unexpected Cargo command'
    shift
    while (( $# )); do
        case "$1" in
            --manifest-path) manifest=$2; shift 2 ;;
            --bin) binary=$2; shift 2 ;;
            --jobs) [[ "$2" == 2 ]] || fail 'BUILD_JOBS ignored'; shift 2 ;;
            --features) features=$2; shift 2 ;;
            --locked) locked=true; shift ;;
            --release) release=true; shift ;;
            *) fail "unexpected Cargo argument: $1" ;;
        esac
    done
    $locked && $release || fail 'Rust releases must use locked release builds'
    [[ -f "$manifest" && -f "${manifest%/*}/Cargo.lock" ]] || fail 'Rust source was not extracted'
    [[ "$CARGO_TARGET_DIR" == "$BUILD_DIR/"* ]] || fail 'Rust build escaped BUILD_DIR'
    if [[ "$binary" == eza && "$features" != vendored-libgit2 ]]; then
        fail 'eza must build libgit2 without a system package'
    fi
    mkdir -p "$CARGO_TARGET_DIR/release"
    write_fixture_binary "$CARGO_TARGET_DIR/release/$binary"
}

go() {
    local output='' flags='' readonly=false
    [[ "$1" == build ]] || fail 'unexpected Go command'
    shift
    while (( $# )); do
        case "$1" in
            -o) output=$2; shift 2 ;;
            -ldflags) flags=$2; shift 2 ;;
            -mod=readonly) readonly=true; shift ;;
            -trimpath|.) shift ;;
            *) fail "unexpected Go argument: $1" ;;
        esac
    done
    $readonly || fail 'Go build allowed dependency changes'
    [[ -f go.mod && "$PWD" == "$SRC_DIR/duf-$DUF_VERSION" ]] || fail 'Go source was not extracted'
    [[ "$output" == "$BUILD_DIR/duf-$DUF_VERSION/duf" ]] || fail 'Go build escaped BUILD_DIR'
    [[ "$flags" == *"-X main.Version=$DUF_VERSION"* ]] || fail 'duf release version was not embedded'
    [[ "$CGO_ENABLED" == 0 && -n "$GOCACHE" && -n "$GOMODCACHE" ]] || fail 'Go build environment missing'
    write_fixture_binary "$output"
}

BUILD_JOBS=2
for attempt in 1 2; do
    for tool in zoxide eza dust tlrc duf procs; do
        "install_$tool"
    done
done
[[ "$(wc -l < "$tmp_dir/downloads")" == 6 ]] || fail 'cached source archives were downloaded again'
for binary in zoxide eza dust tldr duf procs; do
    [[ -x "$BIN_DIR/$binary" ]] || fail "$binary missing from BIN_DIR"
    [[ "$("$BIN_DIR/$binary" --version)" == 'fixture version' ]] || fail "$binary could not run"
done
[[ ! -e "$BIN_DIR/tlrc" ]] || fail 'tlrc installed under the wrong command name'
grep -qxF "https://github.com/ajeetdsouza/zoxide/archive/refs/tags/v$ZOXIDE_VERSION.tar.gz" "$tmp_dir/downloads"
grep -qxF "https://github.com/eza-community/eza/archive/refs/tags/v$EZA_VERSION.tar.gz" "$tmp_dir/downloads"
grep -qxF "https://github.com/bootandy/dust/archive/refs/tags/v$DUST_VERSION.tar.gz" "$tmp_dir/downloads"
grep -qxF "https://github.com/tldr-pages/tlrc/archive/refs/tags/v$TLRC_VERSION.tar.gz" "$tmp_dir/downloads"
grep -qxF "https://github.com/muesli/duf/archive/refs/tags/v$DUF_VERSION.tar.gz" "$tmp_dir/downloads"
grep -qxF "https://github.com/dalance/procs/archive/refs/tags/v$PROCS_VERSION.tar.gz" "$tmp_dir/downloads"

# Tracked Rust sources must also use the pinned compiler and cached build output.
clone_or_update() {
    mkdir -p "$2"
    touch "$2/Cargo.toml" "$2/Cargo.lock"
}
install_rust_git_tool ripgrep https://example.invalid/ripgrep.git rg
[[ -x "$BIN_DIR/rg" ]] || fail 'tracked Rust tool was not installed'
[[ -f "$BUILD_DIR/ripgrep/release/rg" ]] || fail 'tracked Rust build output was not cached'
[[ ! -d "$SRC_DIR/ripgrep/target" ]] || fail 'tracked Rust build polluted its checkout'

# The shared helper provisions explicit compilers while preserving its old API.
source "$repo_dir/bootstrap/lib.sh"
ensure_cargo_toolchain "$CLI_RUST_TOOLCHAIN_VERSION"
[[ "$(wc -l < "$tmp_dir/toolchains")" == 1 ]] || fail 'explicit Rust toolchain was not provisioned'
ensure_cargo_toolchain
[[ "$(wc -l < "$tmp_dir/toolchains")" == 1 ]] || fail 'existing Rust callers unexpectedly changed toolchains'

printf 'bootstrap CLI tool installer checks passed\n'
