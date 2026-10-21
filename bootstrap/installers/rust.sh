#!/usr/bin/env bash
set -Eeuo pipefail

install_rust_tools() {

    log_section "RUST TOOLS INSTALLATION"

    ensure_cargo_toolchain

    # Install fzf from git
    log_info "Installing fzf..."
    clone_or_update "https://github.com/junegunn/fzf.git" "$SRC_DIR/fzf"
    cd "$SRC_DIR/fzf"
    make install
    cp bin/fzf "$BIN_DIR/"

    # Install fzf shell integration
    "$SRC_DIR/fzf/install" --bin --key-bindings --completion --no-update-rc

    log_success "fzf installed"

    # Install ripgrep (rg) from git
    log_info "Installing ripgrep..."
    clone_or_update "https://github.com/BurntSushi/ripgrep.git" "$SRC_DIR/ripgrep"
    cd "$SRC_DIR/ripgrep"
    cargo build --release
    cp target/release/rg "$BIN_DIR/"

    log_success "ripgrep installed"

    # Install fd from git
    log_info "Installing fd..."
    clone_or_update "https://github.com/sharkdp/fd.git" "$SRC_DIR/fd"
    cd "$SRC_DIR/fd"
    cargo build --release
    cp target/release/fd "$BIN_DIR/"

    log_success "fd installed"

	# Install bat from git
	log_info "Installing bat..."

	clone_or_update "https://github.com/sharkdp/bat.git" "$SRC_DIR/bat"
	cd "$SRC_DIR/bat"
	cargo build --release
	cp target/release/bat "$BIN_DIR"

	log_success "bat installed"
}

install_tree_sitter() {
    local TREE_SITTER_CLI_ROOT

    log_section "TREE-SITTER CLI INSTALLATION"

    ensure_cargo_toolchain

    TREE_SITTER_CLI_ROOT="${TREE_SITTER_CLI_ROOT:-$HOME/.local}"

    log_info "Installing/updating tree-sitter CLI..."
    if cargo install --locked tree-sitter-cli --root "$TREE_SITTER_CLI_ROOT"; then
        :
    else
        log_warning "Full tree-sitter CLI build failed; retrying without the QuickJS runtime feature."
        log_warning "This fallback is usually enough for building parsers from repos that already ship generated C sources."
        cargo install --locked --no-default-features tree-sitter-cli --root "$TREE_SITTER_CLI_ROOT"
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
