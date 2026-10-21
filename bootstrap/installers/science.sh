#!/usr/bin/env bash
set -Eeuo pipefail

apply_gfan_compat_patch() {
    local gfan_src_dir=$1
    local z_header="$gfan_src_dir/src/gfanlib_z.h"
    local patched=0

    if [ -f "$z_header" ] && grep -Fq 'std::int32_t' "$z_header" && ! sed -n '1,30p' "$z_header" | grep -Fq '#include <cstdint>'; then
        perl -0pi -e 's/#include <iostream>\n/#include <iostream>\n#include <cstdint>\n/' "$z_header"
        patched=1
    fi

    if [ "$patched" -eq 1 ]; then
        log_info "Applied gfan compatibility patch for explicit std::int32_t declarations."
    else
        log_info "No gfan compatibility patch needed."
    fi
}

write_blade_install_config() {
    local install_file=$1
    local finiteflow_dir=$2
    local sci_prefix=$3
    local escaped_finiteflow_dir=${finiteflow_dir//&/\\&}
    local escaped_sci_prefix=${sci_prefix//&/\\&}

    if [ ! -f "$install_file" ]; then
        log_error "Blade install config not found: $install_file"
        return 1
    fi

    if grep -q '^DFFLOWMLINK_DIR=' "$install_file"; then
        sed -i "s|^DFFLOWMLINK_DIR=.*|DFFLOWMLINK_DIR=\"$escaped_finiteflow_dir\"|" "$install_file"
    else
        printf '\nDFFLOWMLINK_DIR="%s"\n' "$finiteflow_dir" >> "$install_file"
    fi

    if grep -q '^DCMAKE_PREFIX_PATH=' "$install_file"; then
        sed -i "s|^DCMAKE_PREFIX_PATH=.*|DCMAKE_PREFIX_PATH=\"$escaped_sci_prefix\"|" "$install_file"
    else
        printf 'DCMAKE_PREFIX_PATH="%s"\n' "$sci_prefix" >> "$install_file"
    fi
}

install_gmp() {
    local BUILD_JOBS GMP_ARCHIVE GMP_URL
    setup_science_environment
    log_info "Installing GMP from source..."
    GMP_ARCHIVE="gmp-${GMP_VERSION}.tar.xz"
    GMP_URL="${GMP_URL:-https://gmplib.org/download/gmp/${GMP_ARCHIVE}}"

    cd "$SRC_DIR"
    download_file "$GMP_URL" "$GMP_ARCHIVE"
    tar -xf "$GMP_ARCHIVE"
    cd "gmp-${GMP_VERSION}"

    ./configure --prefix="$SCI_PREFIX" --enable-cxx
    BUILD_JOBS="$SCI_JOBS" build_and_install "GMP"
    log_success "GMP installed to $SCI_PREFIX"
}

install_ntl() {
    local BUILD_JOBS NTL_ARCHIVE NTL_URL
    setup_science_environment
    log_info "Installing NTL from source..."
    NTL_ARCHIVE="ntl-${NTL_VERSION}.tar.gz"
    NTL_URL="${NTL_URL:-https://libntl.org/${NTL_ARCHIVE}}"

    cd "$SRC_DIR"
    download_file "$NTL_URL" "$NTL_ARCHIVE"
    tar -xf "$NTL_ARCHIVE"
    cd "ntl-${NTL_VERSION}/src"

    ./configure DEF_PREFIX="$SCI_PREFIX" SHARED=on
    BUILD_JOBS="$SCI_JOBS" build_and_install "NTL"
    log_success "NTL installed to $SCI_PREFIX"
}

install_mpfr() {
    local BUILD_JOBS MPFR_ARCHIVE MPFR_URL
    setup_science_environment
    log_info "Installing MPFR from source..."
    MPFR_ARCHIVE="mpfr-${MPFR_VERSION}.tar.xz"
    MPFR_URL="${MPFR_URL:-https://www.mpfr.org/mpfr-${MPFR_VERSION}/${MPFR_ARCHIVE}}"

    cd "$SRC_DIR"
    download_file "$MPFR_URL" "$MPFR_ARCHIVE"
    tar -xf "$MPFR_ARCHIVE"
    cd "mpfr-${MPFR_VERSION}"

    ./configure --prefix="$SCI_PREFIX" --with-gmp="$SCI_PREFIX"
    BUILD_JOBS="$SCI_JOBS" build_and_install "MPFR"
    log_success "MPFR installed to $SCI_PREFIX"
}

install_flint() {
    local BUILD_JOBS FLINT_ARCHIVE FLINT_URL
    setup_science_environment
    log_info "Installing FLINT from source..."
    FLINT_ARCHIVE="flint-${FLINT_VERSION}.tar.gz"
    FLINT_URL="${FLINT_URL:-https://flintlib.org/download/${FLINT_ARCHIVE}}"

    cd "$SRC_DIR"
    download_file "$FLINT_URL" "$FLINT_ARCHIVE"
    tar -xf "$FLINT_ARCHIVE"
    cd "flint-${FLINT_VERSION}"

    ./configure \
        --prefix="$SCI_PREFIX" \
        --with-gmp="$SCI_PREFIX" \
        --with-mpfr="$SCI_PREFIX"
    BUILD_JOBS="$SCI_JOBS" build_and_install "FLINT"
    log_success "FLINT installed to $SCI_PREFIX"
}

install_finiteflow() {
    local BUILD_JOBS FINITEFLOW_DEV_DIR FINITEFLOW_FLINT_PROVIDER FINITEFLOW_MATHLIB
    setup_science_environment
    local FINITEFLOW_PREFIX_PATH="$SCI_PREFIX"
    FINITEFLOW_FLINT_PROVIDER="${FINITEFLOW_FLINT_PROVIDER:-full}"

    case "$FINITEFLOW_FLINT_PROVIDER" in
        full)
            log_info "Using full FLINT installation for FiniteFlow; skipping flint-finiteflow-dep."
            ;;
        mini|minimal)
            FINITEFLOW_FLINT_PREFIX="${FINITEFLOW_FLINT_PREFIX:-$SCI_PREFIX/finiteflow-deps}"

            log_info "Installing FiniteFlow-specific minimal FLINT into $FINITEFLOW_FLINT_PREFIX..."
            mkdir -p "$FINITEFLOW_FLINT_PREFIX"
            clone_or_update "https://github.com/peraro/flint-finiteflow-dep.git" "$SRC_DIR/flint-finiteflow-dep"
            cd "$SRC_DIR/flint-finiteflow-dep"

            cmake -DCMAKE_PREFIX_PATH="$SCI_PREFIX" \
                  -DCMAKE_INSTALL_PREFIX="$FINITEFLOW_FLINT_PREFIX" \
                  .
            BUILD_JOBS="$SCI_JOBS" build_and_install "FLINT-FiniteFlow-dep"
            log_success "FiniteFlow-specific minimal FLINT installed to $FINITEFLOW_FLINT_PREFIX"

            FINITEFLOW_PREFIX_PATH="$FINITEFLOW_FLINT_PREFIX:$SCI_PREFIX"
            FINITEFLOW_ENV_PREFIX="$FINITEFLOW_FLINT_PREFIX"
            export LD_LIBRARY_PATH="$FINITEFLOW_FLINT_PREFIX/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
            ;;
        *)
            log_error "Unknown FINITEFLOW_FLINT_PROVIDER='$FINITEFLOW_FLINT_PROVIDER'. Use full or mini."
            return 1
            ;;
    esac

    log_info "Installing FiniteFlow (dev sources in ~/dev/finiteflow)..."

    FINITEFLOW_DEV_DIR="$HOME/dev/finiteflow"
    FINITEFLOW_MATHLIB="$SCI_PREFIX/lib"
    mkdir -p "$HOME/dev"
    mkdir -p "$FINITEFLOW_MATHLIB"

    clone_or_update "https://github.com/peraro/finiteflow.git" "$FINITEFLOW_DEV_DIR"
    cd "$FINITEFLOW_DEV_DIR"

    # If there was a previous build, clean it up first
    if [ -f CMakeCache.txt ] || [ -d CMakeFiles ] || [ -f Makefile ]; then
        log_info "Previous FiniteFlow build detected; cleaning up..."

        if [ -f Makefile ]; then
            # Try make clean; don't abort on failure
            if ! make clean; then
                log_warning "make clean failed for FiniteFlow (continuing anyway)..."
            fi

            # Try make uninstall if target exists; don't abort on failure
            if grep -q "^uninstall:" Makefile 2>/dev/null; then
                if ! make uninstall; then
                    log_warning "make uninstall failed for FiniteFlow (continuing anyway)..."
                fi
            else
                log_info "No uninstall target in FiniteFlow Makefile; skipping make uninstall."
            fi
        fi

        # Remove CMake cache and related build files
        rm -f CMakeCache.txt
        rm -rf CMakeFiles
        rm -f cmake_install.cmake
        rm -f install_manifest.txt
        rm -f Makefile

        log_info "Removed previous FiniteFlow CMake cache and build artifacts."
    fi

    cmake -DCMAKE_INSTALL_PREFIX="$SCI_PREFIX" \
          -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
          -DCMAKE_PREFIX_PATH="$FINITEFLOW_PREFIX_PATH" \
          -DMATHLIBINSTALL="$FINITEFLOW_MATHLIB" \
          .
    BUILD_JOBS="$SCI_JOBS" build_and_install "FiniteFlow"
    log_success "FiniteFlow installed to $SCI_PREFIX; sources are in $FINITEFLOW_DEV_DIR"
    if [ -f "$FINITEFLOW_DEV_DIR/compile_commands.json" ]; then
        log_info "clangd compilation database available at $FINITEFLOW_DEV_DIR/compile_commands.json"
    fi
}

install_finiteflow32() {
    local FINITEFLOW32_BUILD_DIR FINITEFLOW32_DEV_DIR FINITEFLOW32_MSOLVE_SRC FINITEFLOW32_PATHS_FILE FINITEFLOW32_REPO_URL
    setup_science_environment
    log_info "Installing FiniteFlow32 from private GitHub repository..."

    FINITEFLOW32_DEV_DIR="${FINITEFLOW32_DEV_DIR:-$HOME/dev/finiteflow32}"
    FINITEFLOW32_BUILD_DIR="${FINITEFLOW32_BUILD_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/finiteflow32/build}"
    FINITEFLOW32_PATHS_FILE="${FINITEFLOW32_PATHS_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/finiteflow32/paths_instructions.txt}"
    FINITEFLOW32_MSOLVE_SRC="${FINITEFLOW32_MSOLVE_SRC:-$SCI_REPOS_DIR/msolve}"
    FINITEFLOW32_REPO_URL="${FINITEFLOW32_REPO_URL:-git@github.com:Giu989/finiteflow32.git}"

    if [ -z "${FINITEFLOW32_RUN_VALIDATION:-}" ]; then
        if command -v WolframKernel >/dev/null 2>&1 || \
           command -v wolfram >/dev/null 2>&1 || \
           command -v wolframscript >/dev/null 2>&1 || \
           command -v math >/dev/null 2>&1; then
            FINITEFLOW32_RUN_VALIDATION=1
        else
            FINITEFLOW32_RUN_VALIDATION=0
        fi
    fi

    mkdir -p "$HOME/dev"
    mkdir -p "$(dirname "$FINITEFLOW32_BUILD_DIR")"
    mkdir -p "$(dirname "$FINITEFLOW32_PATHS_FILE")"

    if ! clone_or_update "$FINITEFLOW32_REPO_URL" "$FINITEFLOW32_DEV_DIR" "${FINITEFLOW32_GIT_REF:-}"; then
        skip_component "FiniteFlow32 repository unavailable or SSH access denied."
    else
        cd "$FINITEFLOW32_DEV_DIR"

        PREFIX="$SCI_PREFIX" \
        DEPS_PREFIX="$SCI_PREFIX" \
        MSOLVE_PREFIX="$SCI_PREFIX" \
        MSOLVE_SRC="$FINITEFLOW32_MSOLVE_SRC" \
        BUILD_DIR="$FINITEFLOW32_BUILD_DIR" \
        PATHS_INSTRUCTIONS_FILE="$FINITEFLOW32_PATHS_FILE" \
        CMAKE_PREFIX_PATH="$SCI_PREFIX" \
        FFLOW_USE_FLINT="${FINITEFLOW32_USE_FLINT:-ON}" \
        FFLOW_FLINT_PREFIX="${FINITEFLOW32_FLINT_PREFIX:-$SCI_PREFIX}" \
        FFLOW_ALLOW_SYSTEM_FLINT="${FINITEFLOW32_ALLOW_SYSTEM_FLINT:-OFF}" \
        CLEAN_BUILD="${FINITEFLOW32_CLEAN_BUILD:-1}" \
        RUN_VALIDATION="$FINITEFLOW32_RUN_VALIDATION" \
        JOBS="${FINITEFLOW32_JOBS:-$SCI_JOBS}" \
        ./install_finiteflow32.sh

        log_success "FiniteFlow32 installed to $SCI_PREFIX; sources are in $FINITEFLOW32_DEV_DIR"
        log_info "FiniteFlow32 path instructions written to $FINITEFLOW32_PATHS_FILE"
        if [ "$FINITEFLOW32_RUN_VALIDATION" = "0" ]; then
            log_info "FiniteFlow32 validation was skipped; set FINITEFLOW32_RUN_VALIDATION=1 to force it later."
        fi
    fi
}

install_blade() {
    local BLADE_BUILD_DIR BLADE_DEV_DIR BLADE_PATCH_FILE FINITEFLOW_DEV_DIR
    setup_science_environment
    log_info "Installing Blade from source..."

    FINITEFLOW_DEV_DIR="${FINITEFLOW_DEV_DIR:-$HOME/dev/finiteflow}"
    BLADE_DEV_DIR="${BLADE_DEV_DIR:-$SCI_REPOS_DIR/blade}"
    BLADE_BUILD_DIR="${BLADE_BUILD_DIR:-$BLADE_DEV_DIR/build}"
    BLADE_PATCH_FILE="${BLADE_PATCH_FILE:-$SCRIPT_DIR/patches/blade/blade_cache_directory.patch}"

    if [ ! -d "$FINITEFLOW_DEV_DIR" ]; then
        log_info "FiniteFlow sources not found at $FINITEFLOW_DEV_DIR; cloning them for Blade integration."
        clone_or_update "https://github.com/peraro/finiteflow.git" "$FINITEFLOW_DEV_DIR"
    fi

    if [ ! -f "$FINITEFLOW_DEV_DIR/fflowmlink.so" ] || [ ! -f "$FINITEFLOW_DEV_DIR/mathlink/FiniteFlow.m" ]; then
        log_warning "Blade expects fflowmlink.so and mathlink/FiniteFlow.m under $FINITEFLOW_DEV_DIR."
        log_warning "Build FiniteFlow there before using Blade if CMake configure fails."
    fi

    clone_or_update "https://gitee.com/multiloop-pku/blade.git" "$BLADE_DEV_DIR"
    cd "$BLADE_DEV_DIR"

    ensure_git_patch_applied "$BLADE_PATCH_FILE" "blade_cache_directory"
    write_blade_install_config "$BLADE_DEV_DIR/install.in.txt" "$FINITEFLOW_DEV_DIR" "$SCI_PREFIX"

    cmake -S "$BLADE_DEV_DIR" -B "$BLADE_BUILD_DIR" -DCMAKE_PREFIX_PATH="$SCI_PREFIX"
    cmake --build "$BLADE_BUILD_DIR" -j"$SCI_JOBS"
    cmake --install "$BLADE_BUILD_DIR"
    log_success "Blade built in $BLADE_BUILD_DIR and installed into $BLADE_DEV_DIR/bin and $BLADE_DEV_DIR/lib"
}

install_msolve() {
    local BUILD_JOBS MSOLVE_DEV_DIR
    setup_science_environment
    log_info "Installing msolve from GitHub..."

    MSOLVE_DEV_DIR="${MSOLVE_DEV_DIR:-$SCI_REPOS_DIR/msolve}"
    mkdir -p "$SCI_REPOS_DIR"

    clone_or_update "https://github.com/algebraic-solving/msolve.git" "$MSOLVE_DEV_DIR" "${MSOLVE_GIT_REF:-}"
    cd "$MSOLVE_DEV_DIR"

    if [ -f Makefile ]; then
        log_info "Previous msolve build detected; cleaning up..."
        if grep -q "^distclean:" Makefile 2>/dev/null; then
            make distclean || log_warning "make distclean failed for msolve (continuing anyway)..."
        elif grep -q "^clean:" Makefile 2>/dev/null; then
            make clean || log_warning "make clean failed for msolve (continuing anyway)..."
        fi
    fi

    if [ ! -x ./autogen.sh ]; then
        log_error "msolve checkout does not contain ./autogen.sh"
        return 1
    fi

    ./autogen.sh
    ./configure --prefix="$SCI_PREFIX"
    BUILD_JOBS="$SCI_JOBS" build_and_install "msolve"
    log_success "msolve installed to $SCI_PREFIX; sources are in $MSOLVE_DEV_DIR"
}

install_gfan() {
    local BUILD_JOBS CDDLIB_ARCHIVE CDDLIB_ARCHIVE_PATH CDDLIB_SRC_DIR CDDLIB_URL CFLAGS GFAN_ARCHIVE GFAN_ARCHIVE_PATH GFAN_MAKE_ARGS GFAN_SRC_DIR GFAN_URL
    setup_science_environment
    log_info "Installing cddlib and gfan from upstream tarballs..."

    GFAN_ARCHIVE="gfan${GFAN_VERSION}.tar.gz"
    GFAN_URL="${GFAN_URL:-https://math.au.dk/~jensen/software/gfan/${GFAN_ARCHIVE}}"
    GFAN_ARCHIVE_PATH="$SRC_DIR/$GFAN_ARCHIVE"
    GFAN_SRC_DIR="${GFAN_SRC_DIR:-$SRC_DIR/gfan-${GFAN_VERSION}-src}"
    CDDLIB_ARCHIVE="cddlib-${CDDLIB_VERSION}.tar.gz"
    CDDLIB_URL="${CDDLIB_URL:-https://people.inf.ethz.ch/fukudak/cdd_home/Cddtarfiles_pub/${CDDLIB_ARCHIVE}}"
    CDDLIB_ARCHIVE_PATH="$SRC_DIR/$CDDLIB_ARCHIVE"
    CDDLIB_SRC_DIR="${CDDLIB_SRC_DIR:-$SRC_DIR/cddlib-${CDDLIB_VERSION}-src}"
    GFAN_MAKE_ARGS=()

    mkdir -p "$SRC_DIR"

    log_info "Installing cddlib for gfan..."
    download_file "$CDDLIB_URL" "$CDDLIB_ARCHIVE_PATH"

    rm -rf "$CDDLIB_SRC_DIR"
    mkdir -p "$CDDLIB_SRC_DIR"
    tar -xzf "$CDDLIB_ARCHIVE_PATH" -C "$CDDLIB_SRC_DIR" --strip-components=1
    cd "$CDDLIB_SRC_DIR"

    CFLAGS="-I$SCI_PREFIX/include -L$SCI_PREFIX/lib" \
        ./configure --prefix="$SCI_PREFIX"
    BUILD_JOBS="$SCI_JOBS" build_and_install "cddlib"
    log_success "cddlib installed to $SCI_PREFIX; sources are in $CDDLIB_SRC_DIR"

    log_info "Installing gfan from upstream tarball..."
    download_file "$GFAN_URL" "$GFAN_ARCHIVE_PATH"

    rm -rf "$GFAN_SRC_DIR"
    mkdir -p "$GFAN_SRC_DIR"
    tar -xzf "$GFAN_ARCHIVE_PATH" -C "$GFAN_SRC_DIR" --strip-components=1
    cd "$GFAN_SRC_DIR"
    apply_gfan_compat_patch "$GFAN_SRC_DIR"

    GFAN_MAKE_ARGS+=("gmppath=$SCI_PREFIX")
    GFAN_MAKE_ARGS+=("cddpath=$SCI_PREFIX")
    GFAN_MAKE_ARGS+=("cddnoprefix=true")

    make "${GFAN_MAKE_ARGS[@]}"
    ./gfan _test
    make PREFIX="$SCI_PREFIX" install
    log_success "gfan installed to $SCI_PREFIX; sources are in $GFAN_SRC_DIR"
}

install_fermat() {
    local FERMAT_LINK_TARGET FERMAT_SRC_DIR FERMAT_URL fermat_ok
    setup_science_environment
    log_info "Installing Fermat..."

    FERMAT_URL="https://home.bway.net/lewis/fermat64/Ferl7.tar.gz"
    FERMAT_SRC_DIR="$SRC_DIR"
    FERMAT_LINK_TARGET="$SCI_PREFIX/bin/fer64"

    mkdir -p "$FERMAT_SRC_DIR"
    cd "$FERMAT_SRC_DIR"

    fermat_ok=1

    # Download archive if not present (avoid repeated fetch)
    if [ ! -f "Ferl7.tar.gz" ]; then
        log_info "Downloading Fermat from $FERMAT_URL"
        if ! wget -O Ferl7.tar.gz "$FERMAT_URL"; then
            skip_component "Could not download Fermat from $FERMAT_URL."
            fermat_ok=0
        fi
    fi

    # Extract only if download (or existing tarball) is OK
    if [ "$fermat_ok" -eq 1 ]; then
        log_info "Extracting Fermat..."
        if ! tar -xzf Ferl7.tar.gz; then
            skip_component "Failed to extract Fermat archive."
            fermat_ok=0
        fi
    fi

    # Find the Fermat binary somewhere under $FERMAT_SRC_DIR
    if [ "$fermat_ok" -eq 1 ]; then
        FER_BINARY="$FERMAT_SRC_DIR/Ferl7/fer64"

        if [ ! -x "$FER_BINARY" ]; then
            skip_component "Fermat binary not found after extraction."
        else
            log_info "Linking Fermat binary ($FER_BINARY) to $FERMAT_LINK_TARGET"
            ln -sf "$FER_BINARY" "$FERMAT_LINK_TARGET"
            log_success "Fermat available as: $FERMAT_LINK_TARGET"
        fi
    fi
}

install_science_extra() {
    setup_science_environment
    log_section "CLONING EXTRA SCIENTIFIC PACKAGES"
    log_info "All extra packages will live in: $SCI_REPOS_DIR"

    # FiniteFlow MathTools
    clone_sci_repo "finiteflow-mathtools" "https://github.com/peraro/finiteflow-mathtools.git"

    # CALICO
    clone_sci_repo "calico" "https://github.com/fontana-g/calico.git"

    # LiteRed2 + Libra
    clone_sci_repo "LiteRed2"  "https://github.com/rnlg/LiteRed2.git"
    clone_sci_repo "Libra"     "https://github.com/rnlg/Libra.git"
    clone_sci_repo "Fermatica" "https://github.com/rnlg/Fermatica.git"

    # AMFlow / CalcLoop
    clone_sci_repo "amflow"   "https://gitlab.com/multiloop-pku/amflow.git"
    clone_sci_repo "calcloop" "https://gitlab.com/multiloop-pku/calcloop.git"

    # BaikovLetter
    clone_sci_repo "Baikovletter" "https://github.com/windfolgen/Baikovletter.git"

    # BaikovPackage
    clone_sci_repo "BaikovPackage" "https://github.com/HjalteFrellesvig/BaikovPackage.git"

    # INITIAL
    clone_sci_repo "INITIAL" "https://github.com/UT-team/INITIAL.git"

    # NeatIBP
    clone_sci_repo "NeatIBP" "https://github.com/yzhphy/NeatIBP.git"

    # Alibrary
    clone_sci_repo "alibrary" "https://github.com/magv/alibrary.git"

    # RationalizeRoots
    clone_sci_repo "rationalizeroots" "https://github.com/marcobesier/rationalizeroots.git"

    # Azurite
    clone_sci_repo "azurite" "https://bitbucket.org/yzhphy/azurite.git"

    # DlogBasis
    clone_sci_repo "DlogBasis" "https://github.com/pascalwasser/DlogBasis.git"

    # Effortless
    clone_sci_repo "Effortless" "https://github.com/antonela-matijasic/Effortless.git"

    # SOFIA
    clone_sci_repo "SOFIA" "https://github.com/StrangeQuark007/SOFIA.git"

    # MultivariateApart
    clone_sci_repo "MultivariateApart" "https://gitlab.msu.edu/vmante/multivariateapart.git"

    # Subtropica
    clone_sci_repo "Subtropica" "https://github.com/SubTropica/SubTropica.git"

    # Canonica
    clone_sci_repo "Canonica" "https://github.com/christophmeyer/CANONICA.git"

    # Private FiniteFlow external packages
    if ! clone_sci_repo "ff_ext_packages" "git@github.com:peraro/ff_ext_packages.git"; then
        component_incomplete "Cannot obtain private repo ff_ext_packages."
    fi

    # Private modification of Singular interface for Mathematica
    if ! clone_sci_repo "singular" "git@github.com:vchestnov/singular.git"; then
        component_incomplete "Cannot obtain private Singular interface repository."
    fi
}

install_qd() {
    local BUILD_JOBS
    setup_science_environment
    # ========================================
    # QD (Quad-Double Arithmetic Library)
    # ========================================
    log_info "Installing QD (Quad-Double library)..."

    cd "$SRC_DIR"
    clone_or_update "https://github.com/scibuilder/QD.git" "$SRC_DIR/QD"
    cd "$SRC_DIR/QD"

    # If there was a previous build, clean it up first
    if [ -f Makefile ]; then
        log_info "Previous QD build detected; cleaning up..."

        if ! make clean; then
            log_warning "make clean failed for QD (continuing anyway)..."
        fi

        # Try make uninstall if the target exists; don't abort on failure
        if grep -q "^uninstall:" Makefile 2>/dev/null; then
            if ! make uninstall; then
                log_warning "make uninstall failed for QD (continuing anyway)..."
            fi
        else
            log_info "No uninstall target in QD Makefile; skipping make uninstall."
        fi
    fi

    # Configure with an absolute prefix
    log_info "Configuring QD with prefix: $SCI_PREFIX"
    ./configure --prefix="$SCI_PREFIX" || {
        log_error "QD configure failed"
        return 1
    }

    # Build and install using your helper
    BUILD_JOBS="$SCI_JOBS" build_and_install "QD"
    log_success "QD installed to $SCI_PREFIX (libs in $SCI_PREFIX/lib, headers in $SCI_PREFIX/include)"
}
