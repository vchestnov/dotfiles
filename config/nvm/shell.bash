# nvm's functions are loaded with --no-use by bashrc. Activate an already
# installed selection without running nvm's expensive automatic version scan.
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

if [[ -n "${NVM_DIR:-}" && -r "$NVM_DIR/nvm.sh" ]]; then
    if ! _dotfiles_activate_node; then
        # Let nvm handle partial versions, implicit aliases, and .nvmrc normally.
        source "$NVM_DIR/nvm.sh"
    fi
fi
