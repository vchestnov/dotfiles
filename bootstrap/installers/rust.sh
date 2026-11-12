#!/usr/bin/env bash
set -Eeuo pipefail

install_rust_git_tool() {
    local name=$1 repository=$2 binary=$3
    local source_dir="$SRC_DIR/$name" target_dir="$BUILD_DIR/$name"

    log_info "Installing $name..."
    clone_or_update "$repository" "$source_dir"
    CARGO_TARGET_DIR="$target_dir" rustup run "$CLI_RUST_TOOLCHAIN_VERSION" cargo build \
        --manifest-path "$source_dir/Cargo.toml" --locked --release --bin "$binary" \
        --jobs "${BUILD_JOBS:-$(default_build_jobs)}"
    install -m 0755 "$target_dir/release/$binary" "$BIN_DIR/$binary"
    log_success "$name installed"
}

install_rust_tools() {

    log_section "RUST TOOLS INSTALLATION"

    ensure_cargo_toolchain "$CLI_RUST_TOOLCHAIN_VERSION"

    # Install fzf from git
    log_info "Installing fzf..."
    clone_or_update "https://github.com/junegunn/fzf.git" "$SRC_DIR/fzf"
    cd "$SRC_DIR/fzf"
    make install
    cp bin/fzf "$BIN_DIR/"

    # Install fzf shell integration
    "$SRC_DIR/fzf/install" --bin --key-bindings --completion --no-update-rc

    log_success "fzf installed"

    install_rust_git_tool ripgrep https://github.com/BurntSushi/ripgrep.git rg
    install_rust_git_tool fd https://github.com/sharkdp/fd.git fd
    install_rust_git_tool bat https://github.com/sharkdp/bat.git bat
}

install_tree_sitter() {
    local TREE_SITTER_CLI_ROOT

    log_section "TREE-SITTER CLI INSTALLATION"

    ensure_cargo_toolchain "$CLI_RUST_TOOLCHAIN_VERSION"

    TREE_SITTER_CLI_ROOT="${TREE_SITTER_CLI_ROOT:-$HOME/.local}"

    log_info "Installing/updating tree-sitter CLI..."
    if rustup run "$CLI_RUST_TOOLCHAIN_VERSION" cargo install --locked tree-sitter-cli \
        --root "$TREE_SITTER_CLI_ROOT" --jobs "${BUILD_JOBS:-$(default_build_jobs)}"; then
        :
    else
        log_warning "Full tree-sitter CLI build failed; retrying without the QuickJS runtime feature."
        log_warning "This fallback is usually enough for building parsers from repos that already ship generated C sources."
        rustup run "$CLI_RUST_TOOLCHAIN_VERSION" cargo install --locked --no-default-features tree-sitter-cli \
            --root "$TREE_SITTER_CLI_ROOT" --jobs "${BUILD_JOBS:-$(default_build_jobs)}"
    fi

    hash -r

    if [ -x "$TREE_SITTER_CLI_ROOT/bin/tree-sitter" ]; then
        log_success "tree-sitter CLI installed at $TREE_SITTER_CLI_ROOT/bin/tree-sitter"
    elif command -v tree-sitter >/dev/null 2>&1; then
        log_success "tree-sitter CLI installed at $(command -v tree-sitter)"
    else
        component_incomplete "tree-sitter install completed, but its binary was not found."
    fi
}
