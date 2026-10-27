#!/usr/bin/env bash
set -Eeuo pipefail

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

refresh_sudo() {
    sudo -v
}

# All arguments after the optional --system flag are passed to make as words.
# Use direct cmake/ninja calls for projects with a different build system.
build_and_install() {
    local project_name=$1 system=false
    shift
    if [[ "${1:-}" == --system ]]; then system=true; shift; fi
    log_info "Building $project_name..."
    make -j"${BUILD_JOBS:-$(default_build_jobs)}" "$@"
    if $system; then
        refresh_sudo
        sudo make install "$@"
    else
        make install "$@"
    fi
    log_success "$project_name installed"
}

setup_science_environment() {
    SCI_JOBS="${SCI_JOBS:-${BUILD_JOBS:-$(default_build_jobs)}}"
    mkdir -p "$SRC_DIR" "$SCI_REPOS_DIR" "$SCI_PREFIX/bin"
    if [[ "${SCI_ENV_READY:-false}" == true ]]; then return 0; fi
    export PATH="$SCI_PREFIX/bin:$PATH"
    export CPPFLAGS="-I$SCI_PREFIX/include${CPPFLAGS:+ $CPPFLAGS}"
    export LDFLAGS="-L$SCI_PREFIX/lib${LDFLAGS:+ $LDFLAGS}"
    export PKG_CONFIG_PATH="$SCI_PREFIX/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
    export LD_LIBRARY_PATH="$SCI_PREFIX/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    SCI_ENV_READY=true
}

clone_sci_repo() {
    local name=$1 url=$2
    log_info "Setting up repo: $name"
    clone_or_update "$url" "$SCI_REPOS_DIR/$name"
}

clone_or_update() {
    local repo_url="$1"
    local dest_dir="$2"
    local branch="${3:-}"   # optional branch

    if [ -d "$dest_dir/.git" ]; then
        log_info "Updating existing repository in $dest_dir"
        cd "$dest_dir" || return 1

        if [[ -n "$(git status --porcelain)" ]]; then
            log_warning "Repository has local changes; using it without updating: $dest_dir"
            return 0
        fi

        if [[ "$(git remote get-url origin)" != "$repo_url" ]]; then
            log_error "Origin differs from $repo_url in $dest_dir; update the remote explicitly."
            return 1
        fi

        # If no branch specified, detect default branch from remote
        if [[ -z "$branch" ]]; then
            branch=$(git remote show origin 2>/dev/null \
                        | awk '/HEAD branch/ {print $NF}') || branch=''

            # Fallback to main/master if detection failed
            if [[ -z "$branch" ]]; then
                if git ls-remote --exit-code --heads origin main &>/dev/null; then
                    branch="main"
                elif git ls-remote --exit-code --heads origin master &>/dev/null; then
                    branch="master"
                else
                    log_warning "Could not determine default branch for $repo_url; using 'main' as fallback."
                    branch="main"
                fi
            fi
        fi

        # Fetch and fast-forward the chosen branch without rewriting local work.
        git fetch --all --prune || return 1

        if git show-ref --verify --quiet "refs/tags/$branch" && ! git show-ref --verify --quiet "refs/remotes/origin/$branch"; then
            git checkout --detach "$branch" || return 1
        elif [[ -n "$branch" ]]; then
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
        mkdir -p "$(dirname "$dest_dir")" || return 1
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

# Generated files contain host paths. Replace the path itself and back up changes,
# so an existing link can never redirect a write into repository configuration.
write_generated_file() {
    local target=$1 mode=${2:-0644} temporary
    mkdir -p "$(dirname "$target")"
    temporary=$(mktemp "${target}.tmp.XXXXXX")
    cat > "$temporary"
    chmod "$mode" "$temporary"
    if [[ -e "$target" || -L "$target" ]]; then
        if cmp -s "$temporary" "$target" && [[ ! -L "$target" ]]; then
            chmod "$mode" "$target"
            rm -- "$temporary"
            return 0
        fi
        local backup="${target}.backup.$(date +%Y%m%dT%H%M%S).$$"
        log_warning "Preserving $target as $backup"
        mv -- "$target" "$backup"
    fi
    mv -- "$temporary" "$target"
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
    git apply --check "$patch_file" >&2
    return 1
}

ensure_cargo_toolchain() {
    local toolchain=${1:-}
    local -a rustup_args=(-y --no-modify-path)
    export CARGO_HOME="${CARGO_HOME:-$XDG_DATA_HOME/cargo}"
    export RUSTUP_HOME="${RUSTUP_HOME:-$XDG_DATA_HOME/rustup}"

    mkdir -p "$BIN_DIR" "$CARGO_HOME" "$RUSTUP_HOME"

    if ! command -v cargo >/dev/null 2>&1 \
        || { [[ -n "$toolchain" ]] && ! command -v rustup >/dev/null 2>&1; }; then
        log_info "Installing Rust..."
        if [[ -n "$toolchain" ]]; then
            rustup_args+=(--default-toolchain none --profile minimal)
        fi
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- "${rustup_args[@]}"
    fi

    if [ -f "$CARGO_HOME/env" ]; then
        # shellcheck disable=SC1090
        source "$CARGO_HOME/env"
    fi

    export PATH="$BIN_DIR:$CARGO_HOME/bin:$PATH"

    # An explicit toolchain supports newer source releases without changing the
    # user's default compiler. Callers select it with `rustup run` when building.
    if [[ -n "$toolchain" ]]; then
        rustup toolchain install "$toolchain" --profile minimal --no-self-update
    fi
}

apt_refresh() {
    local mode=${1:-cached}
    if ! $APT_UPDATED || [ "$mode" = force ]; then
        refresh_sudo || return 1
        sudo apt update || return 1
        APT_UPDATED=true
    fi
}

apt_install() {
    apt_refresh || return 1
    refresh_sudo || return 1
    sudo apt install -y "$@"
}
