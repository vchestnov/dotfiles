#!/usr/bin/env bash
set -Eeuo pipefail

install_core_directories() {
    log_section "DIRECTORY SETUP"

    log_info "Creating directory structure..."
    mkdir -p "$BUILD_DIR" "$BIN_DIR" "$SRC_DIR"

    # The repository-managed profile owns persistent PATH configuration.
    if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
        export PATH="$BIN_DIR:$PATH"
        log_info "Added $BIN_DIR to PATH for this run"
    fi

    log_success "Directory structure created"
}

install_core_home() {
    log_section "HOME DIRECTORIES"

    # Clean home directory setup
    log_info "Setting up clean home directory structure..."

    # Create main directories
    mkdir -p "$HOME/dev" "$HOME/docs/downloads" "$SRC_DIR"

    log_success "Home directory structure created"
}

install_zettelkasten() {
    mkdir -p "$HOME/dev/zk" "$HOME/dev/templates/latex"
}

reset_user_dirs() {
    local dir
    log_warning "Resetting Ubuntu user directories by explicit request"
    for dir in Desktop Documents Downloads Music Pictures Public Templates Videos; do
        if [[ -d "$HOME/$dir" ]]; then
            if rmdir -- "$HOME/$dir" 2>/dev/null; then
                log_info "Removed empty $dir directory"
            else
                log_warning "Could not remove $dir; preserving it."
            fi
        fi
    done

    DOTFILES_DIR="$SCRIPT_DIR" "$SCRIPT_DIR/makesymlinks.sh" nothing --user-dirs
}

install_core_links() {
    local DOTFILES_DIR
    log_section "DOTFILES SETUP"

    local MAKESYMLINKS_SCRIPT="$SCRIPT_DIR/makesymlinks.sh"
    if [ ! -x "$MAKESYMLINKS_SCRIPT" ]; then
        log_error "Executable makesymlinks.sh not found in current checkout: $SCRIPT_DIR"
        return 1
    fi

    log_info "Delegating repository-backed configuration to makesymlinks.sh"
    DOTFILES_DIR="$SCRIPT_DIR" "$MAKESYMLINKS_SCRIPT" "$BOOTSTRAP_PROFILE"
    log_success "Dotfiles linked from $SCRIPT_DIR"
}

install_core() {
    install_core_directories
    install_core_home
    install_core_links
    install_ssh_find_agent
}

install_ssh_find_agent() {
    log_section "SSH-FIND-AGENT INSTALLATION"

    # Clone ssh-find-agent repository
    log_info "Installing ssh-find-agent..."
    clone_or_update "https://github.com/wwalker/ssh-find-agent.git" "$SRC_DIR/ssh-find-agent"

    cd "$SRC_DIR/ssh-find-agent"

    # Install the script to local bin directory
    cp ssh-find-agent.sh "$BIN_DIR/ssh-find-agent"
    chmod +x "$BIN_DIR/ssh-find-agent"

    # Ensure proper ownership
    chown "$USER:$(id -gn)" "$BIN_DIR/ssh-find-agent"

    log_success "ssh-find-agent installed successfully"

    # Provide usage information
    log_info "ssh-find-agent usage:"
    echo "  • ssh_agent_start  - Start SSH agent and add keys"
    echo "  • ssh_agent_list   - List available SSH agents"
    echo "  • ssh_agent_kill   - Kill current SSH agent"
    echo "  • ssh-find-agent   - Run ssh-find-agent directly"
    echo
    log_info "ssh-find-agent will automatically find and use existing SSH agents"
    log_info "This helps avoid multiple SSH agent instances and keeps your keys loaded"
}
