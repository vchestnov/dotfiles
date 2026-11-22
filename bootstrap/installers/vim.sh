#!/usr/bin/env bash
set -Eeuo pipefail

install_vim() {
    log_section "VIM INSTALLATION"

    # Python tools run as separate processes; avoid a host-specific libpython ABI.
    log_info "Building Vim from source..."
    clone_or_update "https://github.com/vim/vim.git" "$SRC_DIR/vim"

    cd "$SRC_DIR/vim"
    make distclean 2>/dev/null || true

    ./configure \
        --with-features=huge \
        --enable-multibyte \
        --enable-rubyinterp=yes \
        --disable-pythoninterp \
        --disable-python3interp \
        --enable-perlinterp=yes \
        --enable-luainterp=yes \
        --enable-gui=no \
        --enable-cscope \
        --enable-terminal \
        --with-x \
        --enable-clipboard \
        --prefix="$HOME/.local" \
        --disable-xsmp \
        --disable-xsmp-interact

    build_and_install "Vim"

    : "${XDG_CACHE_HOME:=$HOME/.cache}";
    mkdir -p "$XDG_CACHE_HOME/vim/"{swap,undo,backup}

    log_success "Vim installed with terminal and clipboard support, without embedded Python"
}
