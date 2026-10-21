#!/usr/bin/env bash
set -Eeuo pipefail

setup_conda_xdg_environment() {
    : "${XDG_CONFIG_HOME:=$HOME/.config}"
    : "${XDG_DATA_HOME:=$HOME/.local/share}"
    : "${XDG_CACHE_HOME:=$HOME/.cache}"
    : "${XDG_STATE_HOME:=$HOME/.local/state}"

    export CONDA_HOME="${CONDA_HOME:-$XDG_DATA_HOME/miniforge3}"
    export CONDARC="${CONDARC:-$XDG_CONFIG_HOME/conda/condarc}"
    export CONDA_ENVS_PATH="${CONDA_ENVS_PATH:-$XDG_DATA_HOME/conda/envs}"
    export CONDA_PKGS_DIRS="${CONDA_PKGS_DIRS:-$XDG_CACHE_HOME/conda/pkgs}"
    export MAMBA_ROOT_PREFIX="${MAMBA_ROOT_PREFIX:-$CONDA_HOME}"

    mkdir -p \
        "$(dirname "$CONDA_HOME")" \
        "$(dirname "$CONDARC")" \
        "$CONDA_ENVS_PATH" \
        "$CONDA_PKGS_DIRS" \
        "$XDG_STATE_HOME/conda"

    write_generated_file "$CONDARC" << EOF
channels:
  - conda-forge
channel_priority: strict
auto_activate_base: false
envs_dirs:
  - $CONDA_ENVS_PATH
pkgs_dirs:
  - $CONDA_PKGS_DIRS
EOF
}

ensure_miniforge() {
    setup_conda_xdg_environment

    if [ -x "$CONDA_HOME/bin/conda" ]; then
        log_info "Miniforge already installed at $CONDA_HOME"
    else
        local installer_name="Miniforge3-$(uname)-$(uname -m).sh"
        local installer_path="$SRC_DIR/$installer_name"
        local installer_url="${MINIFORGE_INSTALLER_URL:-https://github.com/conda-forge/miniforge/releases/latest/download/$installer_name}"

        mkdir -p "$SRC_DIR"
        log_info "Downloading Miniforge installer from GitHub latest release..."

        if command -v curl >/dev/null 2>&1; then
            curl -fsSL "$installer_url" -o "$installer_path"
        elif command -v wget >/dev/null 2>&1; then
            wget "$installer_url" -O "$installer_path"
        else
            log_warning "Neither curl nor wget is available to download Miniforge."
            return 1
        fi

        if [ -d "$CONDA_HOME" ] && [ ! -x "$CONDA_HOME/bin/conda" ]; then
            if [ -z "$(find "$CONDA_HOME" -mindepth 1 -maxdepth 1 -print -quit)" ]; then
                rmdir "$CONDA_HOME"
            else
                log_error "$CONDA_HOME exists but does not look like a conda installation."
                return 1
            fi
        fi

        bash "$installer_path" -b -p "$CONDA_HOME"
        log_success "Miniforge installed to $CONDA_HOME"
    fi

    if [ -f "$CONDA_HOME/etc/profile.d/conda.sh" ]; then
        # shellcheck disable=SC1091
        source "$CONDA_HOME/etc/profile.d/conda.sh"
    fi

    if [ -f "$CONDA_HOME/etc/profile.d/mamba.sh" ]; then
        # shellcheck disable=SC1091
        source "$CONDA_HOME/etc/profile.d/mamba.sh"
    fi

    export PATH="$CONDA_HOME/condabin:$CONDA_HOME/bin:$PATH"
}

sage_env_file_for_host() {
    local python_version="${SAGE_PYTHON_VERSION:-3.12}"

    case "$(uname)-$(uname -m)" in
        Linux-aarch64|Linux-arm64)
            printf 'environment-%s-linux-aarch64.yml\n' "$python_version"
            ;;
        Linux-*)
            printf 'environment-%s-linux.yml\n' "$python_version"
            ;;
        *)
            log_error "Unsupported SageMath host: $(uname -s) $(uname -m)"
            return 1
            ;;
    esac
}

conda_env_exists() {
    local env_name=$1

    "$CONDA_HOME/bin/conda" env list \
        | awk '$1 !~ /^#/ {print $1}' \
        | grep -qx "$env_name"
}

conda_solver() {
    if [ -x "$CONDA_HOME/bin/mamba" ]; then
        printf '%s\n' "$CONDA_HOME/bin/mamba"
    else
        printf '%s\n' "$CONDA_HOME/bin/conda"
    fi
}

install_sage_launcher() {
    local env_name=$1
    local sage_source_dir="${2:-}"
    local launcher_name="${3:-sage-git}"
    local launcher="$BIN_DIR/$launcher_name"

    mkdir -p "$BIN_DIR"

    write_generated_file "$launcher" 0755 << EOF
#!/usr/bin/env bash
set -Eeuo pipefail

export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export CONDA_HOME="${CONDA_HOME}"
export CONDARC="${CONDARC}"
export CONDA_ENVS_PATH="${CONDA_ENVS_PATH}"
export CONDA_PKGS_DIRS="${CONDA_PKGS_DIRS}"

if [ ! -f "\$CONDA_HOME/etc/profile.d/conda.sh" ]; then
    printf '%s\n' "$launcher_name: conda.sh not found under \$CONDA_HOME" >&2
    exit 1
fi

. "\$CONDA_HOME/etc/profile.d/conda.sh"
conda activate "$env_name"

if [ -n "$sage_source_dir" ]; then
    exec "$sage_source_dir/sage" "\$@"
fi

exec sage "\$@"
EOF

    chmod +x "$launcher"
    log_info "Installed SageMath launcher: $launcher"

    if [ ! -e "$BIN_DIR/sage" ]; then
        ln -s "$launcher_name" "$BIN_DIR/sage"
        log_info "Linked $BIN_DIR/sage -> $launcher_name"
    else
        log_warning "$BIN_DIR/sage already exists; leaving it unchanged."
    fi
}

install_sagemath_from_github() {
    local sage_repo_url="${SAGE_REPO_URL:-https://github.com/sagemath/sage.git}"
    local sage_ref="${SAGE_GIT_REF:-develop}"
    local sage_src_dir="${SAGE_SRC_DIR:-$SRC_DIR/sage}"
    local sage_env_name="${SAGE_CONDA_ENV_NAME:-sage-dev}"
    local sage_env_file="${SAGE_ENV_FILE:-$(sage_env_file_for_host)}"
    local solver

    ensure_miniforge
    solver=$(conda_solver)

    if [ -d "$sage_src_dir/.git" ]; then
        log_info "Updating existing SageMath repository in $sage_src_dir"
        cd "$sage_src_dir"
        if ! git diff --quiet || ! git diff --cached --quiet; then
            log_warning "SageMath checkout has local changes; using it without updating."
        else
            git remote get-url upstream >/dev/null 2>&1 || git remote add upstream "$sage_repo_url"
            git remote set-url upstream "$sage_repo_url"
            git fetch upstream --tags
            git checkout "$sage_ref" 2>/dev/null || git checkout -b "$sage_ref" "upstream/$sage_ref"
            git merge --ff-only "upstream/$sage_ref" || {
                log_warning "SageMath checkout cannot be fast-forwarded safely."
                return 1
            }
        fi
    else
        log_info "Cloning SageMath from GitHub ref: $sage_ref"
        git clone -c core.symlinks=true --filter blob:none \
            --origin upstream \
            --branch "$sage_ref" \
            --tags \
            "$sage_repo_url" \
            "$sage_src_dir"
    fi

    cd "$sage_src_dir"

    if [ ! -f "$sage_env_file" ]; then
        log_error "Sage environment file not found: $sage_src_dir/$sage_env_file"
        return 1
    fi

    if conda_env_exists "$sage_env_name"; then
        log_info "Updating SageMath conda environment: $sage_env_name"
        "$solver" env update --name "$sage_env_name" --file "$sage_env_file" --prune
    else
        log_info "Creating SageMath conda environment: $sage_env_name"
        "$solver" env create --name "$sage_env_name" --file "$sage_env_file"
    fi

    log_info "Installing SageMath from GitHub checkout in editable mode..."
    "$CONDA_HOME/bin/conda" run --name "$sage_env_name" \
        python -m pip install --no-build-isolation --editable .

    install_sage_launcher "$sage_env_name" "$sage_src_dir"
    log_success "SageMath installed from GitHub checkout"
}

install_sagemath_from_conda() {
    local sage_env_name="${SAGE_CONDA_ENV_NAME:-sage}"
    local solver

    ensure_miniforge
    solver=$(conda_solver)

    if conda_env_exists "$sage_env_name"; then
        log_info "Updating SageMath conda package environment: $sage_env_name"
        "$solver" install --name "$sage_env_name" -y sage
    else
        log_info "Creating SageMath conda package environment: $sage_env_name"
        "$solver" create --name "$sage_env_name" -y sage
    fi

    install_sage_launcher "$sage_env_name" "" "sage-conda"
    log_success "SageMath installed from conda-forge package"
}

install_sage() {
    log_section "SAGEMATH INSTALLATION"

    SAGE_INSTALL_METHOD="${SAGE_INSTALL_METHOD:-git}"
    log_info "SageMath installation method: $SAGE_INSTALL_METHOD"

    case "$SAGE_INSTALL_METHOD" in
        git|github)
            install_sagemath_from_github
            ;;
        conda)
            install_sagemath_from_conda
            ;;
        *)
            log_error "Unknown SAGE_INSTALL_METHOD='$SAGE_INSTALL_METHOD'. Use git or conda."
            return 1
            ;;
    esac
}
