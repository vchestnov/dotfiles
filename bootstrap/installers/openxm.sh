#!/usr/bin/env bash
set -Eeuo pipefail

install_openxm() {
    log_section "OPENXM + Risa/Asir INSTALLATION"

    local OPENXM_REPOS_DIR="${OPENXM_REPOS_DIR:-$SRC_DIR/openxm}"
    local OPENXM_REPO="$OPENXM_REPOS_DIR/OpenXM"
    local OPENXM_CONTRIB_REPO="$OPENXM_REPOS_DIR/OpenXM_contrib2"

    mkdir -p "$OPENXM_REPOS_DIR" "$BIN_DIR"

    # --- clone/update sources ---
    log_info "Cloning/updating OpenXM sources..."
    clone_or_update "https://github.com/openxm-org/OpenXM.git" "$OPENXM_REPO"
    clone_or_update "https://github.com/openxm-org/OpenXM_contrib2.git" "$OPENXM_CONTRIB_REPO"

    # OpenXM build expects contrib2 as a sibling directory (matches upstream instructions)
    # so we keep them under the same parent: ~/soft/openxm/{OpenXM,OpenXM_contrib2}
    cd "$OPENXM_REPO/src"

    # --- build/install (upstream flow) ---
    log_info "Building OpenXM (make configure; make install)..."
    # Make install is user-local in the tree; no sudo needed per upstream guidance.
    make install
    log_success "OpenXM built in $OPENXM_REPO"
    install_launcher_script "$SCRIPT_DIR/scripts/openxm" "$BIN_DIR/openxm"
    log_info "Use OpenXM_HOME=$OPENXM_REPO openxm asir."
}
