#!/usr/bin/env bash
set -Eeuo pipefail

install_gpg() {
    install_gpg_password_store
    install_gpg_pinentry
}

install_gpg_password_store() {
    local PASSWORD_STORE_DIR_DEFAULT
    log_section "PASS & GIT CREDENTIAL HELPER SETUP"

    # Install pass and GnuPG
    log_info "Installing pass (password-store) and GnuPG..."
    refresh_sudo
    apt_install pass gnupg

    # Configure XDG-style password store directory
    PASSWORD_STORE_DIR_DEFAULT="$HOME/.local/share/password-store"
    export PASSWORD_STORE_DIR="$PASSWORD_STORE_DIR_DEFAULT"

    if [ ! -d "$PASSWORD_STORE_DIR" ]; then
        log_info "Creating password-store directory at $PASSWORD_STORE_DIR"
        mkdir -p "$PASSWORD_STORE_DIR"
    fi

    # Ensure local bin directory exists (should already be created earlier)
    if [ ! -d "$BIN_DIR" ]; then
        log_info "Creating bin directory at $BIN_DIR"
        mkdir -p "$BIN_DIR"
    fi

    if [ -x "$BIN_DIR/git-credential-pass" ] || [ -L "$BIN_DIR/git-credential-pass" ]; then
        log_info "git-credential-pass already installed at $BIN_DIR."
    else
        log_info "Expecting git-credential-pass to be provided by your dotfiles (symlink)."
        log_info "After running makesymlinks.sh, ensure ~/.local/bin/git-credential-pass exists and is executable."
    fi

    log_info "Git credential.helper is managed by config/git/config"

    # Check whether pass is initialized; if not, warn the user
    if ! pass ls >/dev/null 2>&1; then
        log_warning "pass is not initialized yet."
        log_warning "Run 'gpg --full-generate-key' (if needed) and then:"
        log_warning "  pass init <your-gpg-id>"
        log_warning "before using the Git credential helper."
    else
        log_info "pass appears to be initialized; credentials will be stored encrypted."
    fi

    log_success "pass and Git credential helper setup complete"
}

install_gpg_pinentry() {
    local AGENT_CONF GNUPG_DIR
    log_section "GPG TERMINAL PINENTRY SETUP"

    GNUPG_DIR="$HOME/.gnupg"
    AGENT_CONF="$GNUPG_DIR/gpg-agent.conf"

    log_info "Ensuring ~/.gnupg exists and has correct permissions..."
    mkdir -p "$GNUPG_DIR"
    chmod 700 "$GNUPG_DIR"

    # Install pinentry-curses if missing
    if ! command -v pinentry-curses >/dev/null 2>&1; then
        log_info "Installing pinentry-curses..."
        refresh_sudo
        apt_install pinentry-curses
    else
        log_info "pinentry-curses is already installed."
    fi

    if [ ! -e "$AGENT_CONF" ]; then
        log_warning "$AGENT_CONF is missing; run makesymlinks.sh for repository-managed GnuPG configuration."
    fi

    # Restart gpg-agent
    log_info "Restarting gpg-agent..."
    gpgconf --kill gpg-agent || component_incomplete "Could not restart gpg-agent."

    log_success "GPG terminal pinentry configured."
    log_success "Future GPG/pass prompts will appear directly in the terminal."
}
