#!/usr/bin/env bash
set -Eeuo pipefail

install_julia() {
    setup_science_environment
    install_julia_from_tarball "$SCI_PREFIX" "$SCI_REPOS_DIR"
}

install_julia_from_tarball() {
    local install_prefix="${1:-$HOME/.local}"
    local repos_dir="${2:-$HOME/soft}"
    local version="${JULIA_VERSION}"
    local series="${JULIA_SERIES:-${version%.*}}"
    local machine
    local arch
    local arch_dir
    local archive
    local archive_path
    local install_dir
    local current_link
    local url

    machine=$(uname -m)
    case "$machine" in
        x86_64|amd64)
            arch="x86_64"
            arch_dir="x64"
            ;;
        aarch64|arm64)
            arch="aarch64"
            arch_dir="aarch64"
            ;;
        *)
            log_warning "Unsupported Julia architecture '$machine'. Set JULIA_TARBALL_URL manually if you want to install Julia."
            return 1
            ;;
    esac

    archive="julia-${version}-linux-${arch}.tar.gz"
    archive_path="$SRC_DIR/$archive"
    install_dir="${JULIA_INSTALL_DIR:-$repos_dir/julia-$version}"
    current_link="${JULIA_CURRENT_LINK:-$repos_dir/julia}"
    url="${JULIA_TARBALL_URL:-https://julialang-s3.julialang.org/bin/linux/${arch_dir}/${series}/${archive}}"

    mkdir -p "$SRC_DIR" "$repos_dir" "$install_prefix/bin"

    log_info "Downloading Julia ${version} from $url"
    download_file "$url" "$archive_path"

    rm -rf "$install_dir"
    mkdir -p "$install_dir"
    tar -xzf "$archive_path" -C "$install_dir" --strip-components=1

    ln -sfn "$install_dir" "$current_link"
    ln -sfn "$install_dir/bin/julia" "$install_prefix/bin/julia"

    if [ -x "$install_prefix/bin/julia" ]; then
        log_success "Julia installed to $install_dir"
        log_info "Julia launcher available at $install_prefix/bin/julia"
        return 0
    fi

    log_warning "Julia install finished, but $install_prefix/bin/julia was not found."
    return 1
}
