#!/usr/bin/env bash
set -Eeuo pipefail

install_python_lsp() {
    local pylsp_venv

    if command -v pipx >/dev/null 2>&1; then
        pipx install --force 'python-lsp-server[all]'
        return 0
    fi

    if command -v python3 >/dev/null 2>&1; then
        : "${XDG_DATA_HOME:=$HOME/.local/share}"
        pylsp_venv="${PYLSP_VENV_DIR:-$XDG_DATA_HOME/python-lsp-server}"

        if python3 -m venv --help >/dev/null 2>&1; then
            mkdir -p "$(dirname "$pylsp_venv")" "$HOME/.local/bin"
            if [ ! -x "$pylsp_venv/bin/python" ]; then
                python3 -m venv "$pylsp_venv"
            fi

            "$pylsp_venv/bin/python" -m pip install --upgrade pip
            "$pylsp_venv/bin/python" -m pip install --upgrade 'python-lsp-server[all]'
            ln -sfn "$pylsp_venv/bin/pylsp" "$HOME/.local/bin/pylsp"
            return 0
        fi

        log_warning "python3 is available, but python3 -m venv is not."
        return 1
    fi

    log_warning "Neither pipx nor python3 is available for installing pylsp."
    return 1
}

install_julia_lsp() {
    local julia_lsp_env

    if ! command -v julia >/dev/null 2>&1; then
        log_warning "julia is not available on PATH; skipping Julia LSP installation."
        return 1
    fi

    : "${XDG_DATA_HOME:=$HOME/.local/share}"
    julia_lsp_env="${JULIA_LSP_ENV:-$XDG_DATA_HOME/julia/environments/lsp}"
    mkdir -p "$julia_lsp_env"

    julia --startup-file=no --history-file=no --project="$julia_lsp_env" \
        -e 'using Pkg; Pkg.add(["LanguageServer", "SymbolServer", "StaticLint"]); Pkg.precompile()'
}

run_wolfram_code() {
    local code=$1
    local wrapped_code="${code}; Exit[]"

    if command -v WolframKernel >/dev/null 2>&1; then
        WolframKernel -noinit -noprompt -nopaclet -nostartuppaclets -noicon -run "$wrapped_code"
        return $?
    fi

    if command -v wolfram >/dev/null 2>&1; then
        wolfram -noinit -noprompt -nopaclet -nostartuppaclets -noicon -run "$wrapped_code"
        return $?
    fi

    if command -v wolframscript >/dev/null 2>&1; then
        wolframscript -code "$code"
        return $?
    fi

    if command -v math >/dev/null 2>&1; then
        math -noinit -noprompt -run "$wrapped_code"
        return $?
    fi

    return 127
}

install_clangd_from_source() {
    local source_kind="${1:-git}"
    local install_prefix="${2:-$HOME/.local}"
    local git_ref="${CLANGD_GIT_REF}"
    local tar_version="${CLANGD_TARBALL_VERSION}"
    local source_root=""
    local source_dir=""
    local build_dir="$BUILD_DIR/llvm-project-clangd"
    local repo_dir="$SRC_DIR/llvm-project"
    local tarball="$SRC_DIR/llvm-project-${tar_version}.src.tar.xz"
    local tar_src_dir="$SRC_DIR/llvm-project-${tar_version}.src"
    local tar_url="${CLANGD_TARBALL_URL:-https://github.com/llvm/llvm-project/releases/download/llvmorg-${tar_version}/llvm-project-${tar_version}.src.tar.xz}"

    if ! command -v cmake >/dev/null 2>&1; then
        log_warning "cmake is required to build clangd from source."
        return 1
    fi

    if ! command -v ninja >/dev/null 2>&1; then
        log_warning "ninja is required to build clangd from source."
        return 1
    fi

    if ! command -v c++ >/dev/null 2>&1; then
        log_warning "A C++ compiler is required to build clangd from source."
        return 1
    fi

    mkdir -p "$SRC_DIR" "$BUILD_DIR" "$install_prefix"

    case "$source_kind" in
        git)
            if ! command -v git >/dev/null 2>&1; then
                log_warning "git is required for CLANGD_INSTALL_METHOD=git."
                return 1
            fi

            log_info "Installing clangd from llvm-project git ref: $git_ref"
            clone_or_update "https://github.com/llvm/llvm-project.git" "$repo_dir" "$git_ref"
            source_root="$repo_dir"
            ;;
        tar)
            if ! command -v wget >/dev/null 2>&1; then
                log_warning "wget is required for CLANGD_INSTALL_METHOD=tar."
                return 1
            fi

            log_info "Installing clangd from llvm-project source tarball: $tar_version"
            cd "$SRC_DIR"
            if [ ! -f "$tarball" ]; then
                wget "$tar_url" -O "$tarball"
            fi

            if [ -d "$tar_src_dir" ] && [ ! -d "$tar_src_dir/llvm/utils/TableGen" ] && [ ! -d "$tar_src_dir/utils/TableGen" ]; then
                log_warning "Existing llvm-project tarball source tree looks incomplete; re-extracting it."
                rm -rf "$tar_src_dir"
            fi

            if [ ! -d "$tar_src_dir" ]; then
                tar -xf "$tarball"
            fi
            source_root="$tar_src_dir"
            ;;
        *)
            log_error "Unknown clangd source kind '$source_kind'. Use git or tar."
            return 1
            ;;
    esac

    if [ -f "$source_root/llvm/CMakeLists.txt" ] && [ -d "$source_root/llvm/utils/TableGen" ]; then
        source_dir="$source_root/llvm"
    elif [ -f "$source_root/CMakeLists.txt" ] && [ -d "$source_root/utils/TableGen" ]; then
        source_dir="$source_root"
    else
        log_warning "Could not find a valid LLVM source directory under $source_root."
        log_warning "Expected either llvm/CMakeLists.txt with llvm/utils/TableGen, or a top-level CMakeLists.txt with utils/TableGen."
        return 1
    fi

    cmake -G Ninja \
        -S "$source_dir" \
        -B "$build_dir" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$install_prefix" \
        -DLLVM_ENABLE_PROJECTS="clang;clang-tools-extra" \
        -DLLVM_TARGETS_TO_BUILD="host"

    cmake --build "$build_dir" --target clangd -j"${CLANGD_JOBS:-${BUILD_JOBS:-$(default_build_jobs)}}"
    cmake --build "$build_dir" --target install-clang-resource-headers install-clangd

    if [ -x "$install_prefix/bin/clangd" ]; then
        log_success "clangd installed from source to $install_prefix/bin/clangd"
        return 0
    fi

    log_warning "clangd source build completed, but the installed binary was not found in $install_prefix/bin."
    return 1
}

install_lsp() {
    local CLANGD_INSTALL_METHOD
    log_section "LANGUAGE SERVER TOOLING"

    mkdir -p "$BIN_DIR"
    CLANGD_INSTALL_METHOD="${CLANGD_INSTALL_METHOD:-${CLANGD_INSTALL_METHOD_DEFAULT:-git}}"
    if [ "$CLANGD_INSTALL_METHOD" = "auto" ]; then
        if component_enabled system-base && command -v sudo >/dev/null 2>&1; then
            CLANGD_INSTALL_METHOD="apt"
        else
            CLANGD_INSTALL_METHOD="${CLANGD_SOURCE_KIND:-git}"
        fi
    fi

    if command -v clangd >/dev/null 2>&1; then
        log_info "Existing clangd found at $(command -v clangd)"
    fi

    log_info "clangd installation method: $CLANGD_INSTALL_METHOD"

    case "$CLANGD_INSTALL_METHOD" in
        apt)
            if component_enabled system-base && command -v sudo >/dev/null 2>&1; then
                log_info "Installing clangd from apt..."
                refresh_sudo
                apt_install clangd
                log_success "clangd installed"
            else
                log_error "apt-based clangd requires the system-base component."
                return 1
            fi
            ;;
        git|tar)
            log_info "Installing clangd from source into $HOME/.local"
            install_clangd_from_source "$CLANGD_INSTALL_METHOD" "$HOME/.local"
            ;;
        *)
            log_error "Unknown CLANGD_INSTALL_METHOD='$CLANGD_INSTALL_METHOD'. Use auto, apt, git, or tar."
            return 1
            ;;
    esac

    log_info "Installing Python language server (pylsp)..."
    install_python_lsp
    log_success "Python language server installed"

    if [ -f "$SCRIPT_DIR/scripts/julia-lsp" ]; then
        install_launcher_script "$SCRIPT_DIR/scripts/julia-lsp" "$BIN_DIR/julia-lsp"
        log_info "Installed Julia LSP launcher to $BIN_DIR/julia-lsp"
    fi

    log_info "Installing Julia language server (LanguageServer.jl)..."
    if command -v julia >/dev/null 2>&1; then
        install_julia_lsp
        log_success "Julia language server installed"
    else
        log_info "Julia is not installed; omitting its optional LSP integration."
    fi

    if [ -x "$SCRIPT_DIR/scripts/wolfram-lsp" ]; then
        install_launcher_script "$SCRIPT_DIR/scripts/wolfram-lsp" "$BIN_DIR/wolfram-lsp"
        log_info "Installed Wolfram LSP launcher to $BIN_DIR/wolfram-lsp"
    fi

    if command -v WolframKernel >/dev/null 2>&1 || command -v wolfram >/dev/null 2>&1 || command -v wolframscript >/dev/null 2>&1 || command -v math >/dev/null 2>&1; then
        log_info "Ensuring official Wolfram LSP paclets are installed..."
        if run_wolfram_code 'Needs["PacletManager`"]; PacletInstall["CodeParser"]; PacletInstall["CodeInspector"]; PacletInstall["CodeFormatter"]; PacletInstall["LSPServer"];' >/dev/null 2>&1; then
            log_success "Wolfram LSP paclets are available"
        else
            component_incomplete "Could not install the official Wolfram LSP paclets."
            log_warning "If needed, run from a Wolfram session:"
            log_warning '  PacletInstall["CodeParser"]; PacletInstall["CodeInspector"]; PacletInstall["CodeFormatter"]; PacletInstall["LSPServer"];'
        fi
    else
        log_warning "Wolfram tools not found on PATH; skipping Mathematica LSP bootstrap."
    fi

    if command -v vim >/dev/null 2>&1; then
        log_info "Installing/updating Vim plugins for LSP support..."
        vim +'silent! PlugInstall --sync' +qa || component_incomplete "Vim plugin installation did not complete cleanly."
    else
        log_warning "vim not found on PATH; skipping plugin installation."
    fi

    log_success "Language server tooling setup completed"
}
