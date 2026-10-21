#!/usr/bin/env bash
set -Eeuo pipefail

# Shared by bootstrap and scripts/suckless. Sources are never patched or reset.
suckless_error() {
    printf 'suckless: %s\n' "$*" >&2
    return 1
}

suckless_validate_tool() {
    case "$1" in
        dwm|dmenu|st|slstatus|slock) ;;
        *) suckless_error "Unknown tool: $1"; return 1 ;;
    esac
}

suckless_read_lock() {
    local tool=$1 lock_file=$2 name revision repo_url extra found=0
    suckless_validate_tool "$tool" || return 1
    [[ -f "$lock_file" ]] || { suckless_error "Missing commit list: $lock_file"; return 1; }
    SUCKLESS_REVISION=''
    SUCKLESS_REPO_URL=''
    while read -r name revision repo_url extra || [[ -n "$name" ]]; do
        [[ -z "$name" || "$name" == \#* ]] && continue
        [[ "$name" == "$tool" ]] || continue
        if (( found )) || [[ ! "$revision" =~ ^[0-9a-f]{40}$ || -z "$repo_url" || -n "$extra" ]]; then
            suckless_error "Invalid or duplicate entry for $tool in $lock_file"
            return 1
        fi
        SUCKLESS_REVISION=$revision
        SUCKLESS_REPO_URL=$repo_url
        found=1
    done < "$lock_file"
    (( found )) || { suckless_error "No entry for $tool in $lock_file"; return 1; }
}

suckless_require_repository() {
    local tool=$1 repo_dir="$SRC_DIR/$1" top
    suckless_validate_tool "$tool" || return 1
    top=$(git -C "$repo_dir" rev-parse --show-toplevel 2>/dev/null) || {
        suckless_error "No maintained repository at $repo_dir; see SUCKLESS_WORKFLOW.md"
        return 1
    }
    [[ "$top" == "$(cd "$repo_dir" && pwd -P)" ]] || {
        suckless_error "$repo_dir is not a repository root"
        return 1
    }
}

suckless_ensure_source() {
    local tool=$1 revision=$2 repo_url=$3 repo_dir="$SRC_DIR/$1" origin_url
    suckless_validate_tool "$tool" || return 1
    if [[ ! -e "$repo_dir" ]]; then
        [[ "$repo_url" != '-' ]] || {
            suckless_error "$repo_dir is missing and $tool has no hosted URL yet; restore the repository or configure its URL"
            return 1
        }
        mkdir -p "$SRC_DIR" || return 1
        git clone --origin origin --branch main "$repo_url" "$repo_dir" || return 1
        git -C "$repo_dir" remote add upstream "https://git.suckless.org/$tool" || return 1
        git -C "$repo_dir" config rerere.enabled true || return 1
        git -C "$repo_dir" config merge.conflictStyle zdiff3 || return 1
        git -C "$repo_dir" config pull.ff only || return 1
    fi
    suckless_require_repository "$tool" || return 1
    # Fetch only when the pinned object is absent. Never fetch or merge upstream
    # during installation, and never change an existing remote or branch.
    if ! git -C "$repo_dir" cat-file -e "$revision^{commit}" 2>/dev/null; then
        origin_url=$(git -C "$repo_dir" remote get-url origin 2>/dev/null) || {
            suckless_error "$tool lacks commit $revision and has no origin; restore it from backup"
            return 1
        }
        [[ "$origin_url" != https://git.suckless.org/* && "$origin_url" != git://git.suckless.org/* ]] || {
            suckless_error "$tool origin still points to suckless; configure your maintained repository"
            return 1
        }
        if [[ "$repo_url" != '-' && "$origin_url" != "$repo_url" ]]; then
            suckless_error "$tool origin differs from $repo_url; update the commit list or remote explicitly"
            return 1
        fi
        git -C "$repo_dir" fetch origin || return 1
        git -C "$repo_dir" cat-file -e "$revision^{commit}" 2>/dev/null || {
            suckless_error "$tool origin does not contain pinned commit $revision"
            return 1
        }
    fi
}

suckless_resolve_revision() {
    local tool=$1 ref=$2
    suckless_require_repository "$tool" || return 1
    git -C "$SRC_DIR/$tool" rev-parse --verify --end-of-options "$ref^{commit}"
}

suckless_prepare_build() {
    local tool=$1 revision=$2 build_root
    suckless_require_repository "$tool" || return 1
    [[ "$revision" =~ ^[0-9a-f]{40}$ ]] || { suckless_error "Expected a full commit ID for $tool"; return 1; }
    git -C "$SRC_DIR/$tool" cat-file -e "$revision^{commit}" || return 1
    build_root="$BUILD_DIR/suckless/$tool"
    mkdir -p "$build_root" || return 1
    SUCKLESS_BUILD_DIR=$(mktemp -d "$build_root/${revision:0:12}.XXXXXX") || return 1
    git -C "$SRC_DIR/$tool" archive "$revision" | tar -xf - -C "$SUCKLESS_BUILD_DIR" || return 1
    printf 'suckless: %s commit %s\nBuild directory: %s\n' "$tool" "$revision" "$SUCKLESS_BUILD_DIR"
}

suckless_build_revision() {
    local tool=$1 revision=$2
    suckless_prepare_build "$tool" "$revision" || return 1
    make -C "$SUCKLESS_BUILD_DIR" -j"${BUILD_JOBS:-2}" || return 1
}
