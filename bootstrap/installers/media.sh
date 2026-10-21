#!/usr/bin/env bash
set -Eeuo pipefail

install_media() {
    log_section "MEDIA SOFTWARE INSTALLATION"

	curl -sS https://download.spotify.com/debian/pubkey_C85668DF69375001.gpg | sudo gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/spotify.gpg
	echo "deb https://repository.spotify.com stable non-free" | sudo tee /etc/apt/sources.list.d/spotify.list

    # Update system packages
    log_info "Updating system packages..."
    refresh_sudo
    apt_refresh force

	apt_install \
		spotify-client

    log_info "Installing media software from repositories..."
}
