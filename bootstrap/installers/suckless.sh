#!/usr/bin/env bash
set -Eeuo pipefail

source "$SCRIPT_DIR/scripts/lib/suckless.sh"

install_suckless_sources() {
    log_section "SUCKLESS INSTALLATION"
    SUCKLESS_LOCK_FILE="${SUCKLESS_LOCK_FILE:-$SCRIPT_DIR/config/suckless.lock}"
    # Validate availability before installing any of the five tools.
    local tool
    for tool in dwm dmenu st slstatus slock; do
        suckless_read_lock "$tool" "$SUCKLESS_LOCK_FILE"
        suckless_ensure_source "$tool" "$SUCKLESS_REVISION" "$SUCKLESS_REPO_URL"
    done
    apt_install xss-lock
    for tool in dwm dmenu st slstatus slock; do
        suckless_read_lock "$tool" "$SUCKLESS_LOCK_FILE"
        suckless_prepare_build "$tool" "$SUCKLESS_REVISION"
        cd "$SUCKLESS_BUILD_DIR"
        build_and_install "$tool" --system
        log_success "$tool installed from maintained commit $SUCKLESS_REVISION"
    done
}

install_suckless_session() {
    log_section "DWM SESSION CONFIGURATION"

    log_info "Creating desktop entry for dwm in display manager..."
    refresh_sudo
    sudo mkdir -p /usr/share/xsessions

    # Create session startup script with keyboard config
    sudo install -m 0755 "$SCRIPT_DIR/config/suckless/dwm-session" /usr/local/bin/dwm-session


    # Create dwm.desktop file for display manager
    sudo install -m 0644 "$SCRIPT_DIR/config/suckless/dwm.desktop" /usr/share/xsessions/dwm.desktop

    log_success "dwm desktop entry created"
}

install_suckless_helpers() {
    mkdir -p "$BIN_DIR"
    install_launcher_script "$SCRIPT_DIR/scripts/lock" "$BIN_DIR/lock"

    install_launcher_script "$SCRIPT_DIR/scripts/reload-xresources" "$BIN_DIR/reload-xresources"
    log_success "Suckless desktop helpers installed"
}

print_suckless_plan() {
    local tool
    log_info "Suckless sources: $SRC_DIR"
    for tool in dwm dmenu st slstatus slock; do
        suckless_read_lock "$tool" "$SUCKLESS_LOCK_FILE"
        printf '    %-18s %s\n' "$tool" "$SUCKLESS_REVISION"
    done
}

install_suckless() {
    install_suckless_sources
    install_suckless_session
    install_suckless_helpers
}
