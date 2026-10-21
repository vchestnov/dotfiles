#!/usr/bin/env bash
set -Eeuo pipefail

detect_ntl_prefix() {
    local candidate

    for candidate in \
        "${SINGULAR_NTL_PREFIX:-}" \
        "${SCI_PREFIX:-}" \
        "$HOME/.local" \
        ; do
        [ -n "$candidate" ] || continue
        if [ -f "$candidate/include/NTL/ZZ.h" ] && { [ -f "$candidate/lib/libntl.so" ] || [ -f "$candidate/lib/libntl.a" ]; }; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done

    return 1
}

apply_singular_flint_compat_patch() {
    local singular_src_dir=$1
    local factory_file="$singular_src_dir/factory/FLINTconvert.cc"
    local libpolys_file="$singular_src_dir/libpolys/polys/flintconv.cc"
    local flint_version=""
    local patched=0

    if command -v pkg-config >/dev/null 2>&1 && pkg-config --exists flint; then
        flint_version=$(pkg-config --modversion flint 2>/dev/null || true)
    elif [ -f "${SCI_PREFIX:-$HOME/.local}/include/flint/flint.h" ]; then
        flint_version=$(
            awk '
                /#define __FLINT_VERSION / { major=$3 }
                /#define __FLINT_VERSION_MINOR / { minor=$3 }
                /#define __FLINT_VERSION_PATCHLEVEL / { patch=$3 }
                END {
                    if (major != "") {
                        printf "%s.%s.%s\n", major, minor, patch
                    }
                }
            ' "${SCI_PREFIX:-$HOME/.local}/include/flint/flint.h"
        )
    fi

    log_info "Checking Singular sources for FLINT compatibility${flint_version:+ (FLINT $flint_version)}..."

    if [ -f "$factory_file" ] && grep -Fq 'convertFacCF2nmod_poly_t (M->rows[i-1]+j-1, m (i,j));' "$factory_file"; then
        perl -0pi -e 's/convertFacCF2nmod_poly_t \(M->rows\[i-1\]\+j-1, m \(i,j\)\);/convertFacCF2nmod_poly_t (fq_nmod_mat_entry(M, i-1, j-1), m (i,j));/' "$factory_file"
        patched=1
    fi

    if [ -f "$libpolys_file" ] && grep -Fq 'convSingPFlintnmod_poly_t (M->rows[i-1]+j-1, MATELEM(m,i,j),r);' "$libpolys_file"; then
        perl -0pi -e 's/convSingPFlintnmod_poly_t \(M->rows\[i-1\]\+j-1, MATELEM\(m,i,j\),r\);/convSingPFlintnmod_poly_t (fq_nmod_mat_entry(M, i-1, j-1), MATELEM(m,i,j),r);/' "$libpolys_file"
        patched=1
    fi

    if [ "$patched" -eq 1 ]; then
        log_info "Applied Singular compatibility patch for newer FLINT matrix APIs."
    else
        log_info "No Singular FLINT compatibility patch needed."
    fi
}

install_singular() {
    local SINGULAR_NTL_ARGS SINGULAR_PREFIX SINGULAR_TARBALL SINGULAR_URL SRC_SUBDIR
    setup_science_environment
    log_section "SINGULAR COMPUTER ALGEBRA SYSTEM INSTALLATION (LOCAL)"
    log_info "Reinstalling Singular in local prefix for a clean, deterministic setup."

    # -------------------------------------------------------------------------
    # 1. Paths and versions
    # -------------------------------------------------------------------------
    # Where to install Singular (default: ~/.local, kept consistent with SCI_PREFIX)
    SINGULAR_PREFIX="${SCI_PREFIX:-$HOME/.local}"

    # Keep foundational releases explicit and overridable.
    SINGULAR_TARBALL="Singular-${SINGULAR_TAG}.tar.gz"
    SINGULAR_URL="https://github.com/Singular/Singular/archive/refs/tags/${SINGULAR_TAG}.tar.gz"

    mkdir -p "$SRC_DIR"
    cd "$SRC_DIR"

    # -------------------------------------------------------------------------
    # 2. Download source tarball (no sudo)
    # -------------------------------------------------------------------------
    if [ ! -f "$SINGULAR_TARBALL" ]; then
        log_info "Downloading Singular ${SINGULAR_TAG} from GitHub (local tarball)..."
        wget -O "$SINGULAR_TARBALL" "$SINGULAR_URL"
    else
        log_info "Using existing Singular tarball: $SINGULAR_TARBALL"
    fi

    # Determine top-level directory name inside the tarball
    SRC_SUBDIR=$(
        # `tar` lists many files here, but `head` reads only the first line and
        # quits. `tar` continues to write, hits the closed pipe and fires
        # `SIGPIPE` with code 141. Here `{ tar ... || true; }` ensures that
        # even if `tar` dies with 141, the group's exit code is still 0 and we
        # are happy
        { tar -tzf "$SINGULAR_TARBALL" || true; } | head -n1 | cut -d'/' -f1
    )
    if [ -z "$SRC_SUBDIR" ]; then
        log_error "Could not determine Singular source directory from tarball"
        return 1
    fi

    # Clean any previous extracted tree for this tarball
    rm -rf "$SRC_DIR/$SRC_SUBDIR"
    log_info "Extracting Singular sources to $SRC_DIR/$SRC_SUBDIR..."
    tar -xzf "$SINGULAR_TARBALL"

    cd "$SRC_DIR/$SRC_SUBDIR"
    apply_singular_flint_compat_patch "$PWD"

    # -------------------------------------------------------------------------
    # 3. Point build system at locally installed scientific libraries (if any)
    # -------------------------------------------------------------------------
    # The scientific component installs GMP/FLINT/etc. into ~/.local.
    if [ -n "${SCI_PREFIX:-}" ]; then
        export CPPFLAGS="-I$SCI_PREFIX/include${CPPFLAGS:+ $CPPFLAGS}"
        export LDFLAGS="-L$SCI_PREFIX/lib${LDFLAGS:+ $LDFLAGS}"
        export PKG_CONFIG_PATH="$SCI_PREFIX/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
        export LD_LIBRARY_PATH="$SCI_PREFIX/lib:${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
        log_info "Using local scientific libs from $SCI_PREFIX (CPPFLAGS/LDFLAGS/PKG_CONFIG_PATH/LD_LIBRARY_PATH updated)"
    fi

    # -------------------------------------------------------------------------
    # 4. Configure, build, and install (all under $SINGULAR_PREFIX, no sudo)
    # -------------------------------------------------------------------------
    log_info "Configuring Singular with prefix: $SINGULAR_PREFIX (no sudo, local install)..."

    # Some tarballs (e.g. GitHub snapshots) do not ship a pre-generated configure.
    # In that case we try to run ./autogen.sh to generate it.
    if [ ! -x ./configure ]; then
        if [ -x ./autogen.sh ]; then
            log_info "No configure script found, running ./autogen.sh to generate it..."
            if ! ./autogen.sh; then
                log_error "Singular ./autogen.sh failed – please check that autotools (autoconf/automake/libtool) are installed."
                return 1
            fi
        else
            log_error "Neither ./configure nor ./autogen.sh found in $(pwd)"
            log_error "Consider using an official release tarball from the Singular download page instead of a raw GitHub snapshot."
            return 1
        fi
    fi

    SINGULAR_NTL_ARGS=()
    if singular_ntl_prefix=$(detect_ntl_prefix); then
        log_info "Using NTL from $singular_ntl_prefix for Singular"
        SINGULAR_NTL_ARGS+=("--with-ntl=$singular_ntl_prefix")
    else
        log_warning "NTL was not found; Singular will build without NTL support and polymake's singular extension will fail."
    fi

    # Keep configure minimal and robust; gfanlib and extra backends can be added later
    if ! ./configure --prefix="$SINGULAR_PREFIX" "${SINGULAR_NTL_ARGS[@]}"; then
        log_error "Singular ./configure failed"
        return 1
    fi

    # Use your generic helper for build + install into user prefix
    build_and_install "Singular"

    # -------------------------------------------------------------------------
    # 5. Post-install: PATH hint and verification
    # -------------------------------------------------------------------------
    # Make sure ~/.local/bin is on PATH; your script does this earlier for core tools,
    # but we log a reminder in case this section is run stand-alone.
    if ! echo "$PATH" | tr ':' '\n' | grep -qx "$SINGULAR_PREFIX/bin"; then
        log_warning "PATH does not contain $SINGULAR_PREFIX/bin"
        log_info "Add this to your shell rc if needed:"
        log_info "    export PATH=\"$SINGULAR_PREFIX/bin:\$PATH\""
    fi

    # Basic sanity check: can we run Singular at all?
    if command -v Singular &> /dev/null; then
        if Singular -q -c "quit;" >/dev/null 2>&1; then
            VERSION_LINE=$(
                Singular --version -c "quit;" 2>&1 | head -1 || true
            )
            log_success "Singular installation verified: ${VERSION_LINE:-'version check ok'}"
        else
            component_incomplete "Singular is found in PATH but its basic 'quit' check failed."
        fi
    else
        log_error "Singular not found in PATH after installation; check $SINGULAR_PREFIX/bin and PATH"
        return 1
    fi
}
