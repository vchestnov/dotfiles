#!/usr/bin/env bash
set -Eeuo pipefail

apply_profile() {
    ENABLED=()
    local component
    local -a defaults=()
    case "$BOOTSTRAP_PROFILE" in
        desktop)
            defaults=(
                core system-base fonts desktop-tools dwm tex gpg python-tools
                rust-tools tree-sitter zoxide eza dust tlrc duf procs leaf vim lsp neovim go git-lfs
                science sage polymake singular macaulay2 openxm node email zettelkasten
            )
            ;;
        server)
            defaults=(
                core rust-tools tree-sitter zoxide eza dust tlrc duf procs leaf vim lsp neovim go git-lfs
                science sage polymake openxm node email
            )
            ;;
        nothing) ;;
        test) defaults=(dwm) ;;
        *) log_error "Unknown profile '$BOOTSTRAP_PROFILE'."; return 2 ;;
    esac
    for component in "${defaults[@]}"; do set_component "$component" 1; done
    if [[ "$BOOTSTRAP_PROFILE" == server ]]; then set_component qd 0; fi
    for component in "${RISKY_COMPONENTS[@]}"; do
        if component_enabled "$component"; then
            log_error "Risky component $component cannot be a profile default"; return 2
        fi
    done
    if [[ "$BOOTSTRAP_PROFILE" == server ]]; then
        for component in "${COMPONENTS[@]}"; do
            if component_enabled "$component" && ${COMPONENT_SUDO[$component]}; then
                log_error "Server default $component requires sudo"; return 2
            fi
        done
    fi
}
