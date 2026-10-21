#!/usr/bin/env bash
set -Eeuo pipefail

git_lfs_linux_arch() {
    local machine

    if [ "$(uname -s)" != "Linux" ]; then
        log_warning "Git LFS tarball installation currently supports Linux release tarballs only."
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
            printf 'arm\n'
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
            log_warning "Unsupported Git LFS release architecture '$machine'."
            return 1
            ;;
    esac
}

install_git_lfs() {
    local install_method="${1:-${GIT_LFS_INSTALL_METHOD:-$GIT_LFS_INSTALL_METHOD_DEFAULT}}"
    local install_prefix="${GIT_LFS_INSTALL_PREFIX:-$HOME/.local}"

    : "${XDG_CACHE_HOME:=$HOME/.cache}"

    if ! command -v git >/dev/null 2>&1; then
        log_warning "git is required to install Git LFS."
        return 1
    fi

    mkdir -p "$install_prefix/bin"

    case "$install_method" in
        git|github)
            local git_ref="${GIT_LFS_GIT_REF:-main}"
            local source_dir="${GIT_LFS_SOURCE_DIR:-$SRC_DIR/git-lfs}"

            if ! command -v make >/dev/null 2>&1; then
                log_warning "make is required for GIT_LFS_INSTALL_METHOD=git."
                return 1
            fi

            if ! command -v go >/dev/null 2>&1; then
                log_warning "Go is required for GIT_LFS_INSTALL_METHOD=git."
                return 1
            fi

            log_info "Installing Git LFS from GitHub ref: $git_ref"
            clone_or_update "https://github.com/git-lfs/git-lfs.git" "$source_dir" "$git_ref" || return 1

            cd "$source_dir"
            make bin/git-lfs || return 1
            install -m 755 bin/git-lfs "$install_prefix/bin/git-lfs" || return 1
            ;;
        tar|tarball)
            local version="${GIT_LFS_VERSION}"
            local arch
            local cache_dir="${GIT_LFS_CACHE_DIR:-$XDG_CACHE_HOME/bootstrap/git-lfs}"
            local archive
            local source_dir
            local url

            arch=$(git_lfs_linux_arch) || return 1
            archive="$cache_dir/git-lfs-linux-${arch}-v${version}.tar.gz"
            source_dir="${GIT_LFS_TARBALL_DIR:-$SRC_DIR/git-lfs-${version}-linux-${arch}}"
            url="${GIT_LFS_TARBALL_URL:-https://github.com/git-lfs/git-lfs/releases/download/v${version}/git-lfs-linux-${arch}-v${version}.tar.gz}"

            mkdir -p "$cache_dir" "$source_dir"

            if [ ! -f "$archive" ]; then
                log_info "Downloading Git LFS release tarball: $url"
                download_file "$url" "$archive" || return 1
            fi

            if [ ! -x "$source_dir/git-lfs" ]; then
                if [ -z "$(find "$source_dir" -mindepth 1 -maxdepth 1 -print -quit)" ]; then
                    tar -xzf "$archive" -C "$source_dir" --strip-components=1 || return 1
                else
                    log_error "$source_dir exists but does not contain a Git LFS binary."
                    return 1
                fi
            fi

            install -m 755 "$source_dir/git-lfs" "$install_prefix/bin/git-lfs" || return 1

            if [ -d "$source_dir/man" ]; then
                mkdir -p "$install_prefix/share/man"
                cp -R "$source_dir/man/." "$install_prefix/share/man/" || return 1
            fi
            ;;
        *)
            log_error "Unknown GIT_LFS_INSTALL_METHOD='$install_method'. Use git or tar."
            return 1
            ;;
    esac

    export PATH="$install_prefix/bin:$PATH"
    hash -r 2>/dev/null || true

    if [ ! -x "$install_prefix/bin/git-lfs" ]; then
        log_warning "Git LFS install completed, but $install_prefix/bin/git-lfs was not found."
        return 1
    fi

    log_success "Git LFS installed at $install_prefix/bin/git-lfs"
    log_info "Git LFS filters are managed by config/git/config"
}
