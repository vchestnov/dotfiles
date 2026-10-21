#!/usr/bin/env bash
set -Eeuo pipefail

install_neovim() {
    local DOTFILES_DIR NEOVIM_GIT_BRANCH NVIM_INSTALL_PREFIX NVIM_SOURCE_DIR missing_neovim_build_tools
    log_section "NEOVIM SETUP"

    : "${XDG_CONFIG_HOME:=$HOME/.config}"
    : "${XDG_DATA_HOME:=$HOME/.local/share}"
    : "${XDG_CACHE_HOME:=$HOME/.cache}"
    : "${XDG_STATE_HOME:=$HOME/.local/state}"

    NVIM_INSTALL_PREFIX="${NVIM_INSTALL_PREFIX:-$HOME/.local}"
    NVIM_SOURCE_DIR="${NVIM_SOURCE_DIR:-$SRC_DIR/neovim}"
    NEOVIM_GIT_BRANCH="${NEOVIM_GIT_BRANCH:-stable}"

    mkdir -p \
        "$NVIM_INSTALL_PREFIX/bin" \
        "$XDG_CONFIG_HOME" \
        "$XDG_CACHE_HOME/nvim" \
        "$XDG_STATE_HOME/nvim"

    missing_neovim_build_tools=()
    for required_cmd in git cc make cmake ninja curl unzip gettext; do
        if ! command -v "$required_cmd" >/dev/null 2>&1; then
            missing_neovim_build_tools+=("$required_cmd")
        fi
    done

    if [ "${#missing_neovim_build_tools[@]}" -gt 0 ]; then
        skip_component "Missing build tools: ${missing_neovim_build_tools[*]}"
        if component_enabled system-base && command -v sudo >/dev/null 2>&1; then
            log_warning "Enable system-base or install the missing tools, then rerun the neovim component."
        else
            log_warning "This profile avoids sudo. Install the missing tools in user space or via your admin, then rerun the neovim component."
        fi
    else
        log_info "Building Neovim from source (branch: $NEOVIM_GIT_BRANCH)..."
        clone_or_update "https://github.com/neovim/neovim.git" "$NVIM_SOURCE_DIR" "$NEOVIM_GIT_BRANCH"

        cd "$NVIM_SOURCE_DIR"
        make distclean 2>/dev/null || true
        rm -rf build .deps 2>/dev/null || true

        build_and_install "Neovim" CMAKE_BUILD_TYPE=RelWithDebInfo "CMAKE_INSTALL_PREFIX=$NVIM_INSTALL_PREFIX"
        hash -r
    fi

    DOTFILES_DIR="$SCRIPT_DIR" "$SCRIPT_DIR/makesymlinks.sh" nothing --neovim

    if command -v nvim >/dev/null 2>&1; then
        log_success "Neovim is available at $(command -v nvim)"
    elif [ -x "$NVIM_INSTALL_PREFIX/bin/nvim" ]; then
        log_success "Neovim is available at $NVIM_INSTALL_PREFIX/bin/nvim"
    else
        log_warning "nvim is not on PATH; ensure $HOME/.local/bin is exported before launching it."
    fi
}
