#!/usr/bin/env bash
set -Eeuo pipefail

install_python_tools() {
    local ARXIVTERMINAL_DEV_DIR
    log_section "PYTHON DEVELOPMENT TOOLS INSTALLATION"

    # Persistent PATH configuration belongs to the repository-managed profile.

    # Add pipx bin dir to current session's PATH to find poetry later
    export PATH="$PATH:$HOME/.local/bin"

    # ========================================
    # Poetry
    # ========================================
    if ! command -v poetry &> /dev/null; then
        log_info "Installing Poetry using pipx..."
        pipx install poetry
        log_success "Poetry installed successfully."
    else
        log_warning "Poetry is already installed, skipping installation."
        # Optionally, you could upgrade it
        # log_info "Upgrading Poetry..."
        # pipx upgrade poetry
    fi

    # ========================================
    # Arxivterminal
    # ========================================
    log_info "Installing arxivterminal fork..."

    ARXIVTERMINAL_DEV_DIR="$HOME/dev/arxivterminal"
    mkdir -p "$HOME/dev"

    clone_or_update "https://github.com/vchestnov/arxivterminal.git" "$ARXIVTERMINAL_DEV_DIR"
    cd "$ARXIVTERMINAL_DEV_DIR"

    poetry install

    pipx install --force "$ARXIVTERMINAL_DEV_DIR"

    log_success "arxivterminal installed via pipx. Command available as 'arxiv'."
}
