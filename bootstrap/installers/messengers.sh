#!/usr/bin/env bash
set -Eeuo pipefail

install_messengers() {
    log_section "MESSENGERS INSTALLATION"
    refresh_sudo

    # Create temporary directory for downloads
    TEMP_DIR=$(mktemp -d)
    if [[ ! -d "$TEMP_DIR" ]]; then
        log_error "Failed to create temporary directory"
        return 1
    fi

    # Cleanup function
    cleanup_temp() {
        if [[ -d "$TEMP_DIR" ]]; then
            rm -rf "$TEMP_DIR"
            log_info "Cleaned up temporary files"
        fi
    }

    # Set trap to cleanup on exit
    trap cleanup_temp EXIT

    # =============================================================================
    # ZULIP SETUP
    # =============================================================================
    log_info "Setting up Zulip Desktop APT repository..."

    # Download Zulip signing key
    sudo curl -fL -o /etc/apt/trusted.gpg.d/zulip-desktop.asc https://download.zulip.com/desktop/apt/zulip-desktop.asc

    # Add Zulip repository
    echo "deb https://download.zulip.com/desktop/apt stable main" | sudo tee /etc/apt/sources.list.d/zulip-desktop.list > /dev/null

    log_success "Zulip repository configured"

    # =============================================================================
    # SIGNAL SETUP
    # =============================================================================
    log_info "Setting up Signal Desktop APT repository..."

    # Install Signal's official software signing key
    wget -O- https://updates.signal.org/desktop/apt/keys.asc | gpg --dearmor > "$TEMP_DIR/signal-desktop-keyring.gpg"

    sudo mv "$TEMP_DIR/signal-desktop-keyring.gpg" /usr/share/keyrings/signal-desktop-keyring.gpg

    # Add Signal's repository
    echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/signal-desktop-keyring.gpg] https://updates.signal.org/desktop/apt xenial main' | \
        sudo tee /etc/apt/sources.list.d/signal-xenial.list > /dev/null

    log_success "Signal repository configured"

    # =============================================================================
    # TELEGRAM DOWNLOAD
    # =============================================================================
    log_info "Downloading Telegram Desktop..."

    # Get the latest Telegram download URL
    TELEGRAM_URL="https://telegram.org/dl/desktop/linux"
    TELEGRAM_FILE="$TEMP_DIR/telegram.tar.xz"

    # Download Telegram
    wget -O "$TELEGRAM_FILE" "$TELEGRAM_URL"

    # Verify the download is a valid tar.xz file
    if ! file "$TELEGRAM_FILE" | grep -q "XZ compressed data"; then
        log_error "Downloaded Telegram file is not a valid XZ archive"
        return 1
    fi

    log_success "Telegram downloaded successfully"

    # =============================================================================
    # SLACK DOWNLOAD
    # =============================================================================
    log_info "Downloading Slack Desktop..."

	# Slack requires a more sophisticated approach due to redirects
    # We'll use curl with follow redirects and proper headers
    SLACK_FILE="$TEMP_DIR/slack.deb"

    # Try direct download first (may be outdated but worth trying)
    DOWNLOAD_SUCCESS=false
    if curl -fL -A "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36" \
         -o "$SLACK_FILE" \
         "https://downloads.slack-edge.com/releases/linux/4.40.126/prod/x64/slack-desktop-4.40.126-amd64.deb" \
         && file "$SLACK_FILE" | grep -q "Debian binary package"; then
        DOWNLOAD_SUCCESS=true
        log_success "Direct download succeeded"
    else
        log_warning "Direct download failed or file is not a valid DEB package, trying alternative method..."

        # Remove invalid file if it exists
        [[ -f "$SLACK_FILE" ]] && rm -f "$SLACK_FILE"

        # Get the actual download URL from Slack's download page
        log_info "Parsing Slack download page for current version..."
        SLACK_DOWNLOAD_URL=$(curl -s "https://slack.com/intl/en-gb/downloads/instructions/linux?build=deb" | \
                           grep -o 'https://downloads\.slack-edge\.com[^"]*\.deb' | \
                           head -1)

        if [[ -n "$SLACK_DOWNLOAD_URL" ]]; then
            log_info "Found download URL: $SLACK_DOWNLOAD_URL"
            curl -L -A "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36" \
                 -o "$SLACK_FILE" \
                 "$SLACK_DOWNLOAD_URL"


            # Verify this download is valid
            if file "$SLACK_FILE" | grep -q "Debian binary package"; then
                DOWNLOAD_SUCCESS=true
                log_success "Alternative download succeeded"
            else
                log_error "Downloaded file is still not a valid DEB package"
                return 1
            fi
        else
            log_error "Could not find Slack download URL from download page"
            return 1
        fi
    fi

    # Final verification
    if [[ "$DOWNLOAD_SUCCESS" != "true" ]]; then
        log_error "Failed to download valid Slack DEB package"
        return 1
    fi

    log_success "Slack downloaded and verified successfully"

    # =============================================================================
    # APT UPDATE AND INSTALL
    # =============================================================================
    log_info "Updating APT package lists..."
    apt_refresh force

    log_info "Installing Zulip and Signal from repositories..."
    apt_install zulip signal-desktop

    log_success "Repository-based messengers installed"

    # =============================================================================
    # TELEGRAM INSTALLATION
    # =============================================================================
    log_info "Installing Telegram Desktop..."

    # Create directories if they don't exist
    mkdir -p "$HOME/soft" "$HOME/.local/bin"

    # Extract Telegram to user's software directory
    tar -xf "$TELEGRAM_FILE" -C "$HOME/soft/"

    # Create symbolic link in user's local bin
    ln -sf "$HOME/soft/Telegram/Telegram" "$HOME/.local/bin/telegram"

    log_success "Telegram Desktop installed to $HOME/soft/Telegram/"

    # =============================================================================
    # SLACK INSTALLATION
    # =============================================================================
    log_info "Installing Slack Desktop..."

    # Install the DEB package
    apt_install "$SLACK_FILE"

    log_success "Slack Desktop installed"

    # =============================================================================
    # VERIFICATION
    # =============================================================================
    log_info "Verifying installations..."

    # Check if applications are installed and accessible
    APPS=("zulip" "signal-desktop" "telegram" "slack")
    FAILED_APPS=()

    for app in "${APPS[@]}"; do
        # Check both system PATH and user's local bin
        if ! command -v "$app" &> /dev/null && ! [[ -x "$HOME/.local/bin/$app" ]]; then
            FAILED_APPS+=("$app")
        fi
    done

    if [[ ${#FAILED_APPS[@]} -eq 0 ]]; then
        log_success "All messengers installed and verified successfully"
        log_info "Installed applications:"
        log_info "  - Zulip Desktop (system-wide)"
        log_info "  - Signal Desktop (system-wide)"
        log_info "  - Telegram Desktop (user: $HOME/soft/Telegram/)"
        log_info "  - Slack Desktop (system-wide)"
        log_info ""
        log_info "Make sure $HOME/.local/bin is in your PATH to access telegram command"
    else
        component_incomplete "Missing messenger binaries: ${FAILED_APPS[*]}"
        log_info "You may need to add $HOME/.local/bin to your PATH or check the installation"
    fi

    cleanup_temp
    trap - EXIT
    log_success "Messengers installation completed"
}
