#!/usr/bin/env bash
set -Eeuo pipefail

configure_make_install() {
    local project_name=$1
    local source_dir=$2
    local install_prefix=$3
    shift 3
    local jobs="${BUILD_JOBS:-$(default_build_jobs)}"

    cd "$source_dir"
    if [ -x ./autogen.sh ] && [ ! -x ./configure ]; then
        ./autogen.sh
    fi
    if [ -f configure.ac ] && [ ! -x ./configure ]; then
        autoreconf -fi
    fi
    if [ ! -x ./configure ]; then
        log_error "$project_name source tree does not provide a usable ./configure script."
        return 1
    fi

    ./configure --prefix="$install_prefix" "$@"
    BUILD_JOBS="$jobs" build_and_install "$project_name"
}

install_notmuch_from_source() {
    local install_prefix="${1:-$HOME/.local}"
    local source_dir="${NOTMUCH_SOURCE_DIR:-$SRC_DIR/notmuch}"
    local source_kind="${NOTMUCH_INSTALL_METHOD:-tar}"
    local archive_version="${NOTMUCH_VERSION}"
    local archive_path="$SRC_DIR/notmuch-${archive_version}.tar.xz"
    local archive_url="${NOTMUCH_TARBALL_URL:-https://notmuchmail.org/releases/notmuch-${archive_version}.tar.xz}"

    mkdir -p "$SRC_DIR" "$install_prefix"

    case "$source_kind" in
        git|github)
            clone_or_update "https://git.notmuchmail.org/git/notmuch" "$source_dir"
            ;;
        tar|tarball)
            prepare_source_from_tarball \
                "$archive_url" \
                "$archive_path" \
                "$source_dir" \
                "$source_dir/configure"
            ;;
        *)
            log_error "Unknown NOTMUCH_INSTALL_METHOD='$source_kind'. Use git or tar."
            return 1
            ;;
    esac

    configure_make_install "notmuch" "$source_dir" "$install_prefix"
}

install_isync_from_source() {
    local install_prefix="${1:-$HOME/.local}"
    local source_dir="${ISYNC_SOURCE_DIR:-$SRC_DIR/isync}"
    local source_kind="${ISYNC_INSTALL_METHOD:-tar}"
    local archive_version="${ISYNC_VERSION}"
    local archive_path="$SRC_DIR/isync-${archive_version}.tar.gz"
    local archive_url="${ISYNC_TARBALL_URL:-https://downloads.sourceforge.net/project/isync/isync/${archive_version}/isync-${archive_version}.tar.gz}"

    mkdir -p "$SRC_DIR" "$install_prefix"

    case "$source_kind" in
        git|github)
            clone_or_update "https://git.code.sf.net/p/isync/isync" "$source_dir"
            ;;
        tar|tarball)
            prepare_source_from_tarball \
                "$archive_url" \
                "$archive_path" \
                "$source_dir" \
                "$source_dir/configure"
            ;;
        *)
            log_error "Unknown ISYNC_INSTALL_METHOD='$source_kind'. Use git or tar."
            return 1
            ;;
    esac

    configure_make_install "isync/mbsync" "$source_dir" "$install_prefix"
}

install_msmtp_from_source() {
    local install_prefix="${1:-$HOME/.local}"
    local source_dir="${MSMTP_SOURCE_DIR:-$SRC_DIR/msmtp}"
    local source_kind="${MSMTP_INSTALL_METHOD:-tar}"
    local archive_version="${MSMTP_VERSION}"
    local archive_path="$SRC_DIR/msmtp-${archive_version}.tar.xz"
    local archive_url="${MSMTP_TARBALL_URL:-https://marlam.de/msmtp/releases/msmtp-${archive_version}.tar.xz}"

    mkdir -p "$SRC_DIR" "$install_prefix"

    case "$source_kind" in
        git|github)
            clone_or_update "https://git.marlam.de/git/msmtp.git" "$source_dir"
            ;;
        tar|tarball)
            prepare_source_from_tarball \
                "$archive_url" \
                "$archive_path" \
                "$source_dir" \
                "$source_dir/configure"
            ;;
        *)
            log_error "Unknown MSMTP_INSTALL_METHOD='$source_kind'. Use git or tar."
            return 1
            ;;
    esac

    configure_make_install "msmtp" "$source_dir" "$install_prefix"
}

install_neomutt_from_source() {
    local install_prefix="${1:-$HOME/.local}"
    local source_dir="${NEOMUTT_SOURCE_DIR:-$SRC_DIR/neomutt}"
    local source_kind="${NEOMUTT_INSTALL_METHOD:-git}"
    local git_ref="${NEOMUTT_GIT_REF:-}"
    local archive_ref="${NEOMUTT_VERSION}"
    local archive_tag="${archive_ref//-/}"
    local archive_path="$SRC_DIR/neomutt-${archive_tag}.tar.gz"
    local archive_url="${NEOMUTT_TARBALL_URL:-https://github.com/neomutt/neomutt/archive/refs/tags/${archive_tag}.tar.gz}"
    local pkg_config_path="${PKG_CONFIG_PATH:-}"
    local -a configure_args=(--disable-doc)

    mkdir -p "$SRC_DIR" "$install_prefix"

    case "$source_kind" in
        git|github)
            if [ -n "$git_ref" ]; then
                clone_or_update "https://github.com/neomutt/neomutt.git" "$source_dir" "$git_ref"
            else
                clone_or_update "https://github.com/neomutt/neomutt.git" "$source_dir"
            fi
            ;;
        tar|tarball)
            prepare_source_from_tarball \
                "$archive_url" \
                "$archive_path" \
                "$source_dir" \
                "$source_dir/configure"
            ;;
        *)
            log_error "Unknown NEOMUTT_INSTALL_METHOD='$source_kind'. Use git or tar."
            return 1
            ;;
    esac

    if [ -d "$install_prefix/lib/pkgconfig" ]; then
        export PKG_CONFIG_PATH="$install_prefix/lib/pkgconfig${pkg_config_path:+:$pkg_config_path}"
    fi

    if command -v pkg-config >/dev/null 2>&1 && pkg-config --exists notmuch; then
        configure_args+=(--notmuch)
    fi

    if command -v pkg-config >/dev/null 2>&1 && ! pkg-config --exists libidn2; then
        log_info "libidn2 not found; building NeoMutt without IDN support"
        configure_args+=(--disable-idn2)
    fi

    configure_make_install "NeoMutt" "$source_dir" "$install_prefix" "${configure_args[@]}"
}

install_email() {
    local ISYNC_CONFIG_PATH MAILDIR_ROOT MAIL_INSTALL_PREFIX MAIL_SOURCE_ROOT MSMTP_CONFIG_DIR NEOMUTT_CONFIG_DIR NOTMUCH_CONFIG_DIR NOTMUCH_PROFILE missing_mail_build_tools
    log_section "TERMINAL MAIL STACK"

    : "${XDG_CONFIG_HOME:=$HOME/.config}"
    : "${XDG_DATA_HOME:=$HOME/.local/share}"
    : "${XDG_CACHE_HOME:=$HOME/.cache}"
    : "${XDG_STATE_HOME:=$HOME/.local/state}"

    MAIL_INSTALL_PREFIX="${MAIL_INSTALL_PREFIX:-$HOME/.local}"
    MAIL_SOURCE_ROOT="${MAIL_SOURCE_ROOT:-$SRC_DIR/mail}"
    MAILDIR_ROOT="${MAILDIR:-$XDG_DATA_HOME/mail}"
    NOTMUCH_PROFILE="${NOTMUCH_PROFILE:-default}"
    NOTMUCH_CONFIG_DIR="${XDG_CONFIG_HOME}/notmuch/${NOTMUCH_PROFILE}"
    MSMTP_CONFIG_DIR="${XDG_CONFIG_HOME}/msmtp"
    ISYNC_CONFIG_PATH="${XDG_CONFIG_HOME}/isyncrc"
    NEOMUTT_CONFIG_DIR="${XDG_CONFIG_HOME}/neomutt"

    mkdir -p \
        "$MAIL_INSTALL_PREFIX/bin" \
        "$MAIL_SOURCE_ROOT" \
        "$XDG_CACHE_HOME/mail" \
        "$XDG_STATE_HOME/mail" \
        "$MAILDIR_ROOT" \
        "$NOTMUCH_CONFIG_DIR" \
        "$MSMTP_CONFIG_DIR" \
        "$NEOMUTT_CONFIG_DIR"

    export PKG_CONFIG_PATH="$MAIL_INSTALL_PREFIX/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
    export PATH="$MAIL_INSTALL_PREFIX/bin:$PATH"
    export NOTMUCH_CONFIG="${NOTMUCH_CONFIG:-$NOTMUCH_CONFIG_DIR/config}"
    export MSMTP_CONFIG="${MSMTP_CONFIG:-$MSMTP_CONFIG_DIR/config}"
    export NOTMUCH_SOURCE_DIR="${NOTMUCH_SOURCE_DIR:-$MAIL_SOURCE_ROOT/notmuch}"
    export ISYNC_SOURCE_DIR="${ISYNC_SOURCE_DIR:-$MAIL_SOURCE_ROOT/isync}"
    export MSMTP_SOURCE_DIR="${MSMTP_SOURCE_DIR:-$MAIL_SOURCE_ROOT/msmtp}"
    export NEOMUTT_SOURCE_DIR="${NEOMUTT_SOURCE_DIR:-$MAIL_SOURCE_ROOT/neomutt}"

    missing_mail_build_tools=()
    for required_cmd in cc make pkg-config; do
        if ! command -v "$required_cmd" >/dev/null 2>&1; then
            missing_mail_build_tools+=("$required_cmd")
        fi
    done

    if [ "${#missing_mail_build_tools[@]}" -gt 0 ]; then
        skip_component "Missing build tools: ${missing_mail_build_tools[*]}; install them and rerun email."
        return 0
    else
        install_notmuch_from_source "$MAIL_INSTALL_PREFIX"
        install_isync_from_source "$MAIL_INSTALL_PREFIX"
        install_msmtp_from_source "$MAIL_INSTALL_PREFIX"
        install_neomutt_from_source "$MAIL_INSTALL_PREFIX"
        hash -r
    fi

    log_info "XDG mail paths:"
    log_info "  Maildir root: $MAILDIR_ROOT"
    log_info "  NeoMutt config: $NEOMUTT_CONFIG_DIR/neomuttrc"
    log_info "  isync config: $ISYNC_CONFIG_PATH"
    log_info "  msmtp config: $MSMTP_CONFIG"
    log_info "  notmuch config: $NOTMUCH_CONFIG"
}
