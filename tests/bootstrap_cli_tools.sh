#!/usr/bin/env bash
set -Eeuo pipefail

# Exercise release installers offline, including paths containing spaces.
repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

export HOME="$tmp_dir/home with spaces"
export XDG_CONFIG_HOME="$HOME/config" XDG_DATA_HOME="$HOME/data"
export XDG_CACHE_HOME="$HOME/cache" XDG_STATE_HOME="$HOME/state"
SCRIPT_DIR=$repo_dir
SRC_DIR="$HOME/sources"
BUILD_DIR="$HOME/build"
BIN_DIR="$HOME/bin"
BUILD_JOBS=2
source "$repo_dir/bootstrap/paths.sh"
source "$repo_dir/bootstrap/versions.sh"
source "$repo_dir/bootstrap/lib.sh"
source "$repo_dir/bootstrap/installers/cli-tools.sh"
source "$repo_dir/bootstrap/installers/rust.sh"
mkdir -p "$BIN_DIR"

write_binary() {
    mkdir -p "$(dirname "$1")"
    printf '#!/usr/bin/env bash\nprintf "fixture version\\n"\n' > "$1"
    chmod 0755 "$1"
}

download_file() {
    local url=$1 destination=$2 fixture
    printf '%s\n' "$url" >> "$HOME/downloads"
    fixture=$(mktemp -d "$tmp_dir/archive.XXXXXX")
    mkdir "$fixture/release"
    touch "$fixture/release/Cargo.toml" "$fixture/release/Cargo.lock" "$fixture/release/go.mod"
    tar -czf "$destination" -C "$fixture" release
}

# Compiler stand-ins produce runnable artifacts without installing toolchains.
ensure_cargo_toolchain() {
    [[ "$1" == "$CLI_RUST_TOOLCHAIN_VERSION" ]] || fail 'release installer did not select its pinned compiler'
}
rustup() {
    [[ "$1" == run && "$2" == "$CLI_RUST_TOOLCHAIN_VERSION" && "$3" == cargo && "$4" == build ]] \
        || fail 'release build did not use its explicit Rust toolchain'
    shift 4
    local binary='' manifest='' locked=false jobs=''
    while (( $# )); do
        case "$1" in
            --manifest-path) manifest=$2; shift 2 ;;
            --bin) binary=$2; shift 2 ;;
            --jobs) jobs=$2; shift 2 ;;
            --locked) locked=true; shift ;;
            *) shift ;;
        esac
    done
    $locked || fail 'release build ignored its dependency lockfile'
    [[ -f "$manifest" && "$jobs" == 2 && -n "$binary" ]] || fail 'release build lost a path or build option'
    write_binary "$CARGO_TARGET_DIR/release/$binary"
}
go() {
    [[ "$1" == build ]] || fail 'unexpected Go command'
    shift
    local output='' readonly=false
    while (( $# )); do
        case "$1" in
            -o) output=$2; shift 2 ;;
            -mod=readonly) readonly=true; shift ;;
            *) shift ;;
        esac
    done
    $readonly || fail 'Go build allowed dependency changes'
    [[ -f go.mod && -n "$output" && "$CGO_ENABLED" == 0 ]] || fail 'Go release build lost source or output path'
    write_binary "$output"
}

for component in zoxide eza dust tlrc duf procs; do
    "install_$component"
done
for binary in zoxide eza dust tldr duf procs; do
    [[ -x "$BIN_DIR/$binary" ]] || fail "$binary was not installed"
    [[ "$("$BIN_DIR/$binary" --version)" == 'fixture version' ]] || fail "$binary could not run"
done
for release in \
    "ajeetdsouza/zoxide/archive/refs/tags/v$ZOXIDE_VERSION" \
    "eza-community/eza/archive/refs/tags/v$EZA_VERSION" \
    "bootandy/dust/archive/refs/tags/v$DUST_VERSION" \
    "tldr-pages/tlrc/archive/refs/tags/v$TLRC_VERSION" \
    "muesli/duf/archive/refs/tags/v$DUF_VERSION" \
    "dalance/procs/archive/refs/tags/v$PROCS_VERSION"; do
    grep -qxF "https://github.com/$release.tar.gz" "$HOME/downloads" || fail "unexpected release URL: $release"
done
install_eza
[[ "$(wc -l < "$HOME/downloads")" == 6 ]] || fail 'repeat installation did not reuse cached archives'

# Tracked Rust sources must also use the pinned compiler and cached build output.
clone_or_update() {
    mkdir -p "$2"
    touch "$2/Cargo.toml" "$2/Cargo.lock"
}
install_rust_git_tool ripgrep https://example.invalid/ripgrep.git rg
[[ -x "$BIN_DIR/rg" ]] || fail 'tracked Rust tool was not installed'
[[ -f "$BUILD_DIR/ripgrep/release/rg" ]] || fail 'tracked Rust build output was not cached'
[[ ! -d "$SRC_DIR/ripgrep/target" ]] || fail 'tracked Rust build polluted its checkout'

printf 'bootstrap CLI tool checks passed\n'
