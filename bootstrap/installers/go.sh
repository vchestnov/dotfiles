#!/usr/bin/env bash
set -Eeuo pipefail

go_linux_arch() {
    local machine

    if [ "$(uname -s)" != "Linux" ]; then
        log_warning "Go toolchain tarball installation currently supports Linux only."
        return 1
    fi

    machine=$(uname -m)
    case "$machine" in
        x86_64|amd64)
            printf 'amd64\n'
            ;;
        i386|i686)
            printf '386\n'
            ;;
        aarch64|arm64)
            printf 'arm64\n'
            ;;
        armv6l|armv7l)
            printf 'armv6l\n'
            ;;
        ppc64le)
            printf 'ppc64le\n'
            ;;
        riscv64)
            printf 'riscv64\n'
            ;;
        s390x)
            printf 's390x\n'
            ;;
        loongarch64)
            printf 'loong64\n'
            ;;
        *)
            log_warning "Unsupported Go release architecture '$machine'."
            return 1
            ;;
    esac
}

install_go_toolchain() {
    local version="$GO_TOOLCHAIN_VERSION"
    local arch
    local toolchain_root
    local install_dir
    local current_link
    local cache_dir
    local archive
    local url
    local env_file
    local tmp_dir

    : "${XDG_CONFIG_HOME:=$HOME/.config}"
    : "${XDG_DATA_HOME:=$HOME/.local/share}"
    : "${XDG_CACHE_HOME:=$HOME/.cache}"

    arch=$(go_linux_arch) || return 1
    toolchain_root="${GO_TOOLCHAIN_ROOT:-$XDG_DATA_HOME/go-toolchains}"
    install_dir="${GO_TOOLCHAIN_INSTALL_DIR:-$toolchain_root/go${version}}"
    current_link="${GO_TOOLCHAIN_CURRENT:-$toolchain_root/current}"
    cache_dir="${GO_TOOLCHAIN_CACHE_DIR:-$XDG_CACHE_HOME/bootstrap/go}"
    archive="$cache_dir/go${version}.linux-${arch}.tar.gz"
    url="${GO_TOOLCHAIN_TARBALL_URL:-https://go.dev/dl/go${version}.linux-${arch}.tar.gz}"
    env_file="${GO_TOOLCHAIN_ENV_FILE:-$SCRIPT_DIR/config/go/env.sh}"

    mkdir -p "$toolchain_root" "$cache_dir" || return 1

    if [ ! -f "$archive" ]; then
        log_info "Downloading Go $version toolchain: $url"
        download_file "$url" "$archive" || return 1
    fi

    if [ -n "${GO_TOOLCHAIN_TARBALL_SHA256:-}" ]; then
        printf '%s  %s\n' "$GO_TOOLCHAIN_TARBALL_SHA256" "$archive" | sha256sum -c - || return 1
    fi

    if [ ! -x "$install_dir/bin/go" ]; then
        log_info "Installing Go $version to $install_dir"
        tmp_dir="$toolchain_root/.go-${version}.tmp.$$"
        rm -rf "$tmp_dir"
        mkdir -p "$tmp_dir" || return 1
        tar -xzf "$archive" -C "$tmp_dir" || return 1
        rm -rf "$install_dir"
        mv "$tmp_dir/go" "$install_dir" || return 1
        rmdir "$tmp_dir" 2>/dev/null || true
    else
        log_info "Go $version already installed at $install_dir"
    fi

    ln -sfn "$install_dir" "$current_link" || return 1

    # shellcheck disable=SC1090
    source "$env_file" || return 1
    hash -r 2>/dev/null || true

    if command -v go >/dev/null 2>&1; then
        log_success "Go toolchain active: $(go version)"
    else
        log_warning "Go toolchain installed, but go is not on PATH."
        return 1
    fi

    log_info "For new shells, source this file from your bashrc/profile:"
    log_info "  source \"\$XDG_CONFIG_HOME/go/env.sh\""
}
