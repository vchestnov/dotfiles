#!/usr/bin/env bash
set -Eeuo pipefail

install_system_base() {
    log_section "SYSTEM PACKAGES UPDATE"

    log_info "Refreshing Ubuntu package metadata..."
    apt_refresh

    log_info "Installing system packages and build dependencies..."
    apt_install \
        build-essential \
        git \
        curl \
        wget \
        pkg-config \
        autoconf \
        automake \
        libtool \
        cmake \
        ninja-build \
        unzip \
        gettext \
        libboost-dev \
        libjson-perl \
        libperl-dev \
        libreadline-dev \
        libterm-readkey-perl \
        libterm-readline-gnu-perl \
        libxml-perl \
        libxml-sax-perl \
        libxml-writer-perl \
        libxml2-dev \
        libxslt1-dev \
        xclip \
        libx11-dev \
        libxt-dev \
        libxpm-dev \
        libxext-dev \
        x11proto-dev \
        libxft-dev \
        libxinerama-dev \
        libfreetype6-dev \
        fontconfig \
        libfontconfig1-dev \
        libharfbuzz-dev \
        libxrandr-dev \
        libimlib2-dev \
        libxss-dev \
        libjpeg-dev \
        libpng-dev \
        libtiff-dev \
        zlib1g-dev \
        libncurses5-dev \
        libncursesw5-dev \
        lua5.1 \
        liblua5.1-0-dev \
        python3-dev \
        ruby-dev \
        tcl-dev \
        mupdf-tools \
        libmupdf-dev \
        libpoppler-glib-dev \
        libmagic-dev \
        tmux \
        htop \
        efivar \
        bluetooth \
        bluez \
        bluez-tools \
        rfkill \
        blueman \
        libxcb-cursor0 \
        lm-sensors \
        rename \
        python3-full \
        acpi \
        picom \
        meson \
        libgtk-3-dev \
        libgirara-dev \
        libsqlite3-dev \
        libsynctex-dev \
        libjson-glib-dev \
        libdjvulibre-dev \
        ncal \
        qpdf \
        pipx \
        brightnessctl \
        libxcb-xtest0 \
        pavucontrol \
        libboost-all-dev \
        libxapian-dev \
        libgmime-3.0-dev \
        libtalloc-dev

    log_success "System packages and build dependencies installed"
}

remove_nautilus() {
    log_section "NAUTILUS REMOVAL"

    # Remove Ubuntu file manager (Nautilus)
    log_info "Removing Ubuntu file manager (Nautilus)..."
    refresh_sudo
    sudo apt remove -y nautilus nautilus-extension-gnome-terminal
    log_success "Ubuntu file manager removed"
}

upgrade_system() {
    log_warning "Applying explicitly requested full system upgrade"
    apt_refresh
    refresh_sudo
    sudo apt upgrade -y
}
