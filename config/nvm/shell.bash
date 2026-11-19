# Activate an installed nvm selection without its expensive automatic scan.
# With system Node, keep npm global installs under ~/.local instead.
_dotfiles_activate_node() {
    local node_path version=default alias_value='' depth=0 bin
    node_path=$(command -v node) || node_path=''
    if [[ "$node_path" == "$NVM_DIR"/versions/node/*/bin/node && -x "$node_path" ]]; then
        bin=${node_path%/node}
    else
        while [[ -f "$NVM_DIR/alias/$version" ]]; do
            if (( depth >= 20 )); then return 1; fi
            alias_value=''
            if ! IFS= read -r alias_value < "$NVM_DIR/alias/$version" && [[ -z "$alias_value" ]]; then
                return 1
            fi
            version=${alias_value%%#*}
            version=${version//[[:space:]]/}
            (( depth += 1 ))
        done
        [[ "$version" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+$ ]] || return 1
        version="v${version#v}"
        bin="$NVM_DIR/versions/node/$version/bin"
        [[ -x "$bin/node" ]] || return 1
    fi
    case "$PATH:" in "$bin":*) ;; *) PATH="$bin:$PATH" ;; esac
    local man_dir="${bin%/bin}/share/man"
    case "${MANPATH:-}:" in "$man_dir":*) ;; *) MANPATH="$man_dir:${MANPATH:-}" ;; esac
    export PATH MANPATH NVM_BIN="$bin" NVM_INC="${bin%/bin}/include/node"
}

_dotfiles_setup_node() {
    local env_file="${XDG_CONFIG_HOME:-$HOME/.config}/nvm/env.sh" nvm_dir

    # A child shell may inherit our system-Node fallback. Remove only that
    # fallback before loading nvm, which rejects an explicit npm prefix.
    if [[ -n "${DOTFILES_NPM_FALLBACK_PREFIX:-}" ]]; then
        if [[ "${NPM_CONFIG_PREFIX:-}" == "$DOTFILES_NPM_FALLBACK_PREFIX" ]]; then
            unset NPM_CONFIG_PREFIX
        fi
        unset DOTFILES_NPM_FALLBACK_PREFIX
    fi

    if [[ -r "$env_file" ]]; then
        source "$env_file" --no-use
    else
        nvm_dir="${NVM_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/nvm}"
        if [[ -z "${NVM_DIR:-}" && ! -r "$nvm_dir/nvm.sh" && -r "$HOME/.nvm/nvm.sh" ]]; then
            nvm_dir="$HOME/.nvm"
        fi
        if [[ -r "$nvm_dir/nvm.sh" ]]; then
            export NVM_DIR="$nvm_dir"
            source "$NVM_DIR/nvm.sh" --no-use
        fi
    fi

    if [[ -n "${NVM_DIR:-}" && -r "$NVM_DIR/nvm.sh" ]]; then
        if ! _dotfiles_activate_node; then
            # Let nvm handle partial versions, implicit aliases, and .nvmrc.
            source "$NVM_DIR/nvm.sh"
        fi
    elif [[ -z "${NPM_CONFIG_PREFIX:-}${npm_config_prefix:-}" ]]; then
        # Export so programs such as Codex use the same prefix in npm children.
        export NPM_CONFIG_PREFIX="$HOME/.local"
        export DOTFILES_NPM_FALLBACK_PREFIX="$NPM_CONFIG_PREFIX"
    fi
}

_dotfiles_setup_node
