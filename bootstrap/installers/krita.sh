#!/usr/bin/env bash
set -Eeuo pipefail

install_krita() {
    local KRITA_BASE_URL KRITA_DIR KRITA_APPIMAGE_NAME KRITA_APPIMAGE_URL KRITA_APPIMAGE_PATH
    log_section "KRITA INSTALLATION"

    log_info "Installing Krita via AppImage..."

    KRITA_BASE_URL="https://download.kde.org/stable/krita"

    KRITA_DIR="$HOME/soft/krita"
    mkdir -p "$KRITA_DIR" "$BIN_DIR"

    KRITA_APPIMAGE_NAME="krita-${KRITA_VERSION}-x86_64.AppImage"
    KRITA_APPIMAGE_URL="${KRITA_BASE_URL}/${KRITA_VERSION}/${KRITA_APPIMAGE_NAME}"
    KRITA_APPIMAGE_PATH="${KRITA_DIR}/${KRITA_APPIMAGE_NAME}"

    # AppImages commonly require FUSE2 on Ubuntu; install if missing
    if ! ldconfig -p 2>/dev/null | grep -q 'libfuse\.so\.2'; then
        log_info "Installing FUSE2 runtime needed by many AppImages..."
        refresh_sudo
        if ! apt_install libfuse2 && ! apt_install libfuse2t64; then
            component_incomplete "Could not install the FUSE2 runtime needed by this AppImage."
        fi
    fi

    if [[ -f "$KRITA_APPIMAGE_PATH" ]]; then
        log_info "Krita AppImage already present: $KRITA_APPIMAGE_PATH"
    else
        log_info "Downloading Krita ${KRITA_VERSION} AppImage..."
        curl -fL --retry 3 --retry-delay 2 -o "$KRITA_APPIMAGE_PATH" "$KRITA_APPIMAGE_URL"
        chmod +x "$KRITA_APPIMAGE_PATH"
    fi

    # Create/update a stable symlink "krita.AppImage" and a launcher in PATH
    ln -sf "$KRITA_APPIMAGE_PATH" "${KRITA_DIR}/krita.AppImage"
    ln -sf "${KRITA_DIR}/krita.AppImage" "$BIN_DIR/krita"

    log_success "Krita installed (AppImage). Run: krita"
    log_info "Installed at: ${KRITA_APPIMAGE_PATH}"
    log_info "To update, set KRITA_VERSION explicitly and re-run this component."
}
