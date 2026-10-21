#!/usr/bin/env bash
set -Eeuo pipefail

setup_polymake_xdg_environment() {
    : "${XDG_CONFIG_HOME:=$HOME/.config}"
    : "${XDG_DATA_HOME:=$HOME/.local/share}"
    : "${XDG_CACHE_HOME:=$HOME/.cache}"
    : "${XDG_STATE_HOME:=$HOME/.local/state}"

    export POLYMAKE_USER_DIR="${POLYMAKE_USER_DIR:-$XDG_CONFIG_HOME/polymake/user}"
    export POLYMAKE_CONFIG_PATH="${POLYMAKE_CONFIG_PATH:-user=$POLYMAKE_USER_DIR}"

    mkdir -p \
        "$POLYMAKE_USER_DIR" \
        "$XDG_CACHE_HOME/polymake" \
        "$XDG_STATE_HOME/polymake"
}

detect_polymake_dependency_prefix() {
    local candidate

    for candidate in \
        "${POLYMAKE_DEPS_PREFIX:-}" \
        "$HOME/.local" \
        "$HOME/soft/openxm/OpenXM" \
        ; do
        [ -n "$candidate" ] || continue
        if [ -f "$candidate/include/mpfr.h" ] && { [ -f "$candidate/lib/libmpfr.so" ] || [ -f "$candidate/lib/libmpfr.a" ]; }; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done

    return 1
}

build_and_install_polymake() {
    local source_dir=$1
    local prefix="${POLYMAKE_PREFIX:-$HOME/.local}"
    local jobs="${POLYMAKE_JOBS:-${BUILD_JOBS:-$(default_build_jobs)}}"
    local build_dir="${POLYMAKE_BUILD_DIR:-build/Opt}"
    local configure_args=("--prefix=$prefix")
    local extra_args=()
    local deps_prefix

    setup_polymake_xdg_environment
    mkdir -p "$prefix"

    if [ "${POLYMAKE_WITH_JAVA:-0}" != "1" ]; then
        configure_args+=("--without-java")
    fi

    if deps_prefix=$(detect_polymake_dependency_prefix); then
        log_info "Using polymake dependency prefix: $deps_prefix"
        export CPPFLAGS="-I$deps_prefix/include${CPPFLAGS:+ $CPPFLAGS}"
        export LDFLAGS="-L$deps_prefix/lib${LDFLAGS:+ $LDFLAGS}"
        export LD_LIBRARY_PATH="$deps_prefix/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
        if [ -d "$deps_prefix/lib/pkgconfig" ]; then
            export PKG_CONFIG_PATH="$deps_prefix/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
        fi

        if [ -f "$deps_prefix/include/gmp.h" ]; then
            configure_args+=("--with-gmp=$deps_prefix")
        fi

        if [ -f "$deps_prefix/include/mpfr.h" ]; then
            configure_args+=("--with-mpfr=$deps_prefix")
        fi

        if [ -d "$deps_prefix/include/boost" ]; then
            configure_args+=("--with-boost=$deps_prefix")
        fi

    else
        log_warning "Could not find a local MPFR development prefix; polymake configure may fail."
        log_warning "Set POLYMAKE_DEPS_PREFIX to a prefix containing include/mpfr.h and lib/libmpfr.so."
    fi

    if [ -n "${POLYMAKE_CONFIGURE_EXTRA:-}" ]; then
        # shellcheck disable=SC2206
        extra_args=(${POLYMAKE_CONFIGURE_EXTRA})
    fi

    cd "$source_dir"
    log_info "Configuring polymake in $source_dir"
    ./configure "${configure_args[@]}" "${extra_args[@]}"

    if [ ! -f "$build_dir/build.ninja" ]; then
        log_error "polymake ninja build file not found at $source_dir/$build_dir/build.ninja"
        return 1
    fi

    log_info "Building polymake with $jobs parallel jobs"
    ninja -C "$build_dir" -j"$jobs" all
    ninja -C "$build_dir" install

    if [ -x "$prefix/bin/polymake" ]; then
        log_success "polymake installed to $prefix/bin/polymake"
    else
        log_warning "polymake build finished, but $prefix/bin/polymake was not found."
        return 1
    fi
}

install_polymake_from_github() {
    local repo_url="${POLYMAKE_REPO_URL:-https://github.com/polymake/polymake.git}"
    local git_ref="${POLYMAKE_GIT_REF:-}"
    local source_dir="${POLYMAKE_SRC_DIR:-$SRC_DIR/polymake}"

    log_info "Installing polymake from GitHub mirror"
    if [ -n "$git_ref" ]; then
        clone_or_update "$repo_url" "$source_dir" "$git_ref"
    else
        clone_or_update "$repo_url" "$source_dir"
    fi

    build_and_install_polymake "$source_dir"
}

install_polymake_from_tarball() {
    local version="${POLYMAKE_VERSION}"
    local tag="${POLYMAKE_TARBALL_TAG:-V${version}}"
    local archive="$SRC_DIR/polymake-${version}.tar.gz"
    local source_dir="${POLYMAKE_SRC_DIR:-$SRC_DIR/polymake-${version}}"
    local url="${POLYMAKE_TARBALL_URL:-https://github.com/polymake/polymake/archive/refs/tags/${tag}.tar.gz}"

    mkdir -p "$SRC_DIR" "$source_dir"

    if [ ! -f "$archive" ]; then
        log_info "Downloading polymake source tarball: $url"
        download_file "$url" "$archive"
    fi

    if [ ! -f "$source_dir/configure" ]; then
        if [ -z "$(find "$source_dir" -mindepth 1 -maxdepth 1 -print -quit)" ]; then
            tar -xf "$archive" -C "$source_dir" --strip-components=1
        else
            log_error "$source_dir exists but does not contain a polymake configure script."
            return 1
        fi
    fi

    build_and_install_polymake "$source_dir"
}

install_polymake() {
    setup_science_environment
    log_section "POLYMAKE INSTALLATION"

    POLYMAKE_INSTALL_METHOD="${POLYMAKE_INSTALL_METHOD:-git}"
    log_info "polymake installation method: $POLYMAKE_INSTALL_METHOD"

    case "$POLYMAKE_INSTALL_METHOD" in
        git|github)
            install_polymake_from_github
            ;;
        tar|tarball)
            install_polymake_from_tarball
            ;;
        *)
            log_error "Unknown POLYMAKE_INSTALL_METHOD='$POLYMAKE_INSTALL_METHOD'. Use git or tar."
            return 1
            ;;
    esac
}
