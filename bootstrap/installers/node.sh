#!/usr/bin/env bash
set -Eeuo pipefail

install_nvm_node_tools() {
    : "${XDG_CONFIG_HOME:=$HOME/.config}"
    : "${XDG_DATA_HOME:=$HOME/.local/share}"

    local nvm_version="${NVM_VERSION}"
    local node_version="${NODE_VERSION:-lts/*}"
    local nvm_dir="${NVM_DIR:-$XDG_DATA_HOME/nvm}"
    local nvm_env_file="${NVM_ENV_FILE:-$XDG_CONFIG_HOME/nvm/env.sh}"

    local node_packages=(
        @openai/codex
        bash-language-server
        vim-language-server
        vscode-langservers-extracted
        yaml-language-server
        typescript
        typescript-language-server
    )

    if ! command -v git >/dev/null 2>&1; then
        log_warning "git is required to install nvm."
        return 1
    fi

    mkdir -p "$XDG_CONFIG_HOME/nvm" "$XDG_DATA_HOME"

    log_info "Installing/updating nvm $nvm_version in $nvm_dir"
    clone_or_update "https://github.com/nvm-sh/nvm.git" "$nvm_dir" "$nvm_version"

    log_info "Writing nvm environment file: $nvm_env_file"
    write_generated_file "$nvm_env_file" << EOF
# nvm / Node.js environment
export NVM_DIR="$nvm_dir"

if [ -s "\$NVM_DIR/nvm.sh" ]; then
    . "\$NVM_DIR/nvm.sh"
fi

if [ -s "\$NVM_DIR/bash_completion" ]; then
    . "\$NVM_DIR/bash_completion"
fi
EOF

    # Load nvm in the current bootstrap session.
    # shellcheck disable=SC1090
    source "$nvm_env_file"

    if ! command -v nvm >/dev/null 2>&1; then
        log_warning "nvm did not load correctly from $nvm_env_file"
        return 1
    fi

    log_info "Installing Node.js version: $node_version"
    nvm install "$node_version"
    nvm alias default "$node_version"
    nvm use default

    log_info "Node version: $(node --version)"
    log_info "npm version: $(npm --version)"

    log_info "Installing npm global tools..."
    npm install -g "${node_packages[@]}"

    if command -v codex >/dev/null 2>&1; then
        log_success "Codex CLI installed: $(command -v codex)"
    else
        log_warning "Codex package installed, but 'codex' is not currently on PATH."
    fi

    log_success "Node/npm tooling installed via nvm"
    log_info "For new shells, source this file from your bashrc/profile:"
    log_info "  source \"$nvm_env_file\""
}
