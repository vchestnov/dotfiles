#!/usr/bin/env bash
set -Eeuo pipefail

leaf_linux_asset() {
    local machine

    if [ "$(uname -s)" != "Linux" ]; then
        log_warning "Leaf release binary installation currently supports Linux only."
        return 1
    fi

    machine=$(uname -m)
    case "$machine" in
        x86_64|amd64)
            printf 'leaf-linux-x86_64\n'
            ;;
        aarch64|arm64)
            printf 'leaf-linux-arm64\n'
            ;;
        *)
            log_warning "Unsupported Leaf release architecture '$machine'."
            return 1
            ;;
    esac
}

install_leaf() {
    local version="${LEAF_VERSION}"
    local install_dir="${LEAF_INSTALL_DIR:-$BIN_DIR}"
    local cache_dir="${LEAF_CACHE_DIR:-$XDG_CACHE_HOME/bootstrap/leaf/$version}"
    local asset
    local asset_path
    local checksums_path
    local release_url
    local expected_checksum
    local installed_output
    local installed_version

    asset=$(leaf_linux_asset) || return 1
    asset_path="$cache_dir/$asset"
    checksums_path="$cache_dir/checksums.txt"
    release_url="${LEAF_RELEASE_URL:-https://github.com/RivoLink/leaf/releases/download/$version}"

    if [ -x "$install_dir/leaf" ]; then
        if installed_output=$("$install_dir/leaf" --version 2>/dev/null); then
            installed_version=$(awk 'NR == 1 { print $2 }' <<< "$installed_output")
            if [ "$installed_version" = "$version" ]; then
                log_info "Leaf $version is already installed at $install_dir/leaf"
                return 0
            fi
        fi
    fi

    mkdir -p "$cache_dir" "$install_dir"

    if [ ! -f "$asset_path" ]; then
        log_info "Downloading Leaf $version release binary: $asset"
        download_file "$release_url/$asset" "$asset_path" || return 1
    fi

    if [ ! -f "$checksums_path" ]; then
        log_info "Downloading Leaf $version release checksums"
        download_file "$release_url/checksums.txt" "$checksums_path" || return 1
    fi

    expected_checksum=$(
        awk -v asset="$asset" '
            {
                name = $2
                sub(/^\*/, "", name)
                if (name == asset) {
                    print $1
                    exit
                }
            }
        ' "$checksums_path"
    )
    if [[ ! "$expected_checksum" =~ ^[[:xdigit:]]{64}$ ]]; then
        log_error "Leaf checksum entry not found or invalid for $asset"
        return 1
    fi

    log_info "Verifying Leaf $version release checksum"
    printf '%s  %s\n' "$expected_checksum" "$asset_path" | sha256sum -c - || return 1

    install -m 0755 "$asset_path" "$install_dir/leaf" || return 1

    if ! installed_output=$("$install_dir/leaf" --version 2>&1); then
        log_warning "Leaf was installed, but it could not be executed: $installed_output"
        return 1
    fi
    installed_version=$(awk 'NR == 1 { print $2 }' <<< "$installed_output")
    if [ "$installed_version" != "$version" ]; then
        log_warning "Expected Leaf $version after installation, got: $installed_output"
        return 1
    fi

    log_success "Leaf $version installed at $install_dir/leaf"
}
