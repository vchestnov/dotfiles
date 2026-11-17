#!/usr/bin/env bash
set -Eeuo pipefail

# Keep generated binaries out of the clean-source check without changing the
# upstream .gitignore or hiding tracked edits and scientific output.
configure_amflow_git_excludes() {
    local amflow_dir=$1 exclude_file existing='' pattern
    local -a missing=()
    exclude_file=$(git -C "$amflow_dir" rev-parse --path-format=absolute --git-path info/exclude)
    if [[ -e "$exclude_file" || -L "$exclude_file" ]]; then
        existing=$(cat -- "$exclude_file")
    fi
    for pattern in /diffeq_solver/desolver /diffeq_solver/link \
        '/diffeq_solver/desolver.backup.*' '/diffeq_solver/link.backup.*'; do
        if [[ $'\n'"$existing"$'\n' != *$'\n'"$pattern"$'\n'* ]]; then
            missing+=("$pattern")
        fi
    done
    if (( ${#missing[@]} == 0 )); then return 0; fi
    {
        if [[ -e "$exclude_file" || -L "$exclude_file" ]]; then
            cat -- "$exclude_file"
        fi
        printf '\n# Native AMFlow binaries managed by dotfiles bootstrap.\n'
        printf '%s\n' "${missing[@]}"
    } | write_generated_file "$exclude_file"
}

update_amflow_checkout() {
    local amflow_dir=$1 repo_url=${2:-https://gitlab.com/multiloop-pku/amflow.git}
    # Migrate existing installs before checking whether the source is dirty.
    if [[ -d "$amflow_dir/.git" ]]; then configure_amflow_git_excludes "$amflow_dir"; fi
    clone_or_update "$repo_url" "$amflow_dir"
    configure_amflow_git_excludes "$amflow_dir"
}

# WSTP detection must also work when the kernel cannot acquire a licence.
detect_amflow_wstp() {
    local command_path candidate root architecture
    architecture="Linux-$(uname -m)"
    [[ "$architecture" != Linux-x86_64 ]] || architecture=Linux-x86-64
    [[ "$architecture" != Linux-aarch64 ]] || architecture=Linux-ARM64
    if [[ -n "${AMFLOW_WSTP_DIR:-}" ]]; then
        [[ -x "$AMFLOW_WSTP_DIR/CompilerAdditions/wsprep" ]] || return 1
        printf '%s\n' "$AMFLOW_WSTP_DIR"
        return 0
    fi
    for command_path in WolframKernel math wolfram wolframscript; do
        command_path=$(command -v "$command_path") || continue
        command_path=$(readlink -f "$command_path")
        root=$(dirname "$(dirname "$command_path")")
        candidate="$root/SystemFiles/Links/WSTP/DeveloperKit/$architecture"
        if [[ -x "$candidate/CompilerAdditions/wsprep" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    for candidate in /usr/local/Wolfram/{Wolfram,Mathematica}/*/SystemFiles/Links/WSTP/DeveloperKit/"$architecture"; do
        if [[ -x "$candidate/CompilerAdditions/wsprep" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    return 1
}

build_amflow_solver() {
    local amflow_dir=$1 build_dir wstp_dir mpsolve_path command_path cxx=${CXX:-g++}
    local -a targets=(desolver) make_args=()
    for command_path in "$cxx" make mpsolve; do
        if ! command -v "$command_path" >/dev/null 2>&1; then
            component_incomplete "AMFlow C++ solver needs $command_path; install build-essential and mpsolve."
            return 0
        fi
    done
    mkdir -p "$BUILD_DIR"
    build_dir=$(mktemp -d "$BUILD_DIR/amflow.XXXXXX")
    # Build the current source in the cache, preserving local source edits and
    # avoiding upstream auto_install.sh's config and shell startup mutations.
    cp -R "$amflow_dir/diffeq_solver/include" "$amflow_dir/diffeq_solver/src" "$build_dir/"
    cp "$amflow_dir/diffeq_solver/Makefile" "$build_dir/Makefile"
    if ! "$cxx" -std=c++17 -I"$SCI_PREFIX/include" -L"$SCI_PREFIX/lib" \
        -Wl,-rpath,"$SCI_PREFIX/lib" -x c++ - -o "$build_dir/check-deps" \
        -lmpc -lmpfr -lgmp -lyaml-cpp > "$build_dir/check-deps.log" 2>&1 <<'CPP'
#include <mpc.h>
#include <yaml-cpp/yaml.h>
#include <boost/version.hpp>
#if BOOST_VERSION < 108300
#error AMFlow requires Boost 1.83 or later
#endif
int main() {
    mpc_t value;
    mpc_init2(value, 100);
    mpc_clear(value);
    return YAML::Load("value: 1")["value"].as<int>() != 1;
}
CPP
    then
        component_incomplete "AMFlow C++ dependencies missing: install libgmp-dev libmpfr-dev libmpc-dev libyaml-cpp-dev libboost-dev (Boost >= 1.83). See $build_dir/check-deps.log."
        return 0
    fi
    "$build_dir/check-deps"
    mpsolve_path=$(command -v mpsolve)
    if wstp_dir=$(detect_amflow_wstp); then
        targets+=(link)
        make_args+=("WSLINKDIR=$wstp_dir")
    elif [[ -n "${AMFLOW_WSTP_DIR:-}" ]]; then
        log_error "Invalid AMFLOW_WSTP_DIR: $AMFLOW_WSTP_DIR (CompilerAdditions/wsprep missing)."
        return 1
    else
        component_incomplete "AMFlow WSTP kit not found; building desolver only. Set AMFLOW_WSTP_DIR and rerun to enable the default C++ backend in Mathematica."
    fi
    make -C "$build_dir" -j"$SCI_JOBS" CONFIG_FILE=/dev/null \
        "CXX=$cxx" "MPSOLVE=$mpsolve_path" \
        "AMFLOW_GMP_INCLUDE=$SCI_PREFIX/include" "AMFLOW_MPFR_INCLUDE=$SCI_PREFIX/include" \
        "AMFLOW_MPC_INCLUDE=$SCI_PREFIX/include" "AMFLOW_YAML_CPP_INCLUDE=$SCI_PREFIX/include" \
        "AMFLOW_BOOST_INCLUDE=$SCI_PREFIX/include" \
        "AMFLOW_GMP_LIB=$SCI_PREFIX/lib" "AMFLOW_MPFR_LIB=$SCI_PREFIX/lib" \
        "AMFLOW_MPC_LIB=$SCI_PREFIX/lib" "AMFLOW_YAML_CPP_LIB=$SCI_PREFIX/lib" \
        "LIBDIRS=-L$SCI_PREFIX/lib -Wl,-rpath,$SCI_PREFIX/lib" \
        "${make_args[@]}" "${targets[@]}"
    local target
    for target in "${targets[@]}"; do
        write_generated_file "$amflow_dir/diffeq_solver/$target" 0755 < "$build_dir/$target"
    done
    log_success "AMFlow ${targets[*]} built; source and reducer configuration preserved. Build: $build_dir"
}

install_amflow() {
    local amflow_dir
    setup_science_environment
    amflow_dir="${AMFLOW_DIR:-$SCI_REPOS_DIR/amflow}"
    update_amflow_checkout "$amflow_dir"
    build_amflow_solver "$amflow_dir"
}
