#!/usr/bin/env bash
set -Eeuo pipefail

install_tex() {
    local tex_root="${TEXLIVE_ROOT:-$SRC_DIR/texlive}"
    local tex_dir="${TEXLIVE_INSTALL_DIR:-$tex_root/2025}"
    local archive="$XDG_CACHE_HOME/bootstrap/downloads/install-tl-unx.tar.gz"
    local installer_dir

    apt_install wget perl-tk fontconfig
    mkdir -p "$(dirname "$archive")" "$BUILD_DIR"
    download_file "https://mirror.ctan.org/systems/texlive/tlnet/install-tl-unx.tar.gz" "$archive"
    installer_dir=$(mktemp -d "$BUILD_DIR/texlive.XXXXXX")
    tar -xzf "$archive" -C "$installer_dir" --strip-components=1

    write_generated_file "$installer_dir/texlive.profile" << EOF
# TeX Live installation profile
# This profile installs TeX Live to $tex_root
selected_scheme scheme-full
# Install tree (per-user)
TEXDIR $tex_dir

# Per-user config/cache → XDG
TEXMFCONFIG $XDG_CONFIG_HOME/texlive/texmf-config
TEXMFVAR    $XDG_CACHE_HOME/texlive/texmf-var

# User data tree (where your own sty/cls live)
TEXMFHOME   $XDG_DATA_HOME/texmf

# System-like trees kept under your TEXDIR (no root needed)
TEXMFSYSCONFIG $tex_dir/texmf-config
TEXMFSYSVAR    $tex_dir/texmf-var
TEXMFLOCAL     $tex_root/texmf-local
binary_x86_64-linux 1
instopt_adjustpath 0
instopt_adjustrepo 1
instopt_letter 0
instopt_portable 0
instopt_write18_restricted 1
tlpdbopt_autobackup 1
tlpdbopt_backupdir tlpkg/backups
tlpdbopt_create_formats 1
tlpdbopt_desktop_integration 1
tlpdbopt_file_assocs 1
tlpdbopt_generate_updmap 0
tlpdbopt_install_docfiles 1
tlpdbopt_install_srcfiles 1
tlpdbopt_post_code 1
tlpdbopt_sys_bin /usr/local/bin
tlpdbopt_sys_info /usr/local/share/info
tlpdbopt_sys_man /usr/local/share/man
tlpdbopt_w32_multi_user 1
EOF

    "$installer_dir/install-tl" \
        --repository="${TEXLIVE_REPOSITORY:-https://mirror.ox.ac.uk/sites/ctan.org/systems/texlive/tlnet}" \
        --profile="$installer_dir/texlive.profile" --no-interaction
    log_success "TeX Live installed in $tex_dir"
    log_info "Shell configuration is provided by config/texlive-env.sh."
}
