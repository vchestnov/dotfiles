#!/usr/bin/env bash
set -Eeuo pipefail # Exit on error, undefined var; fail pipelines

# Ubuntu 24.04 Development Environment Bootstrap Script
# This script installs and configures a minimal development environment
# Enhanced with breaks and safepoints for safer execution

# =============================================================================
# SETUP: tools
# =============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_section() {
    echo -e "\n${CYAN}=== $1 ===${NC}\n"
}

# Interactive prompt function
prompt_continue() {
    local message=${1:-"Continue with next section?"}
    local auto_continue=${AUTO_CONTINUE:-false}
    
    if [ "$auto_continue" = "true" ]; then
        log_info "Auto-continue enabled, proceeding..."
        return 0
    fi
    
    echo -e "\n${YELLOW}CHECKPOINT:${NC} $message"
    echo "Options:"
    echo "  [Enter] - Continue"
    echo "  s - Skip this section"
    echo "  q - Quit script"
    echo "  a - Auto-continue for rest of script"
    
    while true; do
        read -p "Choice: " choice
        case $choice in
            ""|c|y|yes) return 0 ;;
            s|skip) return 1 ;;
            q|quit|exit) 
                log_info "Script interrupted by user"
                exit 0 
                ;;
            a|auto)
                export AUTO_CONTINUE=true
                log_info "Auto-continue enabled for remainder of script"
                return 0
                ;;
            *) echo "Invalid choice. Use Enter, s, q, or a" ;;
        esac
    done
}

# Error handling with context
handle_error() {
    local exit_code=$?
    local line_number=$1
    log_error "Script failed at line $line_number with exit code $exit_code"
    log_error "Last command: $BASH_COMMAND"
    if declare -F write_run_status >/dev/null 2>&1; then
        write_run_status failed "$exit_code" || true
    fi
    echo -e "\nYou can:"
    echo "1. Fix the issue and re-run the script"
    echo "2. Skip the failed section and continue manually"
    echo "3. Check the logs above for more details"
    exit $exit_code
}

# Function to ensure sudo credentials stay fresh
refresh_sudo() {
    sudo -v
}

# Set up error trap
trap 'handle_error $LINENO' ERR

# Function to clone and build from git remote
clone_or_update() {
    local repo_url="$1"
    local dest_dir="$2"
    local branch="${3:-}"   # optional branch

    if [ -d "$dest_dir/.git" ]; then
        log_info "Updating existing repository in $dest_dir"
        cd "$dest_dir"

        # Make sure origin URL is up to date (if we change from HTTPS to SSH etc.)
        git remote set-url origin "$repo_url" 2>/dev/null || true

        # If no branch specified, detect default branch from remote
        if [[ -z "$branch" ]]; then
            branch=$(git remote show origin 2>/dev/null \
                        | awk '/HEAD branch/ {print $NF}')

            # Fallback to main/master if detection failed 
            if [[ -z "$branch" ]]; then
                if git ls-remote --heads origin main &>/dev/null; then
                    branch="main"
                elif git ls-remote --heads origin master &>/dev/null; then
                    branch="master"
                else
                    log_warning "Could not determine default branch for $repo_url; using 'main' as fallback."
                    branch="main"
                fi
            fi
        fi

        if ! git diff --quiet || ! git diff --cached --quiet; then
            log_warning "Repository has local changes; using it without updating: $dest_dir"
            return 0
        fi

        # Fetch and fast-forward the chosen branch without rewriting local work.
        git fetch --all --prune

        if [[ -n "$branch" ]]; then
            # Try to checkout an existing local branch, otherwise create a tracking branch.
            if ! git checkout "$branch" 2>/dev/null; then
                git checkout -b "$branch" "origin/$branch" 2>/dev/null || return 1
            fi
            git merge --ff-only "origin/$branch" || {
                log_warning "Repository cannot be fast-forwarded safely: $dest_dir"
                return 1
            }
        else
            git pull --ff-only || return 1
        fi
    else
        log_info "Cloning new repository from $repo_url into $dest_dir"
        if [[ -n "$branch" ]]; then
            git clone --branch "$branch" "$repo_url" "$dest_dir" || return 1
        else
            git clone "$repo_url" "$dest_dir" || return 1
        fi
    fi

    return 0
}

default_build_jobs() {
    local cpu_count
    local jobs

    if command -v nproc >/dev/null 2>&1; then
        cpu_count=$(nproc)
    else
        cpu_count=$(getconf _NPROCESSORS_ONLN 2>/dev/null || printf '1\n')
    fi

    if [ "$cpu_count" -le 2 ]; then
        jobs=1
    else
        jobs=$((cpu_count / 2))
    fi

    if [ "$jobs" -gt 4 ]; then
        jobs=4
    fi

    if [ "$jobs" -lt 1 ]; then
        jobs=1
    fi

    printf '%s\n' "$jobs"
}

# Function to build with make and proper ownership
build_and_install() {
    local project_name=$1
    local build_cmd=${2:-"make -j${BUILD_JOBS:-$(default_build_jobs)}"}
    local install_cmd=${3:-"make install"}
    local install_to_local=${4:-true}
    
    log_info "Building $project_name..."
    
    # Commands are retained as strings for compatibility with existing component
    # definitions. Reject shell substitutions; new installers should use arrays.
    if [[ "$build_cmd" == *'$('* || "$install_cmd" == *'$('* || "$build_cmd" == *'`'* || "$install_cmd" == *'`'* ]]; then
        log_error "Unsafe command substitution in build/install command for $project_name"
        return 1
    fi

    # Build as user.
    bash -c "$build_cmd"
    
    # Install with appropriate permissions
    if [ "$install_to_local" = true ]; then
        # Install to user's local directory
        bash -c "$install_cmd"
        log_info "Installed $project_name to user's local directory"
    else
        # Install system-wide with sudo
        refresh_sudo
        sudo bash -c "$install_cmd"
        log_info "Installed $project_name system-wide"
    fi
}

install_launcher_script() {
    local source_script=$1
    local target_script=$2
    local resolved_source

    if [ ! -f "$source_script" ]; then
        return 1
    fi

    mkdir -p "$(dirname "$target_script")"
    resolved_source="$(readlink -f "$source_script" 2>/dev/null || printf '%s\n' "$source_script")"

    if [ "$resolved_source" = "$(readlink -f "$target_script" 2>/dev/null || printf '%s\n' "$target_script")" ]; then
        chmod +x "$source_script"
        return 0
    fi

    chmod +x "$source_script"
    ln -sfn "$resolved_source" "$target_script"
}

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

install_julia_from_tarball() {
    local install_prefix="${1:-$HOME/.local}"
    local repos_dir="${2:-$HOME/soft}"
    local version="${JULIA_VERSION:-1.12.6}"
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
    local git_ref="${CLANGD_GIT_REF:-llvmorg-21.1.6}"
    local tar_version="${CLANGD_TARBALL_VERSION:-21.1.6}"
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

    tee "$CONDARC" > /dev/null << EOF
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

    tee "$launcher" > /dev/null << EOF
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

    ensure_miniforge || return 1
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

    ensure_miniforge || return 1
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

ensure_git_patch_applied() {
    local patch_file=$1
    local patch_name="${2:-$(basename "$patch_file" .patch)}"

    if [ ! -f "$patch_file" ]; then
        log_warning "Local patch not found: $patch_file"
        return 1
    fi

    if git apply --check "$patch_file" 2>/dev/null; then
        git apply "$patch_file"
        log_success "$patch_name patch applied successfully"
        return 0
    fi

    if git apply --reverse --check "$patch_file" 2>/dev/null; then
        log_info "$patch_name patch already applied"
        return 0
    fi

    log_error "$patch_name patch does not apply cleanly"
    return 1
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

download_file() {
    local url=$1
    local dest=$2

    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$url" -o "$dest"
    elif command -v wget >/dev/null 2>&1; then
        wget "$url" -O "$dest"
    else
        log_warning "Neither curl nor wget is available to download $url."
        return 1
    fi
}

install_nvm_node_tools() {
    : "${XDG_CONFIG_HOME:=$HOME/.config}"
    : "${XDG_DATA_HOME:=$HOME/.local/share}"

    local nvm_version="${NVM_VERSION:-v0.40.4}"
    local node_version="${NODE_VERSION:-lts/*}"
    local nvm_dir="${NVM_DIR:-$XDG_DATA_HOME/nvm}"
    local nvm_env_file="${NVM_ENV_FILE:-$XDG_CONFIG_HOME/nvm/env.sh}"

    local node_packages=(
        @openai/codex
        bash-language-server
        vim-language-server
        vscode-langservers-extracted
        yaml-language-server
        typescript
        typescript-language-server
    )

    if ! command -v git >/dev/null 2>&1; then
        log_warning "git is required to install nvm."
        return 1
    fi

    mkdir -p "$XDG_CONFIG_HOME/nvm" "$XDG_DATA_HOME"

    log_info "Installing/updating nvm $nvm_version in $nvm_dir"
    clone_or_update "https://github.com/nvm-sh/nvm.git" "$nvm_dir" "$nvm_version"

    log_info "Writing nvm environment file: $nvm_env_file"
    tee "$nvm_env_file" > /dev/null << EOF
# nvm / Node.js environment
export NVM_DIR="$nvm_dir"

if [ -s "\$NVM_DIR/nvm.sh" ]; then
    . "\$NVM_DIR/nvm.sh"
fi

if [ -s "\$NVM_DIR/bash_completion" ]; then
    . "\$NVM_DIR/bash_completion"
fi
EOF

    # Load nvm in the current bootstrap session.
    # shellcheck disable=SC1090
    source "$nvm_env_file"

    if ! command -v nvm >/dev/null 2>&1; then
        log_warning "nvm did not load correctly from $nvm_env_file"
        return 1
    fi

    log_info "Installing Node.js version: $node_version"
    nvm install "$node_version"
    nvm alias default "$node_version"
    nvm use default

    log_info "Node version: $(node --version)"
    log_info "npm version: $(npm --version)"

    log_info "Installing npm global tools..."
    npm install -g "${node_packages[@]}"

    if command -v codex >/dev/null 2>&1; then
        log_success "Codex CLI installed: $(command -v codex)"
    else
        log_warning "Codex package installed, but 'codex' is not currently on PATH."
    fi

    log_success "Node/npm tooling installed via nvm"
    log_info "For new shells, source this file from your bashrc/profile:"
    log_info "  source \"$nvm_env_file\""
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
    local version="${POLYMAKE_VERSION:-4.15}"
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

extract_archive_into() {
    local archive=$1
    local dest_dir=$2
    local strip_components="${3:-1}"

    mkdir -p "$dest_dir"
    tar -xf "$archive" -C "$dest_dir" --strip-components="$strip_components"
}

prepare_source_from_tarball() {
    local archive_url=$1
    local archive_path=$2
    local source_dir=$3
    local sentinel_path=$4

    mkdir -p "$(dirname "$archive_path")" "$source_dir"

    if [ ! -f "$archive_path" ]; then
        log_info "Downloading source tarball: $archive_url"
        download_file "$archive_url" "$archive_path"
    fi

    if [ ! -e "$sentinel_path" ]; then
        if [ -z "$(find "$source_dir" -mindepth 1 -maxdepth 1 -print -quit)" ]; then
            extract_archive_into "$archive_path" "$source_dir"
        else
            log_error "$source_dir exists but does not contain expected source tree artifact: $sentinel_path"
            return 1
        fi
    fi
}

configure_make_install() {
    local project_name=$1
    local source_dir=$2
    local install_prefix=$3
    local configure_args=${4:-}
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

    ./configure --prefix="$install_prefix" $configure_args
    build_and_install "$project_name" "make -j$jobs" "make install" true
}

install_notmuch_from_source() {
    local install_prefix="${1:-$HOME/.local}"
    local source_dir="${NOTMUCH_SOURCE_DIR:-$SRC_DIR/notmuch}"
    local source_kind="${NOTMUCH_INSTALL_METHOD:-tar}"
    local archive_version="${NOTMUCH_VERSION:-0.40}"
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
    local archive_version="${ISYNC_VERSION:-1.5.1}"
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
    local archive_version="${MSMTP_VERSION:-1.8.32}"
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
    local archive_ref="${NEOMUTT_VERSION:-20260504}"
    local archive_tag="${archive_ref//-/}"
    local archive_path="$SRC_DIR/neomutt-${archive_tag}.tar.gz"
    local archive_url="${NEOMUTT_TARBALL_URL:-https://github.com/neomutt/neomutt/archive/refs/tags/${archive_tag}.tar.gz}"
    local pkg_config_path="${PKG_CONFIG_PATH:-}"
    local configure_args="--disable-doc"

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
        configure_args="$configure_args --notmuch"
    fi

    if command -v pkg-config >/dev/null 2>&1 && ! pkg-config --exists libidn2; then
        log_info "libidn2 not found; building NeoMutt without IDN support"
        configure_args="$configure_args --disable-idn2"
    fi

    configure_make_install "NeoMutt" "$source_dir" "$install_prefix" "$configure_args"
}

go_linux_arch() {
    local machine

    if [ "$(uname -s)" != "Linux" ]; then
        log_warning "Go toolchain tarball installation currently supports Linux only."
        return 1
    fi

    machine=$(uname -m)
    case "$machine" in
        x86_64|amd64)
            printf 'amd64\n'
            ;;
        i386|i686)
            printf '386\n'
            ;;
        aarch64|arm64)
            printf 'arm64\n'
            ;;
        armv6l|armv7l)
            printf 'armv6l\n'
            ;;
        ppc64le)
            printf 'ppc64le\n'
            ;;
        riscv64)
            printf 'riscv64\n'
            ;;
        s390x)
            printf 's390x\n'
            ;;
        loongarch64)
            printf 'loong64\n'
            ;;
        *)
            log_warning "Unsupported Go release architecture '$machine'."
            return 1
            ;;
    esac
}

install_go_toolchain() {
    local version="${GO_TOOLCHAIN_VERSION:-${GO_TOOLCHAIN_VERSION_DEFAULT:-1.26.5}}"
    local arch
    local toolchain_root
    local install_dir
    local current_link
    local cache_dir
    local archive
    local url
    local env_file
    local tmp_dir

    : "${XDG_CONFIG_HOME:=$HOME/.config}"
    : "${XDG_DATA_HOME:=$HOME/.local/share}"
    : "${XDG_CACHE_HOME:=$HOME/.cache}"

    arch=$(go_linux_arch) || return 1
    toolchain_root="${GO_TOOLCHAIN_ROOT:-$XDG_DATA_HOME/go-toolchains}"
    install_dir="${GO_TOOLCHAIN_INSTALL_DIR:-$toolchain_root/go${version}}"
    current_link="${GO_TOOLCHAIN_CURRENT:-$toolchain_root/current}"
    cache_dir="${GO_TOOLCHAIN_CACHE_DIR:-$XDG_CACHE_HOME/bootstrap/go}"
    archive="$cache_dir/go${version}.linux-${arch}.tar.gz"
    url="${GO_TOOLCHAIN_TARBALL_URL:-https://go.dev/dl/go${version}.linux-${arch}.tar.gz}"
    env_file="${GO_TOOLCHAIN_ENV_FILE:-$SCRIPT_DIR/config/go/env.sh}"

    mkdir -p "$toolchain_root" "$cache_dir" || return 1

    if [ ! -f "$archive" ]; then
        log_info "Downloading Go $version toolchain: $url"
        download_file "$url" "$archive" || return 1
    fi

    if [ -n "${GO_TOOLCHAIN_TARBALL_SHA256:-}" ]; then
        printf '%s  %s\n' "$GO_TOOLCHAIN_TARBALL_SHA256" "$archive" | sha256sum -c - || return 1
    fi

    if [ ! -x "$install_dir/bin/go" ]; then
        log_info "Installing Go $version to $install_dir"
        tmp_dir="$toolchain_root/.go-${version}.tmp.$$"
        rm -rf "$tmp_dir"
        mkdir -p "$tmp_dir" || return 1
        tar -xzf "$archive" -C "$tmp_dir" || return 1
        rm -rf "$install_dir"
        mv "$tmp_dir/go" "$install_dir" || return 1
        rmdir "$tmp_dir" 2>/dev/null || true
    else
        log_info "Go $version already installed at $install_dir"
    fi

    ln -sfn "$install_dir" "$current_link" || return 1

    # shellcheck disable=SC1090
    source "$env_file" || return 1
    hash -r 2>/dev/null || true

    if command -v go >/dev/null 2>&1; then
        log_success "Go toolchain active: $(go version)"
    else
        log_warning "Go toolchain installed, but go is not on PATH."
        return 1
    fi

    log_info "For new shells, source this file from your bashrc/profile:"
    log_info "  source \"\$XDG_CONFIG_HOME/go/env.sh\""
}

git_lfs_linux_arch() {
    local machine

    if [ "$(uname -s)" != "Linux" ]; then
        log_warning "Git LFS tarball installation currently supports Linux release tarballs only."
        return 1
    fi

    machine=$(uname -m)
    case "$machine" in
        x86_64|amd64)
            printf 'amd64\n'
            ;;
        i386|i686)
            printf '386\n'
            ;;
        aarch64|arm64)
            printf 'arm64\n'
            ;;
        armv6l|armv7l)
            printf 'arm\n'
            ;;
        ppc64le)
            printf 'ppc64le\n'
            ;;
        riscv64)
            printf 'riscv64\n'
            ;;
        s390x)
            printf 's390x\n'
            ;;
        loongarch64)
            printf 'loong64\n'
            ;;
        *)
            log_warning "Unsupported Git LFS release architecture '$machine'."
            return 1
            ;;
    esac
}

install_git_lfs() {
    local install_method="${1:-git}"
    local install_prefix="${GIT_LFS_INSTALL_PREFIX:-$HOME/.local}"

    : "${XDG_CACHE_HOME:=$HOME/.cache}"

    if ! command -v git >/dev/null 2>&1; then
        log_warning "git is required to install Git LFS."
        return 1
    fi

    mkdir -p "$install_prefix/bin"

    case "$install_method" in
        git|github)
            local git_ref="${GIT_LFS_GIT_REF:-main}"
            local source_dir="${GIT_LFS_SOURCE_DIR:-$SRC_DIR/git-lfs}"

            if ! command -v make >/dev/null 2>&1; then
                log_warning "make is required for GIT_LFS_INSTALL_METHOD=git."
                return 1
            fi

            if ! command -v go >/dev/null 2>&1; then
                log_warning "Go is required for GIT_LFS_INSTALL_METHOD=git."
                return 1
            fi

            log_info "Installing Git LFS from GitHub ref: $git_ref"
            clone_or_update "https://github.com/git-lfs/git-lfs.git" "$source_dir" "$git_ref" || return 1

            cd "$source_dir"
            make bin/git-lfs || return 1
            install -m 755 bin/git-lfs "$install_prefix/bin/git-lfs" || return 1
            ;;
        tar|tarball)
            local version="${GIT_LFS_VERSION:-3.7.1}"
            local arch
            local cache_dir="${GIT_LFS_CACHE_DIR:-$XDG_CACHE_HOME/bootstrap/git-lfs}"
            local archive
            local source_dir
            local url

            arch=$(git_lfs_linux_arch) || return 1
            archive="$cache_dir/git-lfs-linux-${arch}-v${version}.tar.gz"
            source_dir="${GIT_LFS_TARBALL_DIR:-$SRC_DIR/git-lfs-${version}-linux-${arch}}"
            url="${GIT_LFS_TARBALL_URL:-https://github.com/git-lfs/git-lfs/releases/download/v${version}/git-lfs-linux-${arch}-v${version}.tar.gz}"

            mkdir -p "$cache_dir" "$source_dir"

            if [ ! -f "$archive" ]; then
                log_info "Downloading Git LFS release tarball: $url"
                download_file "$url" "$archive" || return 1
            fi

            if [ ! -x "$source_dir/git-lfs" ]; then
                if [ -z "$(find "$source_dir" -mindepth 1 -maxdepth 1 -print -quit)" ]; then
                    tar -xzf "$archive" -C "$source_dir" --strip-components=1 || return 1
                else
                    log_error "$source_dir exists but does not contain a Git LFS binary."
                    return 1
                fi
            fi

            install -m 755 "$source_dir/git-lfs" "$install_prefix/bin/git-lfs" || return 1

            if [ -d "$source_dir/man" ]; then
                mkdir -p "$install_prefix/share/man"
                cp -R "$source_dir/man/." "$install_prefix/share/man/" || return 1
            fi
            ;;
        *)
            log_error "Unknown GIT_LFS_INSTALL_METHOD='$install_method'. Use git or tar."
            return 1
            ;;
    esac

    export PATH="$install_prefix/bin:$PATH"
    hash -r 2>/dev/null || true

    if [ ! -x "$install_prefix/bin/git-lfs" ]; then
        log_warning "Git LFS install completed, but $install_prefix/bin/git-lfs was not found."
        return 1
    fi

    log_success "Git LFS installed at $install_prefix/bin/git-lfs"
    log_info "Git LFS filters are managed by config/git/config"
}

# =============================================================================
# SETUP: command line, profiles, and resolved execution plan
# =============================================================================

readonly COMPONENTS=(
    core system-base fonts desktop-tools dwm tex gpg python-tools rust-tools
    tree-sitter vim lsp neovim go git-lfs science gmp ntl mpfr flint julia
    qd finiteflow finiteflow32 blade gfan fermat msolve science-extra sage
    polymake singular macaulay2 openxm node email zettelkasten krita messengers media
    system-upgrade remove-nautilus reset-user-dirs wipe-suckless
)
readonly RISKY_COMPONENTS=(system-upgrade remove-nautilus reset-user-dirs wipe-suckless)

usage() {
    cat <<'EOF'
Usage: bootstrap.sh [PROFILE] [OPTIONS]

Profiles: desktop (default), server, nothing, test

Options:
  --dry-run              print the resolved plan without changing the system
  --yes                  apply the normal plan without the confirmation prompt
  --list                 list profiles and components
  --only LIST            replace profile defaults with comma-separated components
  --enable LIST          add comma-separated components
  --skip LIST            remove comma-separated components
  --allow-risky          authorize noninteractive execution of selected risky components
  -h, --help             show this help
EOF
}

reset_components() {
    DO_CORE=0 DO_SYSTEM=0 DO_FONTS=0 DO_DESKTOP_TOOLS=0 DO_DWM=0
    DO_TEX=0 DO_GPG=0 DO_POETRY=0 DO_RUST_TOOLS=0 DO_TREE_SITTER=0
    DO_VIM=0 DO_LSP=0 DO_NEOVIM=0 DO_GO_TOOLCHAIN=0 DO_GIT_LFS=0
    DO_SCI=0 DO_GMP=0 DO_NTL=0 DO_MPFR=0 DO_FLINT=0 DO_JULIA=0
    DO_QD=0 DO_FINITEFLOW=0 DO_FINITEFLOW32=0 DO_BLADE=0 DO_GFAN=0
    DO_FERMAT=0 DO_MSOLVE=0 DO_SCI_EXTRA=0 DO_SAGE=0 DO_POLYMAKE=0
    DO_SINGULAR=0 DO_MACAULAY2=0 DO_ASIR=0 DO_NODE_TOOLS=0 DO_EMAIL=0 DO_ZK=0
    DO_KRITA=0 DO_MESSENGERS=0 DO_MEDIA=0 DO_SYSTEM_UPGRADE=0
    DO_NAUTILUS=0 DO_USER_DIR_RESET=0 DO_SUCKLESS_WIPE=0
}

set_science_components() {
    local value=$1
    DO_SCI=$value DO_GMP=$value DO_NTL=$value DO_MPFR=$value DO_FLINT=$value
    DO_JULIA=$value DO_QD=$value DO_FINITEFLOW=$value DO_FINITEFLOW32=$value
    DO_BLADE=$value DO_GFAN=$value DO_FERMAT=$value DO_MSOLVE=$value
    DO_SCI_EXTRA=$value
}

set_component() {
    local component=$1 value=$2
    case "$component" in
        core) DO_CORE=$value ;;
        system-base) DO_SYSTEM=$value ;;
        fonts) DO_FONTS=$value ;;
        desktop-tools) DO_DESKTOP_TOOLS=$value ;;
        dwm) DO_DWM=$value ;;
        tex) DO_TEX=$value ;;
        gpg) DO_GPG=$value ;;
        python-tools) DO_POETRY=$value ;;
        rust-tools) DO_RUST_TOOLS=$value ;;
        tree-sitter) DO_TREE_SITTER=$value ;;
        vim) DO_VIM=$value ;;
        lsp) DO_LSP=$value ;;
        neovim) DO_NEOVIM=$value ;;
        go) DO_GO_TOOLCHAIN=$value ;;
        git-lfs) DO_GIT_LFS=$value ;;
        science) set_science_components "$value" ;;
        gmp) DO_GMP=$value; if (( value )); then DO_SCI=1; fi ;;
        ntl) DO_NTL=$value; if (( value )); then DO_SCI=1; fi ;;
        mpfr) DO_MPFR=$value; if (( value )); then DO_SCI=1; fi ;;
        flint) DO_FLINT=$value; if (( value )); then DO_SCI=1; fi ;;
        julia) DO_JULIA=$value; if (( value )); then DO_SCI=1; fi ;;
        qd) DO_QD=$value; if (( value )); then DO_SCI=1; fi ;;
        finiteflow) DO_FINITEFLOW=$value; if (( value )); then DO_SCI=1; fi ;;
        finiteflow32) DO_FINITEFLOW32=$value; if (( value )); then DO_SCI=1; fi ;;
        blade) DO_BLADE=$value; if (( value )); then DO_SCI=1; fi ;;
        gfan) DO_GFAN=$value; if (( value )); then DO_SCI=1; fi ;;
        fermat) DO_FERMAT=$value; if (( value )); then DO_SCI=1; fi ;;
        msolve) DO_MSOLVE=$value; if (( value )); then DO_SCI=1; fi ;;
        science-extra) DO_SCI_EXTRA=$value; if (( value )); then DO_SCI=1; fi ;;
        sage) DO_SAGE=$value ;;
        polymake) DO_POLYMAKE=$value ;;
        singular) DO_SINGULAR=$value ;;
        macaulay2) DO_MACAULAY2=$value ;;
        openxm) DO_ASIR=$value ;;
        node) DO_NODE_TOOLS=$value ;;
        email) DO_EMAIL=$value ;;
        zettelkasten)
            DO_ZK=$value
            if (( value )); then DO_CORE=1; fi
            ;;
        krita) DO_KRITA=$value ;;
        messengers) DO_MESSENGERS=$value ;;
        media) DO_MEDIA=$value ;;
        desktop-apps)
            DO_KRITA=$value DO_MESSENGERS=$value DO_MEDIA=$value
            ;;
        system-upgrade)
            DO_SYSTEM_UPGRADE=$value
            if (( value )); then DO_SYSTEM=1; fi
            ;;
        remove-nautilus) DO_NAUTILUS=$value ;;
        reset-user-dirs)
            DO_USER_DIR_RESET=$value
            if (( value )); then DO_CORE=1; fi
            ;;
        wipe-suckless) DO_SUCKLESS_WIPE=$value ;;
        *) log_error "Unknown component: $component"; return 1 ;;
    esac
}

component_enabled() {
    case "$1" in
        core) (( DO_CORE ));; system-base) (( DO_SYSTEM ));; fonts) (( DO_FONTS ));;
        desktop-tools) (( DO_DESKTOP_TOOLS ));; dwm) (( DO_DWM ));; tex) (( DO_TEX ));;
        gpg) (( DO_GPG ));; python-tools) (( DO_POETRY ));; rust-tools) (( DO_RUST_TOOLS ));;
        tree-sitter) (( DO_TREE_SITTER ));; vim) (( DO_VIM ));; lsp) (( DO_LSP ));;
        neovim) (( DO_NEOVIM ));; go) (( DO_GO_TOOLCHAIN ));; git-lfs) (( DO_GIT_LFS ));;
        gmp) (( DO_GMP ));; ntl) (( DO_NTL ));; mpfr) (( DO_MPFR ));;
        flint) (( DO_FLINT ));; julia) (( DO_JULIA ));; qd) (( DO_QD ));;
        finiteflow) (( DO_FINITEFLOW ));; finiteflow32) (( DO_FINITEFLOW32 ));;
        blade) (( DO_BLADE ));; gfan) (( DO_GFAN ));; fermat) (( DO_FERMAT ));;
        msolve) (( DO_MSOLVE ));; science-extra) (( DO_SCI_EXTRA ));;
        sage) (( DO_SAGE ));; polymake) (( DO_POLYMAKE ));; singular) (( DO_SINGULAR ));;
        macaulay2) (( DO_MACAULAY2 ));;
        openxm) (( DO_ASIR ));; node) (( DO_NODE_TOOLS ));; email) (( DO_EMAIL ));;
        zettelkasten) (( DO_ZK ));; krita) (( DO_KRITA ));;
        messengers) (( DO_MESSENGERS ));; media) (( DO_MEDIA ));;
        system-upgrade) (( DO_SYSTEM_UPGRADE ));; remove-nautilus) (( DO_NAUTILUS ));;
        reset-user-dirs) (( DO_USER_DIR_RESET ));; wipe-suckless) (( DO_SUCKLESS_WIPE ));;
        *) return 1 ;;
    esac
}

component_method() {
    case "$1" in
        system-base|fonts|desktop-tools|macaulay2|messengers|media|system-upgrade|remove-nautilus)
            printf 'apt/system'
            ;;
        core|zettelkasten|reset-user-dirs) printf 'configuration' ;;
        dwm) printf 'source + system integration' ;;
        tex) printf 'upstream installer' ;;
        gpg) printf 'apt + repository config' ;;
        python-tools) printf 'pipx' ;;
        rust-tools) printf 'rustup/cargo + git' ;;
        tree-sitter) printf 'cargo' ;;
        vim|neovim) printf 'git source' ;;
        lsp) printf 'local/upstream toolchains' ;;
        go|julia) printf 'pinned upstream tarball' ;;
        git-lfs) printf 'git source' ;;
        gmp|ntl|mpfr|flint|gfan|fermat|singular) printf 'pinned source release' ;;
        qd|finiteflow|finiteflow32|blade|msolve|science-extra|sage|polymake|openxm)
            printf 'tracked upstream source'
            ;;
        node) printf 'nvm/npm' ;;
        email) printf 'pinned source release' ;;
        krita) printf 'pinned AppImage' ;;
        wipe-suckless) printf 'local cleanup' ;;
        *) printf 'configured installer' ;;
    esac
}

apply_component_list() {
    local list=$1 value=$2 item
    [ -z "$list" ] && return 0
    IFS=',' read -r -a items <<< "$list"
    for item in "${items[@]}"; do
        [ -n "$item" ] || continue
        set_component "$item" "$value"
    done
}

apply_profile() {
    reset_components
    case "$BOOTSTRAP_PROFILE" in
        desktop)
            for component in core system-base fonts desktop-tools dwm tex gpg python-tools \
                rust-tools tree-sitter vim lsp neovim go git-lfs science sage polymake \
                singular macaulay2 openxm node email zettelkasten; do
                set_component "$component" 1
            done
            ;;
        server)
            for component in core rust-tools tree-sitter vim lsp neovim go git-lfs \
                science sage polymake openxm node email; do
                set_component "$component" 1
            done
            set_component qd 0
            ;;
        nothing) ;;
        test)
            set_component go 1
            set_component git-lfs 1
            ;;
        *) log_error "Unknown profile '$BOOTSTRAP_PROFILE'."; usage; exit 2 ;;
    esac
}

BOOTSTRAP_PROFILE="${BOOTSTRAP_PROFILE:-desktop}"
ONLY_COMPONENTS=""
ENABLE_COMPONENTS=""
SKIP_COMPONENTS=""
DRY_RUN=false
ASSUME_YES=false
ALLOW_RISKY=false
LIST_ONLY=false
profile_seen=false

while (( $# )); do
    case "$1" in
        desktop|server|nothing|test)
            if $profile_seen; then log_error "Only one profile may be selected."; exit 2; fi
            BOOTSTRAP_PROFILE=$1
            profile_seen=true
            shift
            ;;
        --dry-run) DRY_RUN=true; shift ;;
        --yes) ASSUME_YES=true; shift ;;
        --allow-risky) ALLOW_RISKY=true; shift ;;
        --list) LIST_ONLY=true; shift ;;
        --only|--enable|--skip)
            option=$1
            (( $# >= 2 )) || { log_error "$option requires a value."; exit 2; }
            case "$option" in
                --only) ONLY_COMPONENTS=$2 ;;
                --enable) ENABLE_COMPONENTS=$2 ;;
                --skip) SKIP_COMPONENTS=$2 ;;
            esac
            shift 2
            ;;
        --only=*) ONLY_COMPONENTS=${1#*=}; shift ;;
        --enable=*) ENABLE_COMPONENTS=${1#*=}; shift ;;
        --skip=*) SKIP_COMPONENTS=${1#*=}; shift ;;
        -h|--help) usage; exit 0 ;;
        *) log_error "Unknown argument: $1"; usage; exit 2 ;;
    esac
done

if $LIST_ONLY; then
    printf 'Profiles: desktop server nothing test\n'
    printf 'Components:\n  %s\n' "${COMPONENTS[*]}"
    printf 'Alias:\n  desktop-apps = krita,messengers,media\n'
    exit 0
fi

apply_profile
if [ -n "$ONLY_COMPONENTS" ]; then
    reset_components
    apply_component_list "$ONLY_COMPONENTS" 1
fi
apply_component_list "$ENABLE_COMPONENTS" 1
apply_component_list "$SKIP_COMPONENTS" 0

if (( DO_ZK && ! DO_CORE )); then
    log_error "zettelkasten requires core; remove '--skip core' or skip zettelkasten too."
    exit 2
fi
if (( DO_USER_DIR_RESET && ! DO_CORE )); then
    log_error "reset-user-dirs requires core; remove '--skip core' or skip reset-user-dirs too."
    exit 2
fi
if (( DO_SYSTEM_UPGRADE && ! DO_SYSTEM )); then
    log_error "system-upgrade requires system-base; remove '--skip system-base'."
    exit 2
fi

SELECTED_COMPONENTS=()
SELECTED_RISKY=()
for component in "${COMPONENTS[@]}"; do
    if component_enabled "$component"; then SELECTED_COMPONENTS+=("$component"); fi
done
for component in "${RISKY_COMPONENTS[@]}"; do
    if component_enabled "$component"; then SELECTED_RISKY+=("$component"); fi
done

log_section "RESOLVED BOOTSTRAP PLAN"
log_info "Profile: $BOOTSTRAP_PROFILE"
if (( ${#SELECTED_COMPONENTS[@]} )); then
    for component in "${SELECTED_COMPONENTS[@]}"; do
        printf '  %-20s %s\n' "$component" "$(component_method "$component")"
    done
else
    printf '  (no components selected)\n'
fi
if (( ${#SELECTED_RISKY[@]} )); then
    log_warning "Risky opt-ins: ${SELECTED_RISKY[*]}"
fi

if $DRY_RUN; then
    log_success "Dry run completed; no changes were made."
    exit 0
fi

if $ASSUME_YES && (( ${#SELECTED_RISKY[@]} )) && ! $ALLOW_RISKY; then
    log_error "Risky components require --allow-risky when --yes is used."
    exit 2
fi

if ! $ASSUME_YES; then
    read -r -p "Apply this plan? [y/N] " confirm
    [[ "$confirm" =~ ^[Yy]([Ee][Ss])?$ ]] || { log_info "Cancelled."; exit 0; }
fi

# The execution plan has been approved; legacy component checkpoints now run
# noninteractively. Component selection remains controlled by the profile flags.
export AUTO_CONTINUE=true
log_info "Using bootstrap profile: $BOOTSTRAP_PROFILE"

# =============================================================================
# SETUP: pre-flight checks
# =============================================================================
log_section "PRE-FLIGHT CHECKS"

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   log_error "This script should not be run as root or with sudo"
   log_error "The script will prompt for sudo when needed for specific operations"
   exit 1
fi

# # Check internet connectivity
# log_info "Checking internet connectivity..."
# if ! ping -c 1 github.com &>/dev/null; then
#     log_error "No internet connection detected. Please check your connection."
#     exit 1
# fi

if [[ "$BOOTSTRAP_PROFILE" == "desktop" ]]; then
    # Check Ubuntu version
    if ! grep -q "Ubuntu 24.04" /etc/os-release 2>/dev/null; then
        log_warning "This script is designed for Ubuntu 24.04"
        if ! prompt_continue "Continue anyway?"; then
            exit 1
        fi
    fi

    # Check disk space (need at least 2GB free)
    available_space=$(df / | awk 'NR==2 {print $4}')
    if [ "$available_space" -lt 2097152 ]; then  # 2GB in KB
        log_warning "Less than 2GB free space available. Consider freeing up space."
        if ! prompt_continue "Continue anyway?"; then
            exit 1
        fi
    fi

# # Check if sudo is available and cache credentials
# log_info "Checking sudo access..."
# if ! sudo -n true 2>/dev/null; then
#     log_info "Please enter your password to cache sudo credentials:"
#     sudo -v
# fi

    if (( DO_SYSTEM || DO_FONTS || DO_DESKTOP_TOOLS || DO_DWM || DO_TEX || DO_GPG || DO_MACAULAY2 || DO_KRITA || DO_MESSENGERS || DO_MEDIA )) && command -v sudo >/dev/null 2>&1; then
        log_info "Checking sudo access..."
        if ! sudo -n true 2>/dev/null; then
            log_info "Please enter your password to cache sudo credentials:"
            sudo -v
        fi
    elif (( DO_SYSTEM || DO_FONTS || DO_DESKTOP_TOOLS || DO_DWM || DO_TEX || DO_GPG || DO_MACAULAY2 || DO_KRITA || DO_MESSENGERS || DO_MEDIA )); then
        log_warning "sudo not found — skipping sudo warm-up."
    fi
else
    log_info "Skipping some checks for profile: $BOOTSTRAP_PROFILE"
fi

log_success "Pre-flight checks completed"

# =============================================================================
# SETUP: build, src, and bin dirs 
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
BUILD_DIR="${BUILD_DIR:-$XDG_CACHE_HOME/bootstrap/build}"
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
SRC_DIR="${SRC_DIR:-$HOME/soft}"

# Central release defaults. Git-based scientific projects intentionally track
# their configured upstream branch; release-only dependencies remain explicit.
: "${JULIA_VERSION:=1.12.6}"
: "${GMP_VERSION:=6.3.0}"
: "${NTL_VERSION:=11.6.0}"
: "${MPFR_VERSION:=4.2.2}"
: "${FLINT_VERSION:=3.4.0}"
: "${GFAN_VERSION:=0.7}"
: "${CDDLIB_VERSION:=094i}"
: "${SINGULAR_TAG:=Release-4-4-1}"
: "${GO_TOOLCHAIN_VERSION:=1.26.5}"
: "${GIT_LFS_VERSION:=3.7.1}"
: "${CLANGD_TARBALL_VERSION:=21.1.6}"
: "${NVM_VERSION:=v0.40.4}"
: "${KRITA_VERSION:=5.2.11}"
: "${CLANGD_INSTALL_METHOD_DEFAULT:=tar}"
: "${GIT_LFS_INSTALL_METHOD_DEFAULT:=git}"

APT_UPDATED=false
apt_refresh() {
    local mode=${1:-cached}
    if ! $APT_UPDATED || [ "$mode" = force ]; then
        refresh_sudo
        sudo apt update
        APT_UPDATED=true
    fi
}

apt_install() {
    apt_refresh
    refresh_sudo
    sudo apt install -y "$@"
}

write_run_status() {
    local status=$1 exit_code=${2:-0}
    local state_dir="$XDG_STATE_HOME/bootstrap"
    mkdir -p "$state_dir"
    {
        printf 'status=%s\n' "$status"
        printf 'exit_code=%s\n' "$exit_code"
        printf 'profile=%s\n' "$BOOTSTRAP_PROFILE"
        printf 'finished_at=%s\n' "$(date --iso-8601=seconds)"
        printf 'selected_components=%s\n' "${SELECTED_COMPONENTS[*]}"
    } > "$state_dir/last-run"
}

ensure_cargo_toolchain() {
    export CARGO_HOME="${CARGO_HOME:-$XDG_DATA_HOME/cargo}"
    export RUSTUP_HOME="${RUSTUP_HOME:-$XDG_DATA_HOME/rustup}"

    mkdir -p "$BIN_DIR" "$CARGO_HOME" "$RUSTUP_HOME"

    if ! command -v cargo >/dev/null 2>&1; then
        log_info "Installing Rust..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    fi

    if [ -f "$CARGO_HOME/env" ]; then
        # shellcheck disable=SC1090
        source "$CARGO_HOME/env"
    fi

    export PATH="$BIN_DIR:$CARGO_HOME/bin:$PATH"
}

# =============================================================================
# SECTION 01: DIRECTORY SETUP
# =============================================================================

if \
    (( DO_CORE )) && \
    prompt_continue "Set up directory structure and PATH?" && \
    : \
; then
    log_section "DIRECTORY SETUP"
    
    log_info "Creating directory structure..."
    mkdir -p "$BUILD_DIR" "$BIN_DIR" "$SRC_DIR"

    # The repository-managed profile owns persistent PATH configuration.
    if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
        export PATH="$BIN_DIR:$PATH"
        log_info "Added $BIN_DIR to PATH for this run"
    fi

    log_success "Directory structure created"
fi

# =============================================================================
# SECTION 02: SYSTEM PACKAGES
# =============================================================================

if \
    (( DO_SYSTEM )) && \
    prompt_continue "Update system and install build dependencies?" && \
    : \
; then
    log_section "SYSTEM PACKAGES UPDATE"
    
    log_info "Refreshing Ubuntu package metadata..."
    apt_refresh
    if (( DO_SYSTEM_UPGRADE )); then
        log_warning "Applying explicitly requested full system upgrade"
        sudo apt upgrade -y
    fi

    log_info "Installing system packages and build dependencies..."
    apt_install \
        build-essential \
        git \
        curl \
        wget \
        pkg-config \
        autoconf \
        automake \
        libtool \
        cmake \
        ninja-build \
        unzip \
        gettext \
        libboost-dev \
        libjson-perl \
        libperl-dev \
        libreadline-dev \
        libterm-readkey-perl \
        libterm-readline-gnu-perl \
        libxml-perl \
        libxml-sax-perl \
        libxml-writer-perl \
        libxml2-dev \
        libxslt1-dev \
        xclip \
        libx11-dev \
        libxt-dev \
        libxpm-dev \
        libxext-dev \
        x11proto-dev \
        libxft-dev \
        libxinerama-dev \
        libfreetype6-dev \
        fontconfig \
        libfontconfig1-dev \
        libharfbuzz-dev \
        libxrandr-dev \
        libimlib2-dev \
        libxss-dev \
        libjpeg-dev \
        libpng-dev \
        libtiff-dev \
        zlib1g-dev \
        libncurses5-dev \
        libncursesw5-dev \
        lua5.1 \
        liblua5.1-0-dev \
        python3-dev \
        ruby-dev \
        tcl-dev \
        mupdf-tools \
        libmupdf-dev \
        libpoppler-glib-dev \
        libmagic-dev \
        tmux \
        htop \
        efivar \
        bluetooth \
        bluez \
        bluez-tools \
        rfkill \
        blueman \
        libxcb-cursor0 \
        lm-sensors \
        rename \
        python3-full \
        acpi \
        picom \
        meson \
        libgtk-3-dev \
        libgirara-dev \
        libsqlite3-dev \
        libsynctex-dev \
        libjson-glib-dev \
        libdjvulibre-dev \
        ncal \
        qpdf \
        pipx \
        brightnessctl \
        libxcb-xtest0 \
        pavucontrol \
        libboost-all-dev \
        libxapian-dev \
        libgmime-3.0-dev \
        libtalloc-dev

    log_success "System packages and build dependencies installed"
fi

# =============================================================================
# SECTION 03: HOME DIRECTORY CLEANUP
# =============================================================================

if \
    (( DO_CORE )) && \
    prompt_continue "Set up clean home directory structure?" && \
    : \
; then
    log_section "HOME DIRECTORY CLEANUP"
    
    # Clean home directory setup
    log_info "Setting up clean home directory structure..."

    # Create main directories
    mkdir -p "$HOME/dev" "$HOME/docs/downloads" "$HOME/soft"

    # Zettelkasten + templates
    if \
        (( DO_ZK )) && \
        : \
    ; then
        mkdir -p \
            "$HOME/dev/zk" \
            "$HOME/dev/templates" \
            "$HOME/dev/templates/latex"
    fi

    if (( DO_USER_DIR_RESET )); then
        log_warning "Resetting Ubuntu user directories by explicit request"
        for dir in Desktop Documents Downloads Music Pictures Public Templates Videos; do
            if [ -d "$HOME/$dir" ] && [ -z "$(ls -A "$HOME/$dir" 2>/dev/null)" ]; then
                rmdir "$HOME/$dir" 2>/dev/null && log_info "Removed empty $dir directory"
            elif [ -d "$HOME/$dir" ]; then
                log_warning "$dir directory is not empty, skipping removal"
            fi
        done

        mkdir -p "$XDG_CONFIG_HOME"
        tee "$XDG_CONFIG_HOME/user-dirs.dirs" > /dev/null << 'EOF'
XDG_DESKTOP_DIR="$HOME/docs"
XDG_DOWNLOAD_DIR="$HOME/docs/downloads"
XDG_TEMPLATES_DIR="$HOME/docs"
XDG_PUBLICSHARE_DIR="$HOME/docs"
XDG_DOCUMENTS_DIR="$HOME/docs"
XDG_MUSIC_DIR="$HOME/docs"
XDG_PICTURES_DIR="$HOME/docs"
XDG_VIDEOS_DIR="$HOME/docs"
EOF

        tee "$XDG_CONFIG_HOME/user-dirs.conf" > /dev/null << 'EOF'
enabled=False
EOF
    fi

    log_success "Clean home directory structure created"
fi

# =============================================================================
# SECTION 04: NAUTILUS REMOVAL
# =============================================================================

if \
    (( DO_NAUTILUS )) && \
    prompt_continue "Remove Ubuntu file manager (Nautilus)?" && \
    : \
; then
    log_section "NAUTILUS REMOVAL"
    
    # Remove Ubuntu file manager (Nautilus)
    log_info "Removing Ubuntu file manager (Nautilus)..."
    refresh_sudo
    sudo apt remove -y nautilus nautilus-extension-gnome-terminal 2>/dev/null || true
    log_success "Ubuntu file manager removed"
fi

# =============================================================================
# SECTION 06: FONT CONFIGURATION
# =============================================================================

if \
	(( DO_FONTS )) && \
	prompt_continue "Install fonts and configure fontconfig?" && \
	: \
; then
    log_section "FONT CONFIGURATION"
    
    # Font-based emoji crash fix - install proper fonts and configure fontconfig
    log_info "Installing fonts and configuring fontconfig to prevent emoji crashes..."

    # Install essential fonts including non-color emoji fonts
    refresh_sudo
    apt_install \
        fonts-liberation \
        fonts-liberation2 \
        fonts-dejavu \
        fonts-dejavu-core \
        fonts-dejavu-extra \
        fonts-noto-mono \
        fonts-noto-core \
        fonts-symbola \
        fonts-font-awesome \
        fonts-powerline \
        fonts-jetbrains-mono

    # Create fontconfig directory
    mkdir -p "$HOME/.config/fontconfig"

    # Create fontconfig configuration to handle emoji properly
    tee "$HOME/.config/fontconfig/fonts.conf" > /dev/null << 'EOF'
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <!-- Set default fonts -->
  <alias>
    <family>sans-serif</family>
    <prefer>
      <family>Liberation Sans</family>
      <family>DejaVu Sans</family>
      <family>Noto Sans</family>
    </prefer>
  </alias>
  
  <alias>
    <family>serif</family>
    <prefer>
      <family>Liberation Serif</family>
      <family>DejaVu Serif</family>
      <family>Noto Serif</family>
    </prefer>
  </alias>
  
  <alias>
    <family>monospace</family>
    <prefer>
      <family>Liberation Mono</family>
      <family>DejaVu Sans Mono</family>
      <family>Noto Sans Mono</family>
    </prefer>
  </alias>

  <!-- Emoji handling - prefer Symbola (monochrome) over color emoji fonts -->
  <alias>
    <family>emoji</family>
    <prefer>
      <family>Symbola</family>
    </prefer>
  </alias>

  <!-- Disable color emoji fonts for suckless tools -->
  <selectfont>
    <rejectfont>
      <pattern>
        <patelt name="family">
          <string>Noto Color Emoji</string>
        </patelt>
      </pattern>
    </rejectfont>
    <rejectfont>
      <pattern>
        <patelt name="family">
          <string>Apple Color Emoji</string>
        </patelt>
      </pattern>
    </rejectfont>
  </selectfont>

  <!-- Fallback chain for symbols and emoji -->
  <alias>
    <family>sans-serif</family>
    <prefer>
      <family>Liberation Sans</family>
      <family>DejaVu Sans</family>
      <family>Symbola</family>
    </prefer>
  </alias>

  <alias>
    <family>monospace</family>
    <prefer>
      <family>Liberation Mono</family>
      <family>DejaVu Sans Mono</family>
      <family>Symbola</family>
    </prefer>
  </alias>
</fontconfig>
EOF

    # Refresh font cache
    fc-cache -fv

    log_success "Fonts installed and fontconfig configured to prevent emoji crashes"
fi

# =============================================================================
# SECTION 08: VIM FROM SOURCE
# =============================================================================

if \
	(( DO_VIM )) && \
	prompt_continue "Build Vim from source?" && \
	: \
; then
    log_section "VIM INSTALLATION"
    
    # Build Vim from source with terminal and xclip support
    log_info "Building Vim from source..."
    clone_or_update "https://github.com/vim/vim.git" "$SRC_DIR/vim"

    cd "$SRC_DIR/vim"
    make distclean 2>/dev/null || true

    ./configure \
        --with-features=huge \
        --enable-multibyte \
        --enable-rubyinterp=yes \
        --enable-python3interp=yes \
        --enable-perlinterp=yes \
        --enable-luainterp=yes \
        --enable-gui=no \
        --enable-cscope \
        --enable-terminal \
        --with-x \
        --enable-clipboard \
        --prefix="$HOME/.local" \
        --disable-xsmp \
        --disable-xsmp-interact

    build_and_install "Vim" "make -j${BUILD_JOBS:-$(default_build_jobs)}" "make install" true

    : "${XDG_CACHE_HOME:=$HOME/.cache}";
    mkdir -p "$XDG_CACHE_HOME/vim/"{swap,undo,backup}

log_success "Vim installed with terminal and xclip support"
fi

# =============================================================================
# SECTION 09: LANGUAGE SERVER TOOLING
# =============================================================================

if \
    (( DO_LSP )) && \
    prompt_continue "Install language servers and Vim LSP tooling?" && \
    : \
; then
    log_section "LANGUAGE SERVER TOOLING"

    mkdir -p "$BIN_DIR"
    CLANGD_INSTALL_METHOD="${CLANGD_INSTALL_METHOD:-${CLANGD_INSTALL_METHOD_DEFAULT:-git}}"
    if [ "$CLANGD_INSTALL_METHOD" = "auto" ]; then
        if (( DO_SYSTEM )) && command -v sudo >/dev/null 2>&1; then
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
            if (( DO_SYSTEM )) && command -v sudo >/dev/null 2>&1; then
                log_info "Installing clangd from apt..."
                refresh_sudo
                apt_install clangd
                log_success "clangd installed"
            else
                log_warning "apt-based clangd install requested, but this profile does not permit it."
            fi
            ;;
        git|tar)
            log_info "Installing clangd from source into $HOME/.local"
            if ! install_clangd_from_source "$CLANGD_INSTALL_METHOD" "$HOME/.local"; then
                log_warning "clangd source installation failed."
            fi
            ;;
        *)
            log_warning "Unknown CLANGD_INSTALL_METHOD='$CLANGD_INSTALL_METHOD'. Use auto, apt, git, or tar."
            ;;
    esac

    log_info "Installing Python language server (pylsp)..."
    if install_python_lsp; then
        log_success "Python language server installed"
    else
        log_warning "Skipping Python LSP installation"
    fi

    if [ -f "$SCRIPT_DIR/scripts/julia-lsp" ]; then
        install_launcher_script "$SCRIPT_DIR/scripts/julia-lsp" "$BIN_DIR/julia-lsp"
        log_info "Installed Julia LSP launcher to $BIN_DIR/julia-lsp"
    fi

    log_info "Installing Julia language server (LanguageServer.jl)..."
    if install_julia_lsp; then
        log_success "Julia language server installed"
    else
        log_warning "Skipping Julia LSP installation"
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
            log_warning "Could not install the official Wolfram LSP paclets automatically."
            log_warning "If needed, run from a Wolfram session:"
            log_warning '  PacletInstall["CodeParser"]; PacletInstall["CodeInspector"]; PacletInstall["CodeFormatter"]; PacletInstall["LSPServer"];'
        fi
    else
        log_warning "Wolfram tools not found on PATH; skipping Mathematica LSP bootstrap."
    fi

    if command -v vim >/dev/null 2>&1; then
        log_info "Installing/updating Vim plugins for LSP support..."
        vim +'silent! PlugInstall --sync' +qa || log_warning "Vim plugin installation did not complete cleanly."
    else
        log_warning "vim not found on PATH; skipping plugin installation."
    fi

    log_success "Language server tooling setup completed"
fi

# =============================================================================
# SECTION 10: RUST TOOLS (FZF, RIPGREP, FD, BAT)
# =============================================================================

if \
    (( DO_RUST_TOOLS )) && \
    prompt_continue "Install Rust and Rust-based tools (fzf, ripgrep, fd, bat)?" && \
    : \
; then

    log_section "RUST TOOLS INSTALLATION"

    ensure_cargo_toolchain

    # Install fzf from git
    log_info "Installing fzf..."
    clone_or_update "https://github.com/junegunn/fzf.git" "$SRC_DIR/fzf"
    cd "$SRC_DIR/fzf"
    make install
    cp bin/fzf "$BIN_DIR/"

    # Install fzf shell integration
    "$SRC_DIR/fzf/install" --bin --key-bindings --completion --no-update-rc

    log_success "fzf installed"

    # Install ripgrep (rg) from git
    log_info "Installing ripgrep..."
    clone_or_update "https://github.com/BurntSushi/ripgrep.git" "$SRC_DIR/ripgrep"
    cd "$SRC_DIR/ripgrep"
    cargo build --release
    cp target/release/rg "$BIN_DIR/"

    log_success "ripgrep installed"

    # Install fd from git
    log_info "Installing fd..."
    clone_or_update "https://github.com/sharkdp/fd.git" "$SRC_DIR/fd"
    cd "$SRC_DIR/fd"
    cargo build --release
    cp target/release/fd "$BIN_DIR/"

    log_success "fd installed"

	# Install bat from git 
	log_info "Installing bat..."

	clone_or_update "https://github.com/sharkdp/bat.git" "$SRC_DIR/bat"
	cd "$SRC_DIR/bat"
	cargo build --release
	cp target/release/bat "$BIN_DIR"

	log_success "bat installed"
else
    log_info "Skipping Rust tools installation."
fi

# =============================================================================
# SECTION 11: TREE-SITTER CLI
# =============================================================================

if \
    (( DO_TREE_SITTER )) && \
    prompt_continue "Install tree-sitter CLI for custom Neovim parsers?" && \
    : \
; then

    log_section "TREE-SITTER CLI INSTALLATION"

    ensure_cargo_toolchain

    TREE_SITTER_CLI_ROOT="${TREE_SITTER_CLI_ROOT:-$HOME/.local}"

    log_info "Installing/updating tree-sitter CLI..."
    if cargo install --locked tree-sitter-cli --root "$TREE_SITTER_CLI_ROOT"; then
        :
    else
        log_warning "Full tree-sitter CLI build failed; retrying without the QuickJS runtime feature."
        log_warning "This fallback is usually enough for building parsers from repos that already ship generated C sources."
        cargo install --locked --no-default-features tree-sitter-cli --root "$TREE_SITTER_CLI_ROOT"
    fi

    hash -r 2>/dev/null || true

    if [ -x "$TREE_SITTER_CLI_ROOT/bin/tree-sitter" ]; then
        log_success "tree-sitter CLI installed at $TREE_SITTER_CLI_ROOT/bin/tree-sitter"
    elif command -v tree-sitter >/dev/null 2>&1; then
        log_success "tree-sitter CLI installed at $(command -v tree-sitter)"
    else
        log_warning "tree-sitter install completed, but the binary is not on PATH yet."
    fi
else
    log_info "Skipping tree-sitter CLI installation."
fi

# =============================================================================
# SECTION 12: GO TOOLCHAIN
# =============================================================================

if \
    (( DO_GO_TOOLCHAIN )) && \
    prompt_continue "Install current Go toolchain locally?" && \
    : \
; then
    log_section "GO TOOLCHAIN INSTALLATION"

    GO_TOOLCHAIN_VERSION="${GO_TOOLCHAIN_VERSION:-${GO_TOOLCHAIN_VERSION_DEFAULT:-1.26.5}}"
    log_info "Go toolchain version: $GO_TOOLCHAIN_VERSION"

    if install_go_toolchain; then
        log_success "Go toolchain setup completed"
    else
        log_warning "Go toolchain setup failed or was skipped"
    fi
else
    log_info "Skipping Go toolchain installation."
fi

# =============================================================================
# SECTION 12A: GIT LFS
# =============================================================================

if \
    (( DO_GIT_LFS )) && \
    prompt_continue "Install Git LFS from GitHub source or release tarball?" && \
    : \
; then
    log_section "GIT LFS INSTALLATION"

    GIT_LFS_INSTALL_METHOD="${GIT_LFS_INSTALL_METHOD:-${GIT_LFS_INSTALL_METHOD_DEFAULT:-git}}"
    log_info "Git LFS installation method: $GIT_LFS_INSTALL_METHOD"

    if install_git_lfs "$GIT_LFS_INSTALL_METHOD"; then
        log_success "Git LFS setup completed"
    else
        log_warning "Git LFS setup failed or was skipped"
    fi
else
    log_info "Skipping Git LFS installation."
fi

# =============================================================================
# SECTION 13: pre NUCLEAR OPTION: WIPE ALL SUCKLESS TOOLS
# =============================================================================

# Nuclear option - wipe all suckless tools and start completely fresh
if \
		(( DO_SUCKLESS_WIPE )) && \
	prompt_continue "Start completely fresh? (removes all existing suckless directories)" && \
	: \
; then
    log_info "Removing all existing suckless directories..."
    rm -rf "$SRC_DIR/dwm" "$SRC_DIR/dmenu" "$SRC_DIR/st" "$SRC_DIR/slstatus" "$SRC_DIR/slock"
fi

# =============================================================================
# SECTION 14: SUCKLESS TOOLS (DWM)
# =============================================================================

if \
	(( DO_DWM )) && \
	prompt_continue "Build dwm (dynamic window manager)?" && \
	: \
; then
    log_section "DWM INSTALLATION"
    
    # Build dwm
    log_info "Building dwm..."
    clone_or_update "https://git.suckless.org/dwm" "$SRC_DIR/dwm"
    cd "$SRC_DIR/dwm"

    # Create config.h from config.def.h if it doesn't exist
    if [ ! -f config.h ]; then
        cp config.def.h config.h
    fi

    # Popular dwm patches info
    tee patches_info.txt > /dev/null << 'EOF'
Popular dwm patches to consider:
1. pertag - Per-tag settings
2. gaps - Gaps between windows
3. statuscolors - Colored text in status bar
4. systray - System tray support
5. fullgaps - Configurable gaps
6. autostart - Autostart applications
7. restartsig - Restart dwm without logging out
8. adjacenttag - Navigate to adjacent tags
9. actualfullscreen - True fullscreen
10. sticky - Make windows stick across tags

EMOJI CRASH FIX: Fixed via fontconfig - no source modifications needed

To apply patches:
1. Download patch from https://dwm.suckless.org/patches/
2. Apply with: patch -p1 < patchfile.diff
3. Resolve conflicts if any
4. Rebuild with make clean install
EOF

    build_and_install "dwm" "make clean && make -j${BUILD_JOBS:-$(default_build_jobs)}" "make install" false

    log_success "dwm installed with font-based emoji crash fix"
fi

# =============================================================================
# SECTION 15: SUCKLESS TOOLS (DMENU)
# =============================================================================

if \
	(( DO_DWM )) && \
	prompt_continue "Build dmenu?" && \
	: \
; then
    log_section "DMENU INSTALLATION"
    
    # Build dmenu
    log_info "Building dmenu..."
    clone_or_update "https://git.suckless.org/dmenu" "$SRC_DIR/dmenu"
    cd "$SRC_DIR/dmenu"

    if [ ! -f config.h ]; then
        cp config.def.h config.h
    fi

    # Popular dmenu patches info
    tee patches_info.txt > /dev/null << 'EOF'
Popular dmenu patches to consider:
1. center - Center dmenu on screen
2. fuzzymatch - Fuzzy matching
3. border - Add border around dmenu
4. lineheight - Adjust line height
5. password - Password input mode
6. case-insensitive - Case insensitive matching
7. instant - Show results instantly
8. numbers - Show number of matches
9. highlight - Highlight matched characters
10. grid - Grid layout for results

EMOJI CRASH FIX: Fixed via fontconfig - no source modifications needed
EOF

    build_and_install "dmenu" "make clean && make -j${BUILD_JOBS:-$(default_build_jobs)}" "make install" false

    log_success "dmenu installed with font-based emoji crash fix"
fi

# =============================================================================
# SECTION 16: SUCKLESS TOOLS (ST TERMINAL)
# =============================================================================

if \
	(( DO_DWM )) && \
	prompt_continue "Build st (simple terminal)?" && \
	: \
; then
    log_section "ST TERMINAL INSTALLATION"
    
    # Build st (simple terminal)
    log_info "Building st..."
    clone_or_update "https://git.suckless.org/st" "$SRC_DIR/st"
    cd "$SRC_DIR/st"

    if [ ! -f config.h ]; then
        cp config.def.h config.h
    fi

    # Popular st patches info
    tee patches_info.txt > /dev/null << 'EOF'
Popular st patches to consider:
1. scrollback - Scrollback with mouse/keyboard
2. font2 - Fallback font support (less needed now with proper fontconfig)
3. anysize - Remove terminal size restrictions
4. clipboard - Better clipboard integration
5. desktopentry - Desktop entry for application menu
6. ligatures - Font ligature support
7. transparency - Background transparency
8. externalpipe - Pipe terminal content to external commands
9. boxdraw - Render box drawing characters
10. nordtheme - Nord color theme

EMOJI CRASH FIX: Fixed via fontconfig - no source modifications needed
EOF

    # Edit config.mk to enable Xresources
    sed -i 's/^[A-Z]*CPPFLAGS.*$/& -DXRESOURCES/' config.mk

    build_and_install "st" "make clean && make -j${BUILD_JOBS:-$(default_build_jobs)}" "make install" false

    log_success "st installed with font-based emoji crash fix"
fi

# =============================================================================
# SECTION 17: SUCKLESS TOOLS (SLSTATUS)
# =============================================================================
if \
	(( DO_DWM )) && \
	prompt_continue "Build slstatus (status monitor)?" && \
	: \
; then
    log_section "SLSTATUS INSTALLATION"
    
    # Build slstatus
    log_info "Building slstatus..."
    clone_or_update "https://git.suckless.org/slstatus" "$SRC_DIR/slstatus"
    cd "$SRC_DIR/slstatus"
    if [ ! -f config.h ]; then
        cp config.def.h config.h
    fi
    # Popular slstatus patches and configuration info
    tee patches_info.txt > /dev/null << 'EOF'
Popular slstatus patches and configuration tips:
1. Custom modules - Add custom status modules
2. Colors - Colored status text (works with dwm statuscolors patch)
3. Separators - Custom separators between status items
4. Network interfaces - Monitor specific network interfaces
5. Temperature sensors - CPU/GPU temperature monitoring
6. Battery improvements - Better battery status display
7. Volume control - Audio volume status
8. Brightness - Screen brightness monitoring
9. Memory usage - RAM/swap usage display
10. Uptime - System uptime display

Configuration notes:
- Edit config.h to customize status bar components
- Common components: datetime, battery, CPU usage, memory, network
- Use with dwm for status bar display
- Can pipe output to other status bars (i3bar, etc.)

Example config.h modifications:
- Change update interval (default 1 second)
- Add/remove status components
- Customize format strings
- Set network interface names
EOF
    build_and_install "slstatus" "make clean && make -j${BUILD_JOBS:-$(default_build_jobs)}" "make install" false
    log_success "slstatus installed - configure config.h and integrate with dwm"
fi

# =============================================================================
# SECTION 18: SUCKLESS TOOLS (SLOCK)
# =============================================================================
if \
    (( DO_DWM )) && \
    prompt_continue "Build slock (screen locker)?" && \
    : \
; then
    log_section "SLOCK INSTALLATION"

    # Optional but recommended: integrates lockers with X11 idle + systemd sleep
    refresh_sudo
    apt_install xss-lock

    log_info "Building slock..."
    clone_or_update "https://git.suckless.org/slock" "$SRC_DIR/slock"
    cd "$SRC_DIR/slock"

    if [ ! -f config.h ]; then
        cp config.def.h config.h
    fi

    build_and_install "slock" "make clean && make -j${BUILD_JOBS:-$(default_build_jobs)}" "make install" false

    # Convenience wrapper (message flag comes from patching in SECTION 21;
    # without the patch, slock will simply ignore -m and still lock fine.)
    tee "$HOME/.local/bin/lock" > /dev/null <<'EOF'
#!/usr/bin/env bash
exec slock -m "Locked  $(date '+%a %d %b, %H:%M:%S')"
EOF
    chmod +x "$HOME/.local/bin/lock"

    log_success "slock installed"
fi

# =============================================================================
# SECTION 19: FILE MANAGER AND PDF VIEWER
# =============================================================================

if \
	(( DO_DESKTOP_TOOLS )) && \
	prompt_continue "Install vifm (file manager) and zathura (PDF viewer)?" && \
	: \
; then
    log_section "FILE MANAGER AND PDF VIEWER"
    
    # Install vifm
    log_info "Installing vifm..."
    refresh_sudo
    apt_install vifm

    log_success "vifm installed"

    log_info "Installing colors for vifm..."
    clone_or_update "https://github.com/vifm/vifm-colors" "$HOME/.config/vifm/colors"
    log_success "Colors for vifm installed"

    # Install zathura and plugins
    log_info "Installing zathura..."
    apt_install zathura zathura-pdf-poppler zathura-ps zathura-djvu

    log_success "zathura installed"
fi

# =============================================================================
# SECTION 20: NEOVIM SETUP
# =============================================================================

if \
    (( DO_NEOVIM )) && \
    prompt_continue "Build Neovim from source and link the repo-managed config?" && \
    : \
; then
    log_section "NEOVIM SETUP"

    : "${XDG_CONFIG_HOME:=$HOME/.config}"
    : "${XDG_DATA_HOME:=$HOME/.local/share}"
    : "${XDG_CACHE_HOME:=$HOME/.cache}"
    : "${XDG_STATE_HOME:=$HOME/.local/state}"

    NVIM_INSTALL_PREFIX="${NVIM_INSTALL_PREFIX:-$HOME/.local}"
    NVIM_SOURCE_DIR="${NVIM_SOURCE_DIR:-$SRC_DIR/neovim}"
    NVIM_CONFIG_SOURCE="${NVIM_CONFIG_SOURCE:-$SCRIPT_DIR/config/nvim}"
    NVIM_CONFIG_TARGET="${NVIM_CONFIG_TARGET:-$XDG_CONFIG_HOME/nvim}"
    NEOVIM_GIT_BRANCH="${NEOVIM_GIT_BRANCH:-stable}"

    mkdir -p \
        "$NVIM_INSTALL_PREFIX/bin" \
        "$XDG_CONFIG_HOME" \
        "$XDG_CACHE_HOME/nvim" \
        "$XDG_STATE_HOME/nvim"

    missing_neovim_build_tools=()
    for required_cmd in git cc make cmake ninja curl unzip gettext; do
        if ! command -v "$required_cmd" >/dev/null 2>&1; then
            missing_neovim_build_tools+=("$required_cmd")
        fi
    done

    if [ "${#missing_neovim_build_tools[@]}" -gt 0 ]; then
        log_warning "Skipping Neovim build; missing required tools: ${missing_neovim_build_tools[*]}"
        if (( DO_SYSTEM )) && command -v sudo >/dev/null 2>&1; then
            log_warning "Run Section 02 first or install the missing tools, then retry Section 18."
        else
            log_warning "This profile avoids sudo. Install the missing tools in user space or via your admin, then retry Section 18."
        fi
    else
        log_info "Building Neovim from source (branch: $NEOVIM_GIT_BRANCH)..."
        clone_or_update "https://github.com/neovim/neovim.git" "$NVIM_SOURCE_DIR" "$NEOVIM_GIT_BRANCH"

        cd "$NVIM_SOURCE_DIR"
        make distclean 2>/dev/null || true
        rm -rf build .deps 2>/dev/null || true

        build_and_install \
            "Neovim" \
            "make CMAKE_BUILD_TYPE=RelWithDebInfo CMAKE_INSTALL_PREFIX=$NVIM_INSTALL_PREFIX" \
            "make install" \
            true
        hash -r 2>/dev/null || true
    fi

    if [ -d "$NVIM_CONFIG_SOURCE" ]; then
        if [ -e "$NVIM_CONFIG_TARGET" ] && [ ! -L "$NVIM_CONFIG_TARGET" ]; then
            backup_path="${NVIM_CONFIG_TARGET}.backup.$(date +%Y%m%d_%H%M%S)"
            log_warning "Backing up existing Neovim config: $NVIM_CONFIG_TARGET -> $backup_path"
            mv "$NVIM_CONFIG_TARGET" "$backup_path"
        fi

        if [ -L "$NVIM_CONFIG_TARGET" ]; then
            current_link=$(readlink -- "$NVIM_CONFIG_TARGET" || true)
            if [ "$current_link" != "$NVIM_CONFIG_SOURCE" ]; then
                log_warning "Replacing existing Neovim config symlink: $NVIM_CONFIG_TARGET -> $current_link"
                rm -f -- "$NVIM_CONFIG_TARGET"
            fi
        fi

        ln -sfn "$NVIM_CONFIG_SOURCE" "$NVIM_CONFIG_TARGET"
        log_info "Linked repo-managed Neovim config: $NVIM_CONFIG_TARGET -> $NVIM_CONFIG_SOURCE"
    else
        log_warning "Repo-managed Neovim config not found at $NVIM_CONFIG_SOURCE; skipping config link."
    fi

    if command -v nvim >/dev/null 2>&1; then
        log_success "Neovim is available at $(command -v nvim)"
    elif [ -x "$NVIM_INSTALL_PREFIX/bin/nvim" ]; then
        log_success "Neovim is available at $NVIM_INSTALL_PREFIX/bin/nvim"
    else
        log_warning "nvim is not on PATH; ensure $HOME/.local/bin is exported before launching it."
    fi
fi

# =============================================================================
# SECTION 21A: TERMINAL MAIL STACK
# =============================================================================

if \
    (( DO_EMAIL )) && \
    prompt_continue "Install terminal mail stack from source (NeoMutt + isync + msmtp + notmuch)?" && \
    : \
; then
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
        log_warning "Skipping terminal mail stack build; missing required tools: ${missing_mail_build_tools[*]}"
        log_warning "Install them in user space or via your admin, then retry Section 18A."
    else
        install_notmuch_from_source "$MAIL_INSTALL_PREFIX"
        install_isync_from_source "$MAIL_INSTALL_PREFIX"
        install_msmtp_from_source "$MAIL_INSTALL_PREFIX"
        install_neomutt_from_source "$MAIL_INSTALL_PREFIX"
        hash -r 2>/dev/null || true
    fi

    log_info "XDG mail paths:"
    log_info "  Maildir root: $MAILDIR_ROOT"
    log_info "  NeoMutt config: $NEOMUTT_CONFIG_DIR/neomuttrc"
    log_info "  isync config: $ISYNC_CONFIG_PATH"
    log_info "  msmtp config: $MSMTP_CONFIG"
    log_info "  notmuch config: $NOTMUCH_CONFIG"
fi

# =============================================================================
# SECTION 22: DWM SESSION CONFIGURATION
# =============================================================================

if \
	(( DO_DWM )) && \
	prompt_continue "Configure dwm desktop session?" && \
	: \
; then
    log_section "DWM SESSION CONFIGURATION"
    
    log_info "Creating desktop entry for dwm in display manager..."
    refresh_sudo
    sudo mkdir -p /usr/share/xsessions

    # Create session startup script with keyboard config
    sudo tee /usr/local/bin/dwm-session > /dev/null << 'EOF'
#!/bin/sh

# Source ~/.profile to load XDG environment and other exports
[ -f "$HOME/.profile" ] && . "$HOME/.profile"

# Load X resources
[ -f "$HOME/.config/X11/Xresources" ] && xrdb -merge "$HOME/.config/X11/Xresources"

# Add ~/.local/bin to PATH only if not already present
case ":$PATH:" in
  *:"$HOME/.local/bin":*) ;;
  *) PATH="$HOME/.local/bin:$PATH" ;;
esac
export PATH

# Drop legacy GTK accessibility modules injected by /etc/X11/Xsession.d/90atk-adaptor
unset GTK_MODULES

# Keyboard configuration:
# repeat rate and key maps
xset r rate 300 50
setxkbmap "us,ru" -option "grp:caps_toggle"
# setxkbmap -option altwin:swap_lalt_lwin

# Set black desktop background
xsetroot -solid black

# # Disable screen saver and DPMS
# xset s off -dpms

# Enable screensaver/DPMS and lock on idle
xset s 900 60            # start screensaver after 15 min, cycle every 60s
xset +dpms
xset dpms 900 1200 1800    # standby/suspend/off

# Lock on idle and on suspend (systemd)
xss-lock --transfer-sleep-lock -- lock &

# Start background services 
slstatus &

# xrandr --newmode "2560x1440_60.00"  312.25  2560 2752 3024 3488  1440 1443 1448 1493 -hsync +vsync
# xrandr --addmode HDMI-1 "2560x1440_60.00"

# Start dwm
exec dwm
EOF

    sudo chmod +x /usr/local/bin/dwm-session

    # Create dwm.desktop file for display manager
    sudo tee /usr/share/xsessions/dwm.desktop > /dev/null << 'EOF'
[Desktop Entry]
Name=dwm
Comment=Dynamic window manager
Exec=dwm-session
TryExec=dwm
Icon=
Type=XSession
DesktopNames=dwm
EOF

    log_success "dwm desktop entry created"
fi

# =============================================================================
# SECTION 24: DOTFILES SETUP
# =============================================================================

if \
	(( DO_CORE )) && \
	prompt_continue "Link repository-managed dotfiles?" && \
	: \
; then
    log_section "DOTFILES SETUP"

    DOTFILES_DIR="$SCRIPT_DIR"
    MAKESYMLINKS_SCRIPT="$DOTFILES_DIR/makesymlinks.sh"
    if [ ! -x "$MAKESYMLINKS_SCRIPT" ]; then
        log_error "Executable makesymlinks.sh not found in current checkout: $DOTFILES_DIR"
        exit 1
    fi

    log_info "Delegating repository-backed configuration to makesymlinks.sh"
    "$MAKESYMLINKS_SCRIPT" "$BOOTSTRAP_PROFILE"
    log_success "Dotfiles linked from $DOTFILES_DIR"
fi


# =============================================================================
# SECTION 25: NVM SETUP
# =============================================================================

if \
    (( DO_NODE_TOOLS )) && \
    prompt_continue "Install Node.js and npm tooling via nvm?" && \
    : \
; then
    log_section "NODE/NPM TOOLING VIA NVM"
   
    if install_nvm_node_tools; then
        log_success "Node/npm tooling setup completed"
    else
        log_warning "Node/npm tooling setup failed or was incomplete."
    fi
fi

# =============================================================================
# SECTION 26: SSH-FIND-AGENT INSTALLATION
# =============================================================================

if \
	(( DO_CORE )) && \
	prompt_continue "Install ssh-find-agent for SSH agent management?" && \
	: \
; then
    log_section "SSH-FIND-AGENT INSTALLATION"
    
    # Clone ssh-find-agent repository
    log_info "Installing ssh-find-agent..."
    clone_or_update "https://github.com/wwalker/ssh-find-agent.git" "$SRC_DIR/ssh-find-agent"
    
    cd "$SRC_DIR/ssh-find-agent"
    
    # Install the script to local bin directory
    cp ssh-find-agent.sh "$BIN_DIR/ssh-find-agent"
    chmod +x "$BIN_DIR/ssh-find-agent"
    
    # Ensure proper ownership
    chown "$USER:$(id -gn)" "$BIN_DIR/ssh-find-agent"
    
    log_success "ssh-find-agent installed successfully"
    
    # Provide usage information
    log_info "ssh-find-agent usage:"
    echo "  • ssh_agent_start  - Start SSH agent and add keys"
    echo "  • ssh_agent_list   - List available SSH agents"
    echo "  • ssh_agent_kill   - Kill current SSH agent"
    echo "  • ssh-find-agent   - Run ssh-find-agent directly"
    echo
    log_info "ssh-find-agent will automatically find and use existing SSH agents"
    log_info "This helps avoid multiple SSH agent instances and keeps your keys loaded"
fi

# =============================================================================
# SECTION 27: SUCKLESS TOOLS CONFIGURATION
# =============================================================================
if \
	(( DO_DWM )) && \
	prompt_continue "Configure and patch suckless tools?" && \
	: \
; then
    log_section "SUCKLESS CONFIGURATION"

    PATCHES_DIR="$SCRIPT_DIR/patches"

	apply_patch() {
		local source=$1
		local patch_name=$2
		local patch_file=""
		local -a patch_args=()
		if [ -n "${3:-}" ]; then read -r -a patch_args <<< "$3"; fi

		# Determine patch source type
		if [[ "$source" =~ ^https?:// ]]; then
			patch_file="${patch_name}.patch"
			if wget -q "$source" -O "$patch_file"; then
				log_info "Downloaded $patch_name patch from URL"
			else
				log_warning "Failed to download $patch_name patch"
				return 1
			fi
		elif [ -f "$source" ]; then
			patch_file="$source"
			patch_name="$(basename "$source" .patch)"
			log_info "Applying local patch from file: $patch_file"
		else
			log_warning "Local patch not found: $source"
			return 1
		fi

		if patch --dry-run -p1 "${patch_args[@]}" < "$patch_file" >/dev/null 2>&1; then
			patch -p1 "${patch_args[@]}" < "$patch_file"
			log_success "$patch_name patch applied successfully"
		elif patch --dry-run -R -p1 "${patch_args[@]}" < "$patch_file" >/dev/null 2>&1; then
			log_info "$patch_name patch already applied"
		else
			log_error "$patch_name patch does not apply cleanly"
			return 1
		fi
	}

	git_apply_patch() {
		local source=$1
		ensure_git_patch_applied "$source"
	}

    # Function to configure a suckless tool
    configure_suckless_tool() {
        local tool_name=$1
        local tool_dir="$SRC_DIR/$tool_name"
        
        if [ ! -d "$tool_dir" ]; then
            log_warning "$tool_name not found in $tool_dir, skipping..."
            return 1
        fi
        
        cd "$tool_dir"
        log_info "Configuring $tool_name..."
        
        # Apply tool-specific patches and configurations
		case "$tool_name" in
            "st")
                apply_patch "https://st.suckless.org/patches/scrollback/st-scrollback-20210507-4536f46.diff" "scrollback"
                apply_patch "https://st.suckless.org/patches/xresources/st-xresources-20200604-9ba7ecf.diff" "xresources"
                # Fix st-xresources' wrong order of additional colors
                sed -i \
                    -e 's/{ "background",   STRING,  &colorname\[256\] }/{ "background",   STRING,  \&colorname[259] }/' \
                    -e 's/{ "foreground",   STRING,  &colorname\[257\] }/{ "foreground",   STRING,  \&colorname[258] }/' \
                    -e 's/{ "cursorColor",  STRING,  &colorname\[258\] }/{ "cursorColor",  STRING,  \&colorname[256] }/' \
                    config.def.h
                apply_patch "https://st.suckless.org/patches/clipboard/st-clipboard-20180309-c5ba9c0.diff" "clipboard"
			;;
                
            "dmenu")
				# apply_patch "https://tools.suckless.org/dmenu/patches/xresources/dmenu-xresources-4.9.diff" "xresources"
                apply_patch "https://tools.suckless.org/dmenu/patches/center/dmenu-center-20240616-36c3d68.diff" "center"
                apply_patch "https://tools.suckless.org/dmenu/patches/fuzzymatch/dmenu-fuzzymatch-5.3.diff" "fuzzymatch" "--fuzz=3"
				apply_patch "https://tools.suckless.org/dmenu/patches/fuzzyhighlight/dmenu-fuzzyhighlight-5.3.diff" "fuzzyhighlight" "--fuzz=3"
				# Note: this manual patch should already disable the centered dmenu
			    git_apply_patch "$PATCHES_DIR/dmenu/dmenu-xresources-combined.diff" "xresources"
                # Disable centered dmenu by default (use -c)
                # sed -i 's/\(^static int centered = \)1\(;.*\)/\10\2/' config.def.h
			;;
                
            "dwm")
                local dmenu_configured=false

                apply_patch "https://dwm.suckless.org/patches/center/dwm-center-6.2.diff" "center"
                apply_patch "$PATCHES_DIR/dwm/dwm-fix-dmenucmd.diff" "dmenucmd"
                apply_patch "$PATCHES_DIR/dwm/dwm-xrdb-patch.diff" "xrdb" "--fuzz=3"
                apply_patch "$PATCHES_DIR/dwm/dwm-config-fixes.diff" "config" "--fuzz=3"
				# apply_patch "https://dwm.suckless.org/patches/xresources/dwm-xresources-20210827-138b405.diff" "xresources" "--fuzz=3"

                # cp config.def.h /tmp/config.def.h.tmp
                
                # Add -i for case-insensitive matching in dmenu
                # sed -i '
                #     # Match one-line definition with both start and };
                #     /^static.*dmenucmd\[\][[:space:]]*=/ {
                #         /};/ {
                #             /-i/! s/\("dmenu[^"]*"\)/\1, "-i"/
                #             n
                #         }
                #     }
                #     # Match multi-line dmenucmd[] arrays
                #     /^static.*dmenucmd\[\][[:space:]]*=/,/};/ {
                #         /-i/! s/\("dmenu[^"]*"\)/\1, "-i"/
                #     }
                # ' config.def.h

                # # Check if the substitution was made
                # if ! cmp -s config.def.h /tmp/config.def.h.tmp; then
                #     log_success "Added -i flag to dmenu_run command"
                #     dmenu_configured=true
                # else
                #     log_warning "Failed to modify dmenu_run command"
                # fi
                # rm -f /tmp/config.def.h.tmp
			;;

			"slstatus")
				# Modify config.def.h for custom status bar
				# Change interval to 1 second (1000ms)
				sed -i 's/const unsigned int interval = [0-9]*;/const unsigned int interval = 1000;/' config.def.h
				
				# Replace the args array with custom status elements
				sed -i '/static const struct arg args\[\] = {/,/};/c\
static const struct arg args[] = {\
	/* function format          argument */\
	{ cpu_perc, " CPU %2s%%", NULL },\
	{ ram_perc, " RAM %2s%%", NULL },\
    { battery_state, " %s", "BAT0" },\
    { battery_perc, "%s%%", "BAT0" },\
	{ temp, " %s°C", "/sys/class/thermal/thermal_zone2/temp" },\
    { datetime, " %s", "%b %d %H:%M:%S" },\
};' config.def.h
			;;
            "slock")
                apply_patch \
                    "$PATCHES_DIR/slock/slock-capslock-xresources-message-patches.diff" \
                    "slock-patches"
            ;;
        esac

        # Copy patched config.def.h to config.h
        if [ -f config.def.h ]; then
            log_info "Copying patched config.def.h to config.h for $tool_name"
            cp config.def.h config.h
        fi
        
        # Apply Gruvbox theme
        case "$tool_name" in
            "st")
                log_info "Applying Gruvbox theme to st..."
                sed -i '
                    s/"#bbbbbb"/"#ebdbb2"/g;
                    s/"#222222"/"#282828"/g;
                    s/"#cccccc"/"#ebdbb2"/g
                ' config.h 2>/dev/null || true
                ;;
            "dmenu")
                log_info "Applying Gruvbox theme to dmenu..."
                sed -i '
                    s/"#bbbbbb", "#222222"/"#ebdbb2", "#282828"/g;
                    s/"#eeeeee", "#005577"/"#ebdbb2", "#458588"/g
                ' config.h 2>/dev/null || true
                ;;
            "dwm"|"slstatus")
                log_info "Applying Gruvbox theme to dwm..."
                sed -i '
                    s/#222222/#282828/g;
                    s/#444444/#504945/g;
                    s/#bbbbbb/#ebdbb2/g;
                    s/#eeeeee/#ebdbb2/g;
                    s/#005577/#458588/g
                ' config.h 2>/dev/null || true
                ;;
        esac
        
        # Build and install
        log_info "Building $tool_name..."
        make clean >/dev/null 2>&1
        if make -j"${BUILD_JOBS:-$(default_build_jobs)}" >/dev/null 2>&1; then
            refresh_sudo
            if sudo make install >/dev/null 2>&1; then
                log_success "$tool_name configured and installed successfully"
            else
                log_error "Failed to install $tool_name"
                return 1
            fi
        else
            log_error "Failed to build $tool_name"
            return 1
        fi
    }

    # Create basic Xresources for suckless tools
    create_xresources() {
        # If user manages .Xresources via dotfiles (symlink), do not overwrite
        if [ -L "$HOME/.Xresources" ]; then
            log_info "~/.Xresources is a symlink (likely managed by dotfiles); skipping default Xresources creation."
            return
        fi

        log_info "Creating basic Xresources configuration..."
        tee "$HOME/.Xresources" > /dev/null << 'EOF'
! Suckless tools configuration with Xresources support

! Font configuration
st.font: JetBrains Mono:pixelsize=14:antialias=true:hinting=true
dmenu.font: JetBrains Mono:pixelsize=14:antialias=true:hinting=true
dwm.font: JetBrains Mono:pixelsize=14:antialias=true:hinting=true

! DWM specific Xresources
dwm.normbgcolor: #282828
dwm.normfgcolor: #ebdbb2
dwm.selbgcolor: #fe8019
dwm.selfgcolor: #282828
dwm.normbordercolor: #504945
dwm.selbordercolor: #fe8019

! dmenu specific Xresources
! Normal item
dmenu.foreground:     #ebdbb2
dmenu.background:     #282828

! Selected item
dmenu.selforeground:  #282828
dmenu.selbackground:  #fe8019

! Highlighted match (unselected)
dmenu.hiforeground:   #fabd2f
dmenu.hibackground:   #282828

! Highlighted match (selected)
dmenu.hiselforeground: #282828
dmenu.hiselbackground: #fabd2f

! Output (e.g., for dmenu -l)
dmenu.outforeground:  #83a598
dmenu.outbackground:  #3c3836

! General terminal colors (Gruvbox theme)
*.background: #282828
*.foreground: #ebdbb2
*.cursorColor: #ebdbb2

! Black
*.color0: #282828
*.color8: #928374

! Red
*.color1: #cc241d
*.color9: #fb4934

! Green
*.color2: #98971a
*.color10: #b8bb26

! Yellow
*.color3: #d79921
*.color11: #fabd2f

! Blue
*.color4: #458588
*.color12: #83a598

! Magenta
*.color5: #b16286
*.color13: #d3869b

! Cyan
*.color6: #689d6a
*.color14: #8ec07c

! White
*.color7: #a89984
*.color15: #ebdbb2

! Additional st-specific configurations
st.background: #282828
st.foreground: #ebdbb2
st.cursorColor: #ebdbb2
st.alpha: 1.0

! slock colors 
slock.color0:      #000000   ! INIT
slock.color4:      #005577   ! INPUT
slock.color1:      #cc3333   ! FAILED
slock.color3:      #ff0000   ! CAPS

! slock message patch bits 
slock.message:     Locked
slock.text_color:  #ebdbb2
slock.font_name:   JetBrains Mono:size=16
EOF
        xrdb -merge "$HOME/.Xresources" 2>/dev/null || true
        log_success "Xresources configuration created"
    }

    # Create a script to reload Xresources easily
    tee "$HOME/.local/bin/reload-xresources" > /dev/null << 'EOF'
#!/bin/bash
# Reload Xresources configuration
xrdb -merge ~/.Xresources && echo "Xresources reloaded successfully"
EOF
    chmod +x "$HOME/.local/bin/reload-xresources" 2>/dev/null || true
    log_info "Created reload-xresources script in ~/.local/bin/"
    
    # Configure each tool
    for tool in dwm dmenu st slstatus slock; do
        configure_suckless_tool "$tool"
    done

    # # Create Xresources
    # create_xresources
    
    log_success "Suckless tools configuration completed"
fi


# =============================================================================
# SECTION 29: MESSENGERS
# =============================================================================
if \
	(( DO_MESSENGERS )) && \
	prompt_continue "Install messengers (telegram, slack, signal, zulip)?" && \
	: \
; then
    log_section "MESSENGERS INSTALLATION"
    refresh_sudo
    
    # Create temporary directory for downloads
    TEMP_DIR=$(mktemp -d)
    if [[ ! -d "$TEMP_DIR" ]]; then
        log_error "Failed to create temporary directory"
        exit 1
    fi
    
    # Cleanup function
    cleanup_temp() {
        if [[ -d "$TEMP_DIR" ]]; then
            rm -rf "$TEMP_DIR"
            log_info "Cleaned up temporary files"
        fi
    }
    
    # Set trap to cleanup on exit
    trap cleanup_temp EXIT
    
    # Function to check if command succeeded
    check_command() {
        if [[ $? -ne 0 ]]; then
            log_error "$1"
            cleanup_temp
            exit 1
        fi
    }
    
    # =============================================================================
    # ZULIP SETUP
    # =============================================================================
    log_info "Setting up Zulip Desktop APT repository..."
    
    # Download Zulip signing key
    sudo curl -fL -o /etc/apt/trusted.gpg.d/zulip-desktop.asc https://download.zulip.com/desktop/apt/zulip-desktop.asc
    check_command "Failed to download Zulip signing key"
    
    # Add Zulip repository
    echo "deb https://download.zulip.com/desktop/apt stable main" | sudo tee /etc/apt/sources.list.d/zulip-desktop.list > /dev/null
    check_command "Failed to add Zulip repository"
    
    log_success "Zulip repository configured"
    
    # =============================================================================
    # SIGNAL SETUP
    # =============================================================================
    log_info "Setting up Signal Desktop APT repository..."
    
    # Install Signal's official software signing key
    wget -O- https://updates.signal.org/desktop/apt/keys.asc | gpg --dearmor > "$TEMP_DIR/signal-desktop-keyring.gpg"
    check_command "Failed to download Signal signing key"
    
    sudo mv "$TEMP_DIR/signal-desktop-keyring.gpg" /usr/share/keyrings/signal-desktop-keyring.gpg
    check_command "Failed to install Signal signing key"
    
    # Add Signal's repository
    echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/signal-desktop-keyring.gpg] https://updates.signal.org/desktop/apt xenial main' | \
        sudo tee /etc/apt/sources.list.d/signal-xenial.list > /dev/null
    check_command "Failed to add Signal repository"
    
    log_success "Signal repository configured"
    
    # =============================================================================
    # TELEGRAM DOWNLOAD
    # =============================================================================
    log_info "Downloading Telegram Desktop..."
    
    # Get the latest Telegram download URL
    TELEGRAM_URL="https://telegram.org/dl/desktop/linux"
    TELEGRAM_FILE="$TEMP_DIR/telegram.tar.xz"
    
    # Download Telegram
    wget -O "$TELEGRAM_FILE" "$TELEGRAM_URL"
    check_command "Failed to download Telegram"
    
    # Verify the download is a valid tar.xz file
    if ! file "$TELEGRAM_FILE" | grep -q "XZ compressed data"; then
        log_error "Downloaded Telegram file is not a valid XZ archive"
        exit 1
    fi
    
    log_success "Telegram downloaded successfully"
    
    # =============================================================================
    # SLACK DOWNLOAD
    # =============================================================================
    log_info "Downloading Slack Desktop..."

	# Slack requires a more sophisticated approach due to redirects
    # We'll use curl with follow redirects and proper headers
    SLACK_FILE="$TEMP_DIR/slack.deb"
    
    # Try direct download first (may be outdated but worth trying)
    curl -L -A "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36" \
         -o "$SLACK_FILE" \
         "https://downloads.slack-edge.com/releases/linux/4.40.126/prod/x64/slack-desktop-4.40.126-amd64.deb"
    
    # Check if download succeeded AND if it's a valid DEB package
    DOWNLOAD_SUCCESS=false
    if [[ $? -eq 0 ]] && [[ -f "$SLACK_FILE" ]] && file "$SLACK_FILE" | grep -q "Debian binary package"; then
        DOWNLOAD_SUCCESS=true
        log_success "Direct download succeeded"
    else
        log_warning "Direct download failed or file is not a valid DEB package, trying alternative method..."
        
        # Remove invalid file if it exists
        [[ -f "$SLACK_FILE" ]] && rm -f "$SLACK_FILE"
        
        # Get the actual download URL from Slack's download page
        log_info "Parsing Slack download page for current version..."
        SLACK_DOWNLOAD_URL=$(curl -s "https://slack.com/intl/en-gb/downloads/instructions/linux?build=deb" | \
                           grep -o 'https://downloads\.slack-edge\.com[^"]*\.deb' | \
                           head -1)
        
        if [[ -n "$SLACK_DOWNLOAD_URL" ]]; then
            log_info "Found download URL: $SLACK_DOWNLOAD_URL"
            curl -L -A "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36" \
                 -o "$SLACK_FILE" \
                 "$SLACK_DOWNLOAD_URL"
            check_command "Failed to download Slack using alternative method"
            
            # Verify this download is valid
            if file "$SLACK_FILE" | grep -q "Debian binary package"; then
                DOWNLOAD_SUCCESS=true
                log_success "Alternative download succeeded"
            else
                log_error "Downloaded file is still not a valid DEB package"
                exit 1
            fi
        else
            log_error "Could not find Slack download URL from download page"
            exit 1
        fi
    fi
    
    # Final verification
    if [[ "$DOWNLOAD_SUCCESS" != "true" ]]; then
        log_error "Failed to download valid Slack DEB package"
        exit 1
    fi
    
    log_success "Slack downloaded and verified successfully"
       
    # =============================================================================
    # APT UPDATE AND INSTALL
    # =============================================================================
    log_info "Updating APT package lists..."
    apt_refresh force
    check_command "Failed to update APT package lists"
    
    log_info "Installing Zulip and Signal from repositories..."
    apt_install zulip signal-desktop
    check_command "Failed to install Zulip and Signal"
    
    log_success "Repository-based messengers installed"
    
    # =============================================================================
    # TELEGRAM INSTALLATION
    # =============================================================================
    log_info "Installing Telegram Desktop..."
    
    # Create directories if they don't exist
    mkdir -p "$HOME/soft" "$HOME/.local/bin"
    
    # Extract Telegram to user's software directory
    tar -xf "$TELEGRAM_FILE" -C "$HOME/soft/"
    check_command "Failed to extract Telegram"
    
    # Create symbolic link in user's local bin
    ln -sf "$HOME/soft/Telegram/Telegram" "$HOME/.local/bin/telegram"
    check_command "Failed to create Telegram symbolic link"
    
    log_success "Telegram Desktop installed to $HOME/soft/Telegram/"
    
    # =============================================================================
    # SLACK INSTALLATION
    # =============================================================================
    log_info "Installing Slack Desktop..."
    
    # Install the DEB package
    sudo dpkg -i "$SLACK_FILE"
    
    # Fix any dependency issues
    if [[ $? -ne 0 ]]; then
        log_warning "Fixing Slack dependencies..."
        sudo apt-get install -f -y
        check_command "Failed to fix Slack dependencies"
    fi
    
    # # Create symbolic link in user's local bin for convenience
    # mkdir -p "$HOME/.local/bin"
    # ln -sf /usr/bin/slack "$HOME/.local/bin/slack" 2>/dev/null || true
    
    log_success "Slack Desktop installed"
    
    # =============================================================================
    # VERIFICATION
    # =============================================================================
    log_info "Verifying installations..."
    
    # Check if applications are installed and accessible
    APPS=("zulip" "signal-desktop" "telegram" "slack")
    FAILED_APPS=()
    
    for app in "${APPS[@]}"; do
        # Check both system PATH and user's local bin
        if ! command -v "$app" &> /dev/null && ! [[ -x "$HOME/.local/bin/$app" ]]; then
            FAILED_APPS+=("$app")
        fi
    done
    
    if [[ ${#FAILED_APPS[@]} -eq 0 ]]; then
        log_success "All messengers installed and verified successfully"
        log_info "Installed applications:"
        log_info "  - Zulip Desktop (system-wide)"
        log_info "  - Signal Desktop (system-wide)"
        log_info "  - Telegram Desktop (user: $HOME/soft/Telegram/)"
        log_info "  - Slack Desktop (system-wide)"
        log_info ""
        log_info "Make sure $HOME/.local/bin is in your PATH to access telegram command"
    else
        log_warning "Some applications may not be properly installed: ${FAILED_APPS[*]}"
        log_info "You may need to add $HOME/.local/bin to your PATH or check the installation"
    fi
    
    cleanup_temp
    trap - EXIT
    log_success "Messengers installation completed"
fi

# =============================================================================
# SECTION 30: MEDIA
# =============================================================================
if \
	(( DO_MEDIA )) && \
	prompt_continue "Install media software?" && \
	: \
; then
    log_section "MEDIA SOFTWARE INSTALLATION"

	curl -sS https://download.spotify.com/debian/pubkey_C85668DF69375001.gpg | sudo gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/spotify.gpg
	echo "deb https://repository.spotify.com stable non-free" | sudo tee /etc/apt/sources.list.d/spotify.list

    # Update system packages
    log_info "Updating system packages..."
    refresh_sudo
    apt_refresh force

	apt_install \
		spotify-client

    log_info "Installing media software from repositories..."
fi

# =============================================================================
# SECTION 32: SCIENTIFIC SOFTWARE (MODULAR SUBSECTIONS)
# =============================================================================

if \
	(( DO_SCI )) && \
    (( DO_GMP || DO_NTL || DO_MPFR || DO_FLINT || DO_JULIA || DO_QD || DO_FINITEFLOW || DO_FINITEFLOW32 || DO_BLADE || DO_GFAN || DO_FERMAT || DO_MSOLVE || DO_SCI_EXTRA )) && \
	prompt_continue "Install enabled scientific software components?" && \
	: \
; then
    log_section "SCIENTIFIC SOFTWARE INSTALLATION"

    SCI_PREFIX="$HOME/.local"
    SCI_ENV_REPO_PATH="$SCRIPT_DIR/config/scientific-env.sh"
    SCI_ENV_PATH="${XDG_CONFIG_HOME:-$HOME/.config}/scientific-env.sh"
    SCI_REPOS_DIR="$HOME/soft"
    SCI_JOBS="${SCI_JOBS:-${BUILD_JOBS:-$(default_build_jobs)}}"
    FINITEFLOW_PREFIX_PATH="$SCI_PREFIX"
    FINITEFLOW_ENV_PREFIX=""

    # Ensure required directories exist
    mkdir -p "$SRC_DIR"
    mkdir -p "$SCI_PREFIX"
    mkdir -p "$SCI_REPOS_DIR"

    # Prefer the local scientific prefix for subsequent builds, even when only
    # a subset of the section is enabled on a later rerun.
    export PATH="$SCI_PREFIX/bin${PATH:+:$PATH}"
    export CPPFLAGS="-I$SCI_PREFIX/include${CPPFLAGS:+ $CPPFLAGS}"
    export LDFLAGS="-L$SCI_PREFIX/lib${LDFLAGS:+ $LDFLAGS}"
    export PKG_CONFIG_PATH="$SCI_PREFIX/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
    export LD_LIBRARY_PATH="$SCI_PREFIX/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

    # Helper to clone repos into common directory
    clone_sci_repo() {
        local name=$1
        local url=$2
        local dest="$SCI_REPOS_DIR/$name"

        log_info "Setting up repo: $name"
		clone_or_update "$url" "$dest"
    }

    # ========================================
    # GMP
    # ========================================
    if (( DO_GMP )); then
        log_info "Installing GMP from source..."
        GMP_VERSION="${GMP_VERSION:-6.3.0}"
        GMP_ARCHIVE="gmp-${GMP_VERSION}.tar.xz"
        GMP_URL="${GMP_URL:-https://gmplib.org/download/gmp/${GMP_ARCHIVE}}"

        cd "$SRC_DIR"
        download_file "$GMP_URL" "$GMP_ARCHIVE"
        tar -xf "$GMP_ARCHIVE"
        cd "gmp-${GMP_VERSION}"

        ./configure --prefix="$SCI_PREFIX" --enable-cxx
        build_and_install "GMP" "make -j$SCI_JOBS" "make install" true
        log_success "GMP installed to $SCI_PREFIX"
    fi

    # ========================================
    # NTL
    # ========================================
    if (( DO_NTL )); then
        log_info "Installing NTL from source..."
        NTL_VERSION="${NTL_VERSION:-11.6.0}"
        NTL_ARCHIVE="ntl-${NTL_VERSION}.tar.gz"
        NTL_URL="${NTL_URL:-https://libntl.org/${NTL_ARCHIVE}}"

        cd "$SRC_DIR"
        download_file "$NTL_URL" "$NTL_ARCHIVE"
        tar -xf "$NTL_ARCHIVE"
        cd "ntl-${NTL_VERSION}/src"

        ./configure DEF_PREFIX="$SCI_PREFIX" SHARED=on
        build_and_install "NTL" "make -j$SCI_JOBS" "make install" true
        log_success "NTL installed to $SCI_PREFIX"
    fi

    # ========================================
    # MPFR
    # ========================================
    if (( DO_MPFR )); then
        log_info "Installing MPFR from source..."
        MPFR_VERSION="${MPFR_VERSION:-4.2.2}"
        MPFR_ARCHIVE="mpfr-${MPFR_VERSION}.tar.xz"
        MPFR_URL="${MPFR_URL:-https://www.mpfr.org/mpfr-${MPFR_VERSION}/${MPFR_ARCHIVE}}"

        cd "$SRC_DIR"
        download_file "$MPFR_URL" "$MPFR_ARCHIVE"
        tar -xf "$MPFR_ARCHIVE"
        cd "mpfr-${MPFR_VERSION}"

        ./configure --prefix="$SCI_PREFIX" --with-gmp="$SCI_PREFIX"
        build_and_install "MPFR" "make -j$SCI_JOBS" "make install" true
        log_success "MPFR installed to $SCI_PREFIX"
    fi

    # ========================================
    # FLINT
    # ========================================
    if (( DO_FLINT )); then
        log_info "Installing FLINT from source..."
        FLINT_VERSION="${FLINT_VERSION:-3.4.0}"
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
        build_and_install "FLINT" "make -j$SCI_JOBS" "make install" true
        log_success "FLINT installed to $SCI_PREFIX"
    fi

    # ========================================
    # Julia
    # ========================================
    if (( DO_JULIA )); then
        log_info "Installing Julia from the official generic Linux tarball..."
        if install_julia_from_tarball "$SCI_PREFIX" "$SCI_REPOS_DIR"; then
            log_success "Julia installed locally; binaries live under $SCI_REPOS_DIR"
        else
            log_warning "Julia installation failed."
        fi
    fi

    # ========================================
    # FiniteFlow FLINT provider
    # ========================================
    if (( DO_FINITEFLOW )); then
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
                build_and_install "FLINT-FiniteFlow-dep" "make -j$SCI_JOBS" "make install" true
                log_success "FiniteFlow-specific minimal FLINT installed to $FINITEFLOW_FLINT_PREFIX"

                FINITEFLOW_PREFIX_PATH="$FINITEFLOW_FLINT_PREFIX:$SCI_PREFIX"
                FINITEFLOW_ENV_PREFIX="$FINITEFLOW_FLINT_PREFIX"
                export LD_LIBRARY_PATH="$FINITEFLOW_FLINT_PREFIX/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
                ;;
            *)
                log_error "Unknown FINITEFLOW_FLINT_PROVIDER='$FINITEFLOW_FLINT_PROVIDER'. Use full or mini."
                exit 1
                ;;
        esac
    fi


    if \
        (( DO_QD)) && \
        : \
    ; then
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
            exit 1
        }

        # Build and install using your helper
        build_and_install "QD" "make -j$SCI_JOBS" "make install" true
        log_success "QD installed to $SCI_PREFIX (libs in $SCI_PREFIX/lib, headers in $SCI_PREFIX/include)"
    fi
        
    # ========================================
    # FiniteFlow
    # ========================================
    if (( DO_FINITEFLOW )); then
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
        build_and_install "FiniteFlow" "make -j$SCI_JOBS" "make install" true
        log_success "FiniteFlow installed to $SCI_PREFIX; sources are in $FINITEFLOW_DEV_DIR"
        if [ -f "$FINITEFLOW_DEV_DIR/compile_commands.json" ]; then
            log_info "clangd compilation database available at $FINITEFLOW_DEV_DIR/compile_commands.json"
        fi
    fi

    # ========================================
    # FiniteFlow32
    # ========================================
    if (( DO_FINITEFLOW32 )); then
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
            log_warning "Skipping FiniteFlow32 (repository unavailable or SSH access denied)."
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
    fi

    # ========================================
    # Blade
    # ========================================
    if (( DO_BLADE )); then
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
        build_and_install "Blade" "cmake --build \"$BLADE_BUILD_DIR\" -j$SCI_JOBS" "cmake --install \"$BLADE_BUILD_DIR\"" true
        log_success "Blade built in $BLADE_BUILD_DIR and installed into $BLADE_DEV_DIR/bin and $BLADE_DEV_DIR/lib"
    fi

    # ========================================
    # msolve
    # ========================================
    if (( DO_MSOLVE )); then
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
            exit 1
        fi

        ./autogen.sh
        ./configure --prefix="$SCI_PREFIX"
        build_and_install "msolve" "make -j$SCI_JOBS" "make install" true
        log_success "msolve installed to $SCI_PREFIX; sources are in $MSOLVE_DEV_DIR"
    fi

    # ========================================
    # gfan
    # ========================================
    if (( DO_GFAN )); then
        log_info "Installing cddlib and gfan from upstream tarballs..."

        GFAN_VERSION="${GFAN_VERSION:-0.7}"
        GFAN_ARCHIVE="gfan${GFAN_VERSION}.tar.gz"
        GFAN_URL="${GFAN_URL:-https://math.au.dk/~jensen/software/gfan/${GFAN_ARCHIVE}}"
        GFAN_ARCHIVE_PATH="$SRC_DIR/$GFAN_ARCHIVE"
        GFAN_SRC_DIR="${GFAN_SRC_DIR:-$SRC_DIR/gfan-${GFAN_VERSION}-src}"
        CDDLIB_VERSION="${CDDLIB_VERSION:-094i}"
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
        build_and_install "cddlib" "make -j$SCI_JOBS" "make install" true
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
    fi

    # ========================================
    # Fermat
    # ========================================
    if (( DO_FERMAT )); then
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
                log_warning "Could not download Fermat! Skipping Fermat installation (network issue or mirror blocked?)."
                fermat_ok=0
            fi
        fi

        # Extract only if download (or existing tarball) is OK
        if [ "$fermat_ok" -eq 1 ]; then
            log_info "Extracting Fermat..."
            if ! tar -xzf Ferl7.tar.gz; then
                log_warning "Failed to extract Fermat archive! Skipping Fermat installation."
                fermat_ok=0
            fi
        fi

        # Find the Fermat binary somewhere under $FERMAT_SRC_DIR
        if [ "$fermat_ok" -eq 1 ]; then
            FER_BINARY="$FERMAT_SRC_DIR/Ferl7/fer64"

            if [ -z "$FER_BINARY" ]; then
                log_warning "Fermat binary not found after extraction! Skipping Fermat installation."
            else
                log_info "Linking Fermat binary ($FER_BINARY) to $FERMAT_LINK_TARGET"
                ln -sf "$FER_BINARY" "$FERMAT_LINK_TARGET"
                log_success "Fermat available as: $FERMAT_LINK_TARGET"
            fi
        fi
    fi

    # ========================================
    # Extra tools 
    # ========================================
    if (( DO_SCI_EXTRA )); then
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
            log_warning "Skipping private repo ff_ext_packages (SSH keys not configured or access denied)."
        fi

        # Private modification of Singular interface for Mathematica
        if ! clone_sci_repo "singular" "git@github.com:vchestnov/singular.git"; then
            log_warning "Skipping private repo singular (SSH keys not configured or access denied)."
        fi
    fi

    if (( DO_SCI_EXTRA )); then
        log_success "Extra scientific packages cloned into $SCI_REPOS_DIR"
        log_info "Consult each repository's README for Mathematica / workflow-specific setup."
    else
        log_info "Scientific repositories and helper tools live under: $SCI_REPOS_DIR"
    fi
    
    log_success "Scientific software installation complete!"
    log_info "Scientific environment is managed from: $SCI_ENV_REPO_PATH"
    log_info "Link it with ./makesymlinks.sh, then use it in the current session with: source \"$SCI_ENV_PATH\""
    log_info "If you want this loaded in new terminal sessions, source \"$SCI_ENV_PATH\" from your shell profile."
fi

# =============================================================================
# SECTION 33A: SAGEMATH (MINIFORGE + GITHUB CHECKOUT)
# =============================================================================

if \
    (( DO_SAGE )) && \
    prompt_continue "Install SageMath via XDG Miniforge and GitHub checkout?" && \
    : \
; then
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
            exit 1
            ;;
    esac
fi

# =============================================================================
# SECTION 34B: POLYMAKE (GITHUB/SOURCE BUILD, XDG-COMPLIANT)
# =============================================================================

if \
    (( DO_POLYMAKE )) && \
    prompt_continue "Install polymake from GitHub/source into ~/.local?" && \
    : \
; then
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
            exit 1
            ;;
    esac
fi

# =============================================================================
# SECTION 35: OPENXM + Risa/Asir (from source, XDG-compliant)
# =============================================================================

if \
    (( DO_ASIR )) && \
    prompt_continue "Install OpenXM + Risa/Asir from source (XDG-compliant)?" && \
    : \
; then
    log_section "OPENXM + Risa/Asir INSTALLATION"

    # --- XDG locations (install/runtime tree in XDG_DATA_HOME; env in XDG_CONFIG_HOME) ---
    : "${XDG_DATA_HOME:=$HOME/.local/share}"
    : "${XDG_CONFIG_HOME:=$HOME/.config}"

    OPENXM_PREFIX="$XDG_DATA_HOME/openxm"          # runtime tree (OpenXM_HOME)
    OPENXM_CONFIG_DIR="$XDG_CONFIG_HOME/openxm"
    OPENXM_ENV_SH="$OPENXM_CONFIG_DIR/env.sh"

    # Keep sources with the rest of your scientific repos (your script already uses ~/soft)
    OPENXM_REPOS_DIR="$HOME/soft/openxm"
    OPENXM_REPO="$OPENXM_REPOS_DIR/OpenXM"
    OPENXM_CONTRIB_REPO="$OPENXM_REPOS_DIR/OpenXM_contrib2"

    mkdir -p "$OPENXM_PREFIX" "$OPENXM_CONFIG_DIR" "$OPENXM_REPOS_DIR"

    # # --- deps (from upstream README prereq list; some are already in your base deps) ---
    # log_info "Installing OpenXM build dependencies..."
    # refresh_sudo
    # sudo apt install -y \
    #     nkf \
    #     wget \
    #     texinfo \
    #     texi2html \
    #     sharutils \
    #     java-common \
    #     openjdk-11-jdk \
    #     gnupg \
    #     latex2html \
    #     dvipdfmx \
    #     freeglut3-dev \
    #     libxaw7 \
    #     libxaw7-dev \
    #     libtinfo-dev \
    #     bison \
    #     build-essential \
    #     git \
    #     || true

    # --- clone/update sources ---
    log_info "Cloning/updating OpenXM sources..."
    clone_or_update "https://github.com/openxm-org/OpenXM.git" "$OPENXM_REPO"
    clone_or_update "https://github.com/openxm-org/OpenXM_contrib2.git" "$OPENXM_CONTRIB_REPO"

    # OpenXM build expects contrib2 as a sibling directory (matches upstream instructions)
    # so we keep them under the same parent: ~/soft/openxm/{OpenXM,OpenXM_contrib2}
    cd "$OPENXM_REPO/src"

    # --- build/install (upstream flow) ---
    log_info "Building OpenXM (make configure; make install)..."
    # Make install is user-local in the tree; no sudo needed per upstream guidance.
    # make configure
    # make -j"$(nproc)"
    # make
    make install
    
    # # --- build/install (asir-only) ---
    # log_info "Building OpenXM: asir only (install-asir)..."
    # # This avoids k097/kxx/gnuplot/oxmgraph/OpenMath/Mathematica-related targets.
    # # Still builds required deps (util, asir-gc, gmp/mpfr/mpc/mpfi, pari, editline).
    # make -j"$(nproc)" install-asir

    # # --- optional: asir-contrib packages only (avoid oxservers dependency chain) ---
    # if prompt_continue "Install asir-contrib packages (no oxservers)?" && : ; then
    #     log_info "Installing asir-contrib (packages only)..."
    #     make configure-asir-contrib
    #     (cd asir-contrib && make -j"$(nproc)" && make install)
    # fi
    
    # log_info "Building OpenXM (asir + linsolv only)..."

    # # Always start from src
    # cd "$OPENXM_REPO/src"

    # # --- configure phase (minimal) ---
    # make configure-util
    # make configure-gmp
    # make configure-mpfr
    # make configure-mpc
    # make configure-mpfi
    # make configure-asir
    # make configure-linsolv
    # make configure-asir-contrib || true

    # # --- build phase ---
    # make -j"$(nproc)" \
    #     all-util \
    #     all-asirgc \
    #     all-gmp \
    #     all-mpfr \
    #     all-mpc \
    #     all-mpfi \
    #     all-asir \
    #     all-linsolv

    # # --- install phase (user-local, no sudo) ---
    # make \
    #     install-util \
    #     install-asirgc \
    #     install-gmp \
    #     install-mpfr \
    #     install-mpc \
    #     install-mpfi \
    #     install-asir \
    #     install-linsolv \
    #     install-asir-contrib

: <<'OPENXM_IGNORE'
    # The build typically creates an OpenXM runtime tree with bin/lib under the repo.
    # We copy/sync that runtime tree into XDG_DATA_HOME so OpenXM_HOME is clean + stable.
    # Try a couple of plausible layouts robustly.
    log_info "Installing runtime tree into: $OPENXM_PREFIX"
    if [ -d "$OPENXM_REPO/OpenXM" ] && [ -d "$OPENXM_REPO/OpenXM/bin" ]; then
        rsync -a --delete "$OPENXM_REPO/OpenXM/" "$OPENXM_PREFIX/"
    else
        # fallback: treat repo root as OpenXM_HOME if it already contains bin/
        if [ -d "$OPENXM_REPO/bin" ]; then
            rsync -a --delete "$OPENXM_REPO/" "$OPENXM_PREFIX/"
        else
            log_error "Could not locate built OpenXM runtime tree (expected OpenXM/bin)."
            log_error "Looked for: $OPENXM_REPO/OpenXM/bin or $OPENXM_REPO/bin"
            exit 1
        fi
    fi

    # --- env file (XDG) ---
    log_info "Writing OpenXM environment file: $OPENXM_ENV_SH"
    tee "$OPENXM_ENV_SH" > /dev/null << EOF
# OpenXM / Risa-Asir environment (XDG-compliant)
export OpenXM_HOME="$OPENXM_PREFIX"
export PATH="\$OpenXM_HOME/bin:\$PATH"
# Some OpenXM components rely on runtime libs in OpenXM_HOME/lib
export LD_LIBRARY_PATH="\$OpenXM_HOME/lib\${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}"
EOF

    log_info "OpenXM environment will be loaded by the repository-managed profile"

    # --- launcher in ~/.local/bin ---
    # Provide a stable 'openxm' command regardless of upstream rc script pathing.
    log_info "Installing launcher: $BIN_DIR/openxm"
    install -m 0755 "$SCRIPT_DIR/scripts/openxm" "$BIN_DIR/openxm"

    # Optional: keep a copy of upstream-generated rc/openxm as openxm.orig if present
    # Upstream suggests generating it in OpenXM/rc via `make`.
    if [ -d "$OPENXM_REPO/rc" ]; then
        cd "$OPENXM_REPO/rc"
        if make; then
            if [ -f "$OPENXM_REPO/rc/openxm" ]; then
                cp -f "$OPENXM_REPO/rc/openxm" "$BIN_DIR/openxm.orig"
                chmod +x "$BIN_DIR/openxm.orig"
                log_info "Saved upstream rc/openxm as: $BIN_DIR/openxm.orig"
            fi
        else
            log_warning "OpenXM/rc make failed; continuing with wrapper launcher only."
        fi
    fi
OPENXM_IGNORE

    log_success "OpenXM installed (OpenXM_HOME=$OPENXM_PREFIX)"
    log_info "Try: source \"$OPENXM_ENV_SH\" && openxm asir"
fi

# =============================================================================
# SECTION 36: TEXLIVE INSTALLATION
# =============================================================================
if \
	(( DO_TEX )) && \
	prompt_continue "Install TeX Live?" && \
	: \
; then
    log_section "TEXLIVE INSTALLATION"
    
    # Install system dependencies
    log_info "Installing system dependencies..."
    apt_install wget perl-tk fontconfig
    
    # Download TeX Live installer
    log_info "Downloading TeX Live installer..."
    cd "$SRC_DIR"
    wget -O install-tl-unx.tar.gz "https://mirror.ctan.org/systems/texlive/tlnet/install-tl-unx.tar.gz"
    tar -xzf install-tl-unx.tar.gz
    
    # Find the extracted directory (it's usually named install-tl-YYYYMMDD)
    INSTALL_DIR=$(find . -maxdepth 1 -type d -name "install-tl-*" | head -1)
    if [ -z "$INSTALL_DIR" ]; then
        log_error "Could not find TeX Live installer directory"
        exit 1
    fi
    cd "$INSTALL_DIR"
    
    # Create installation profile for automated installation
    log_info "Creating TeX Live installation profile..."
    tee texlive.profile > /dev/null << EOF
# TeX Live installation profile
# This profile installs TeX Live to $HOME/soft/texlive
selected_scheme scheme-full
# Install tree (per-user)
TEXDIR $HOME/soft/texlive/2025

# Per-user config/cache → XDG
TEXMFCONFIG $XDG_CONFIG_HOME/texlive/texmf-config
TEXMFVAR    $XDG_CACHE_HOME/texlive/texmf-var

# User data tree (where your own sty/cls live)
TEXMFHOME   $XDG_DATA_HOME/texmf

# System-like trees kept under your TEXDIR (no root needed)
TEXMFSYSCONFIG $HOME/soft/texlive/2025/texmf-config
TEXMFSYSVAR    $HOME/soft/texlive/2025/texmf-var
TEXMFLOCAL     $HOME/soft/texlive/texmf-local
binary_x86_64-linux 1
instopt_adjustpath 0
instopt_adjustrepo 1
instopt_letter 0
instopt_portable 0
instopt_write18_restricted 1
tlpdbopt_autobackup 1
tlpdbopt_backupdir tlpkg/backups
tlpdbopt_create_formats 1
tlpdbopt_desktop_integration 1
tlpdbopt_file_assocs 1
tlpdbopt_generate_updmap 0
tlpdbopt_install_docfiles 1
tlpdbopt_install_srcfiles 1
tlpdbopt_post_code 1
tlpdbopt_sys_bin /usr/local/bin
tlpdbopt_sys_info /usr/local/share/info
tlpdbopt_sys_man /usr/local/share/man
tlpdbopt_w32_multi_user 1
EOF
    
    # Replace $HOME with actual path in profile
    sed -i "s|\$HOME|$HOME|g" texlive.profile
    
    # Run automated installation
    log_info "Running TeX Live installation (this may take a while)..."
    ./install-tl --repository=https://mirror.ox.ac.uk/sites/ctan.org/systems/texlive/tlnet \
                 --profile=texlive.profile \
                 --no-interaction
    
    if [ $? -eq 0 ]; then
        log_success "TeX Live installed successfully"
        
        # if command -v pdflatex &> /dev/null; then
        #     log_success "TeX Live installation verified - pdflatex is available"
        # else
        #     log_warning "TeX Live installation may have issues - pdflatex not found in PATH"
        # fi
        
        # Clean up installer
        log_info "Cleaning up installer files..."
        cd "$SRC_DIR"
        rm -rf install-tl-* texlive.profile
        
        log_success "TeX Live installation complete!"
        log_info "Environment setup script created at: $HOME/soft/texlive-env.sh"
        log_info "To use TeX Live in current session, run: source $HOME/soft/texlive-env.sh"
        
    else
        log_error "TeX Live installation failed"
        exit 1
    fi
fi

# =============================================================================
# SECTION 37: krita and write
# =============================================================================
if \
	(( DO_KRITA )) && \
	prompt_continue "Install krita?" && \
	: \
; then
    log_section "KRITA INSTALLATION"

    log_info "Installing Krita via AppImage..."

        KRITA_BASE_URL="https://download.kde.org/stable/krita"
        KRITA_VERSION="${KRITA_VERSION:-5.2.11}"

        KRITA_DIR="$HOME/soft/krita"
        mkdir -p "$KRITA_DIR" "$BIN_DIR"

        KRITA_APPIMAGE_NAME="krita-${KRITA_VERSION}-x86_64.AppImage"
        KRITA_APPIMAGE_URL="${KRITA_BASE_URL}/${KRITA_VERSION}/${KRITA_APPIMAGE_NAME}"
        KRITA_APPIMAGE_PATH="${KRITA_DIR}/${KRITA_APPIMAGE_NAME}"

        # AppImages commonly require FUSE2 on Ubuntu; install if missing
        if ! ldconfig -p 2>/dev/null | grep -q 'libfuse\.so\.2'; then
            log_info "Installing FUSE2 runtime needed by many AppImages..."
            refresh_sudo
            apt_install libfuse2 || apt_install libfuse2t64 || true
        fi

        if [[ -f "$KRITA_APPIMAGE_PATH" ]]; then
            log_info "Krita AppImage already present: $KRITA_APPIMAGE_PATH"
        else
            log_info "Downloading Krita ${KRITA_VERSION} AppImage..."
            curl -fL --retry 3 --retry-delay 2 -o "$KRITA_APPIMAGE_PATH" "$KRITA_APPIMAGE_URL"
            chmod +x "$KRITA_APPIMAGE_PATH"
        fi

        # Create/update a stable symlink "krita.AppImage" and a launcher in PATH
        ln -sf "$KRITA_APPIMAGE_PATH" "${KRITA_DIR}/krita.AppImage"
        ln -sf "${KRITA_DIR}/krita.AppImage" "$BIN_DIR/krita"

        log_success "Krita installed (AppImage). Run: krita"
        log_info "Installed at: ${KRITA_APPIMAGE_PATH}"
        log_info "To update, set KRITA_VERSION explicitly and re-run this component."
fi

# =============================================================================
# SECTION 39: SINGULAR COMPUTER ALGEBRA SYSTEM (LOCAL INSTALL, NO SUDO)
# =============================================================================
if \
    # (( DO_SCI )) && \
    (( DO_SINGULAR )) && \
    prompt_continue "Install Singular locally (no sudo)?" && \
    : \
; then
    log_section "SINGULAR COMPUTER ALGEBRA SYSTEM INSTALLATION (LOCAL)"
    log_info "Reinstalling Singular in local prefix for a clean, deterministic setup."

    # -------------------------------------------------------------------------
    # 1. Paths and versions
    # -------------------------------------------------------------------------
    # Where to install Singular (default: ~/.local, kept consistent with SCI_PREFIX)
    SINGULAR_PREFIX="${SCI_PREFIX:-$HOME/.local}"

    # Keep foundational releases explicit and overridable.
    SINGULAR_TAG="${SINGULAR_TAG:-Release-4-4-1}"
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
        exit 1
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
                exit 1
            fi
        else
            log_error "Neither ./configure nor ./autogen.sh found in $(pwd)"
            log_error "Consider using an official release tarball from the Singular download page instead of a raw GitHub snapshot."
            exit 1
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
        exit 1
    fi

    # Use your generic helper for build + install into user prefix
    build_and_install "Singular" "make -j${BUILD_JOBS:-$(default_build_jobs)}" "make install" true

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
            log_warning "Singular is found in PATH but a basic 'quit' test failed"
        fi
    else
        log_error "Singular not found in PATH after installation; check $SINGULAR_PREFIX/bin and PATH"
    fi
fi

# =============================================================================
# SECTION 40: MACAULAY2 COMPUTER ALGEBRA SYSTEM
# =============================================================================
if \
    (( DO_MACAULAY2 )) && \
    prompt_continue "Install Macaulay2 Computer Algebra System from PPA?" && \
    : \
; then
    log_section "MACAULAY2 COMPUTER ALGEBRA SYSTEM INSTALLATION (PPA)"

    INSTALL_MACAULAY2=false

    # Check if M2 is already installed.
    if command -v M2 &> /dev/null; then
        # Extract version; fails softly to "unknown".
        CURRENT_VERSION=$(
            M2 --version 2>/dev/null \
                | head -n1 \
                || echo "unknown"
        )
        log_info "Macaulay2 is already installed (version: $CURRENT_VERSION)"

        if prompt_continue "Reinstall/update Macaulay2 via PPA?"; then
            INSTALL_MACAULAY2=true
        else
            log_info "Skipping Macaulay2 installation"
        fi
    else
        INSTALL_MACAULAY2=true
    fi

    if [[ "$INSTALL_MACAULAY2" = true ]]; then
        log_info "Adding official Macaulay2 PPA: ppa:macaulay2/macaulay2"

        refresh_sudo
        sudo add-apt-repository -y ppa:macaulay2/macaulay2

        log_info "Updating package lists…"
        apt_refresh force

        log_info "Installing Macaulay2…"
        apt_install macaulay2

        # Verify installation
        log_info "Verifying Macaulay2 installation…"
        if command -v M2 &> /dev/null; then
            # Minimal non-interactive invocation
            if M2 --version > /dev/null 2>&1; then
                log_success "Macaulay2 installation verified and working"
            else
                log_warning "Macaulay2 is installed but failed a minimal non-interactive test"
            fi
        else
            log_error "'M2' binary not found after installation"
            log_info "Try: sudo apt-get install -f"
        fi
    fi
fi

# =============================================================================
# SECTION 42: PYTHON TOOLS
# =============================================================================

if \
	(( DO_POETRY )) && \
	prompt_continue "Install Python development tools (Poetry)?" && \
	: \
; then
    log_section "PYTHON DEVELOPMENT TOOLS INSTALLATION"

    # Ensure pipx paths are configured in the user's environment
    log_info "Ensuring pipx paths are configured..."
    pipx ensurepath
    
    # Add pipx bin dir to current session's PATH to find poetry later
    export PATH="$PATH:$HOME/.local/bin"

    # ========================================
    # Poetry 
    # ========================================
    if ! command -v poetry &> /dev/null; then
        log_info "Installing Poetry using pipx..."
        pipx install poetry
        log_success "Poetry installed successfully."
    else
        log_warning "Poetry is already installed, skipping installation."
        # Optionally, you could upgrade it
        # log_info "Upgrading Poetry..."
        # pipx upgrade poetry
    fi

    # ========================================
    # Arxivterminal 
    # ========================================
    log_info "Installing arxivterminal fork..."

    ARXIVTERMINAL_DEV_DIR="$HOME/dev/arxivterminal"
    mkdir -p "$HOME/dev"

    clone_or_update "https://github.com/vchestnov/arxivterminal.git" "$ARXIVTERMINAL_DEV_DIR"
    cd "$ARXIVTERMINAL_DEV_DIR"

    poetry install

    pipx install --force "$ARXIVTERMINAL_DEV_DIR"

    log_success "arxivterminal installed via pipx. Command available as 'arxiv'."
fi

# =============================================================================
# SECTION 43: PASS PASSWORD STORE & GIT CREDENTIAL HELPER
# =============================================================================

if \
	(( DO_GPG )) && \
	prompt_continue "Configure pass-based password store and Git credential helper (for Overleaf tokens, etc.)?" && \
	: \
; then
    log_section "PASS & GIT CREDENTIAL HELPER SETUP"

    # Install pass and GnuPG
    log_info "Installing pass (password-store) and GnuPG..."
    refresh_sudo
    apt_install pass gnupg

    # Configure XDG-style password store directory
    PASSWORD_STORE_DIR_DEFAULT="$HOME/.local/share/password-store"
    export PASSWORD_STORE_DIR="$PASSWORD_STORE_DIR_DEFAULT"

    if [ ! -d "$PASSWORD_STORE_DIR" ]; then
        log_info "Creating password-store directory at $PASSWORD_STORE_DIR"
        mkdir -p "$PASSWORD_STORE_DIR"
    fi

    # Ensure local bin directory exists (should already be created earlier)
    if [ ! -d "$BIN_DIR" ]; then
        log_info "Creating bin directory at $BIN_DIR"
        mkdir -p "$BIN_DIR"
    fi

    if [ -x "$BIN_DIR/git-credential-pass" ] || [ -L "$BIN_DIR/git-credential-pass" ]; then
        log_info "git-credential-pass already installed at $BIN_DIR."
    else
        log_info "Expecting git-credential-pass to be provided by your dotfiles (symlink)."
        log_info "After running makesymlinks.sh, ensure ~/.local/bin/git-credential-pass exists and is executable."
    fi

    log_info "Git credential.helper is managed by config/git/config"

    # Check whether pass is initialized; if not, warn the user
    if ! pass ls >/dev/null 2>&1; then
        log_warning "pass is not initialized yet."
        log_warning "Run 'gpg --full-generate-key' (if needed) and then:"
        log_warning "  pass init <your-gpg-id>"
        log_warning "before using the Git credential helper."
    else
        log_info "pass appears to be initialized; credentials will be stored encrypted."
    fi

    log_success "pass and Git credential helper setup complete"
fi

# =============================================================================
# SECTION 44: GPG TERMINAL PINENTRY (for pass, git-credential-pass)
# =============================================================================
if \
	(( DO_GPG )) && \
	prompt_continue "Configure GnuPG to use terminal (curses) pinentry instead of GUI pop-ups?" && \
	: \
; then
    log_section "GPG TERMINAL PINENTRY SETUP"

    GNUPG_DIR="$HOME/.gnupg"
    AGENT_CONF="$GNUPG_DIR/gpg-agent.conf"

    log_info "Ensuring ~/.gnupg exists and has correct permissions..."
    mkdir -p "$GNUPG_DIR"
    chmod 700 "$GNUPG_DIR"

    # Install pinentry-curses if missing
    if ! command -v pinentry-curses >/dev/null 2>&1; then
        log_info "Installing pinentry-curses..."
        refresh_sudo
        apt_install pinentry-curses
    else
        log_info "pinentry-curses is already installed."
    fi

    if [ ! -e "$AGENT_CONF" ]; then
        log_warning "$AGENT_CONF is missing; run makesymlinks.sh for repository-managed GnuPG configuration."
    fi

    # Restart gpg-agent
    log_info "Restarting gpg-agent..."
    gpgconf --kill gpg-agent || true

    log_success "GPG terminal pinentry configured."
    log_success "Future GPG/pass prompts will appear directly in the terminal."
fi


log_section "BOOTSTRAP COMPLETED SUCCESSFULLY!"
write_run_status success 0
log_info "Profile: $BOOTSTRAP_PROFILE"
log_info "Selected components: ${SELECTED_COMPONENTS[*]:-(none)}"
log_info "Run status: $XDG_STATE_HOME/bootstrap/last-run"
