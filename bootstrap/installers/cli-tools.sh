#!/usr/bin/env bash
set -Eeuo pipefail

install_rust_cli_release() {
    local name=$1 repository=$2 version=$3 binary=$4
    shift 4
    local source_dir="$SRC_DIR/$name-$version"
    local archive="$XDG_CACHE_HOME/bootstrap/downloads/$name-$version.tar.gz"
    local target_dir="$BUILD_DIR/$name-$version"
    local url="https://github.com/$repository/archive/refs/tags/v$version.tar.gz"

    ensure_cargo_toolchain "$CLI_RUST_TOOLCHAIN_VERSION"
    log_info "Building $name $version from its source release..."
    prepare_source_from_tarball "$url" "$archive" "$source_dir" "$source_dir/Cargo.lock"
    CARGO_TARGET_DIR="$target_dir" rustup run "$CLI_RUST_TOOLCHAIN_VERSION" cargo build \
        --manifest-path "$source_dir/Cargo.toml" --locked --release --bin "$binary" \
        --jobs "${BUILD_JOBS:-$(default_build_jobs)}" "$@"
    install -m 0755 "$target_dir/release/$binary" "$BIN_DIR/$binary"
    "$BIN_DIR/$binary" --version
    log_success "$name $version installed at $BIN_DIR/$binary"
}

install_zoxide() {
    install_rust_cli_release zoxide ajeetdsouza/zoxide "$ZOXIDE_VERSION" zoxide
}

install_eza() {
    install_rust_cli_release eza eza-community/eza "$EZA_VERSION" eza \
        --features vendored-libgit2
}

install_dust() {
    install_rust_cli_release dust bootandy/dust "$DUST_VERSION" dust
}

install_tlrc() {
    install_rust_cli_release tlrc tldr-pages/tlrc "$TLRC_VERSION" tldr
}

install_procs() {
    install_rust_cli_release procs dalance/procs "$PROCS_VERSION" procs
}

install_duf() {
    local version="$DUF_VERSION"
    local source_dir="$SRC_DIR/duf-$version"
    local archive="$XDG_CACHE_HOME/bootstrap/downloads/duf-$version.tar.gz"
    local build_dir="$BUILD_DIR/duf-$version"
    local url="https://github.com/muesli/duf/archive/refs/tags/v$version.tar.gz"

    if ! command -v go >/dev/null 2>&1; then
        log_error 'Go is required to build duf; select the go component.'
        return 1
    fi

    log_info "Building duf $version from its source release..."
    prepare_source_from_tarball "$url" "$archive" "$source_dir" "$source_dir/go.mod"
    mkdir -p "$build_dir" "$BIN_DIR"
    (
        cd "$source_dir"
        CGO_ENABLED=0 \
        GOCACHE="${GOCACHE:-$XDG_CACHE_HOME/bootstrap/go-build}" \
        GOMODCACHE="${GOMODCACHE:-$XDG_CACHE_HOME/bootstrap/go-mod}" \
            go build -mod=readonly -trimpath -ldflags "-s -w -X main.Version=$version" \
                -o "$build_dir/duf" .
    )
    install -m 0755 "$build_dir/duf" "$BIN_DIR/duf"
    "$BIN_DIR/duf" --version
    log_success "duf $version installed at $BIN_DIR/duf"
}
