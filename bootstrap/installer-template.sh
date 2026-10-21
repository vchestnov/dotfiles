#!/usr/bin/env bash
set -Eeuo pipefail

# Copy to installers/example.sh. Add EXAMPLE_VERSION to versions.sh and register
# install_example in components.sh. Nothing runs when this file is sourced.
install_example() {
    local prefix="$HOME/.local"
    local source_dir="$SRC_DIR/example-$EXAMPLE_VERSION"
    local archive="$XDG_CACHE_HOME/bootstrap/downloads/example-$EXAMPLE_VERSION.tar.gz"
    local url="https://example.org/releases/example-$EXAMPLE_VERSION.tar.gz"

    prepare_source_from_tarball "$url" "$archive" "$source_dir" "$source_dir/configure"
    cd "$source_dir"
    ./configure --prefix="$prefix"
    build_and_install "Example"
}
