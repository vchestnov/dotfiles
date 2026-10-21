#!/usr/bin/env bash
set -Eeuo pipefail

install_fonts() {
    local DOTFILES_DIR
    log_section "FONT CONFIGURATION"

    # Font-based emoji crash fix - install proper fonts and configure fontconfig
    log_info "Installing fonts and configuring fontconfig to prevent emoji crashes..."

    # Install essential fonts including non-color emoji fonts
    refresh_sudo
    apt_install \
        fonts-liberation \
        fonts-liberation2 \
        fonts-dejavu \
        fonts-dejavu-core \
        fonts-dejavu-extra \
        fonts-noto-mono \
        fonts-noto-core \
        fonts-symbola \
        fonts-font-awesome \
        fonts-powerline \
        fonts-jetbrains-mono

    DOTFILES_DIR="$SCRIPT_DIR" "$SCRIPT_DIR/makesymlinks.sh" nothing --fontconfig

    fc-cache -fv
}
