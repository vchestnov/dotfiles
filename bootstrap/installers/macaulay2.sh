#!/usr/bin/env bash
set -Eeuo pipefail

install_macaulay2() {
    log_section "MACAULAY2 COMPUTER ALGEBRA SYSTEM INSTALLATION (PPA)"


    # Check if M2 is already installed.
    if command -v M2 &> /dev/null; then
        # Extract version; fails softly to "unknown".
        CURRENT_VERSION=$(
            M2 --version 2>/dev/null \
                | head -n1 \
                || echo "unknown"
        )
        log_info "Macaulay2 is already installed (version: $CURRENT_VERSION)"

    fi

    log_info "Adding official Macaulay2 PPA: ppa:macaulay2/macaulay2"

    refresh_sudo
    sudo add-apt-repository -y ppa:macaulay2/macaulay2

    log_info "Updating package lists…"
    apt_refresh force

    log_info "Installing Macaulay2…"
    apt_install macaulay2

    # Verify installation
    log_info "Verifying Macaulay2 installation…"
    if command -v M2 &> /dev/null; then
        # Minimal non-interactive invocation
        if M2 --version > /dev/null 2>&1; then
            log_success "Macaulay2 installation verified and working"
        else
            component_incomplete "Macaulay2 is installed but its version check failed."
        fi
    else
        log_error "'M2' binary not found after installation"
        log_info "Try: sudo apt-get install -f"
        return 1
    fi
}
