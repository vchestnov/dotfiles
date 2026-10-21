#!/usr/bin/env bash
set -Eeuo pipefail

install_desktop_tools() {
    log_section "FILE MANAGER AND PDF VIEWER"

    # Install vifm
    log_info "Installing vifm..."
    refresh_sudo
    apt_install vifm

    log_success "vifm installed"

    log_info "Installing colors for vifm..."
    clone_or_update "https://github.com/vifm/vifm-colors" "$HOME/.config/vifm/colors"
    log_success "Colors for vifm installed"

    # Install zathura and plugins
    log_info "Installing zathura..."
    apt_install zathura zathura-pdf-poppler zathura-ps zathura-djvu

    log_success "zathura installed"
}
