#!/usr/bin/env bash
set -Eeuo pipefail # Exit on error, undefined var; fail pipelines

# ============================================================
# Symlink dotfiles into $HOME
#
# - By default assumes dotfiles live in "$HOME/dotfiles"
# - You can override with:
#       DOTFILES_DIR=/some/where ./makesymlinks.sh
# - Existing files are backed up with a timestamp suffix
# ============================================================

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

DRY_RUN=0
if [[ "${1-}" == "--dry" ]]; then
    DRY_RUN=1
    shift
fi

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
    echo -e "\nYou can:"
    echo "1. Fix the issue and re-run the script"
    echo "2. Skip the failed section and continue manually"
    echo "3. Check the logs above for more details"
    exit $exit_code
}

# Set up error trap
trap 'handle_error $LINENO' ERR

# Helpers
ensure_dir() {
    if [ ! -d "$1" ]; then
        mkdir -p "$1"
        log_info "Created directory: $1"
    fi
}

backup_path() {
    local target=$1
    local ts
    ts=$(date +%Y%m%d%H%M%S)
    printf '%s.bak.%s' "$target" "$ts"
}

link_file() {
    local src=$1
    local dest=$2
    local label=${3:-}

    if [ ! -e "$src" ] && [ ! -L "$src" ]; then
        log_warn "Source missing, skipping: $src${label:+ ($label)}"
        return 0
    fi

    if (( DRY_RUN )); then
        log_info "[dry-run] Would link: $src -> $dest${label:+ ($label)}"
        return
    fi

    # Already a symlink at dest?
    if [ -L "$dest" ]; then
        local current
        current=$(readlink -- "$dest" || true)
        if [ "$current" = "$src" ]; then
            log_info "Symlink already correct: $dest -> $src${label:+ ($label)}"
            return 0
        else
            log_warn "Replacing existing symlink: $dest -> $current (new: $src)"
            rm -f -- "$dest"
        fi

    # Regular file or directory: back it up
    elif [ -e "$dest" ]; then
        local backup
        backup=$(backup_path "$dest")
        log_warn "Backing up existing path: $dest -> $backup"
        mv -- "$dest" "$backup"
    fi

    ln -s -- "$src" "$dest"
    log_info "Linked: $dest -> $src${label:+ ($label)}"
}

# =============================================================================
# SETUP: profile selection 
# =============================================================================

# You can call this script as:
#   ./makesymlinks.sh            # default profile: desktop
#   ./makesymlinks.sh server     # use server profile
# or set BOOTSTRAP_PROFILE in the environment.

BOOTSTRAP_PROFILE="${BOOTSTRAP_PROFILE:-desktop}"

if [[ $# -gt 0 ]]; then
    BOOTSTRAP_PROFILE="$1"
    shift
fi

log_info "Using bootstrap profile: $BOOTSTRAP_PROFILE"

# Default feature flags for desktop profile
DO_CORE=1         # core directories, shell basics
DO_EXPERIMENTAL=0 # dev stub
DO_FZF=1
DO_GIT=1
DO_GPG=1
DO_GUI=1          # GUI stuff for desktop
DO_SCI=1          # scientific env
DO_SSH=1
DO_TEX=1
DO_USER=1         # User scripts
DO_VIFM=1
DO_WOLFRAM=1
DO_TEMPLATES=1
DO_KRITA=1

case "$BOOTSTRAP_PROFILE" in
    desktop)
        # defaults already represent desktop
        ;;
    server)
        DO_CORE=1
        DO_EXPERIMENTAL=0
        DO_FZF=1
        DO_GIT=1
        DO_GPG=0
        DO_GUI=0
        DO_SCI=1
        DO_SSH=0
        DO_TEX=0
        DO_USER=1
        DO_VIFM=0
        DO_WOLFRAM=1
        DO_TEMPLATES=0
        DO_KRITA=0
        ;;
    nothing)
        DO_CORE=0
        DO_EXPERIMENTAL=0
        DO_FZF=0
        DO_GIT=0
        DO_GPG=0
        DO_GUI=0
        DO_SCI=0
        DO_SSH=0
        DO_TEX=0
        DO_USER=0
        DO_VIFM=0
        DO_WOLFRAM=0
        DO_TEMPLATES=0
        DO_KRITA=1
        ;;
    *)
        log_error "Unknown profile '$BOOTSTRAP_PROFILE'!"
        exit 1
        ;;
esac


# Logging
log_info()    { printf "\033[1;34m[INFO]\033[0m %s\n" "$@"; }
log_warn()    { printf "\033[1;33m[WARN]\033[0m %s\n" "$@"; }
log_error()   { printf "\033[1;31m[ERROR]\033[0m %s\n" "$@"; }
log_success() { printf "\033[1;32m[SUCCESS]\033[0m %s\n" "$@"; }

# =============================================================================
# SECTION 01: Sanity check
# =============================================================================

if [ ! -d "$DOTFILES_DIR" ]; then
    log_error "DOTFILES_DIR does not exist: $DOTFILES_DIR"
    exit 1
fi

log_info "Using DOTFILES_DIR=$DOTFILES_DIR"
log_info "Using XDG_CONFIG_HOME=$XDG_CONFIG_HOME"

# =============================================================================
# SECTION 02: Basic shell dotfiles in $HOME
# =============================================================================

if \
    (( DO_CORE )) && \
    : \
; then
    link_file "$DOTFILES_DIR/bashrc"        "$HOME/.bashrc"        "bashrc"
    link_file "$DOTFILES_DIR/bash_profile"  "$HOME/.bash_profile"  "bash_profile"
    link_file "$DOTFILES_DIR/profile"       "$HOME/.profile"       "POSIX profile"

    link_file "$DOTFILES_DIR/tmux.conf"     "$HOME/.tmux.conf"     "tmux"
    link_file "$DOTFILES_DIR/vimrc"         "$HOME/.vimrc"         "vimrc"
    link_file "$DOTFILES_DIR/vim"           "$HOME/.vim"           ".vim runtime"
fi

if \
    (( DO_EXPERIMENTAL)) && \
    : \
; then
    # Optional: xinitrc
    if [ -f "$DOTFILES_DIR/xinitrc" ]; then
        link_file "$DOTFILES_DIR/xinitrc" "$HOME/.xinitrc" "xinitrc"
    fi
fi

# =============================================================================
# SECTION 03: Git config in XDG-compliant locations
#   ~/.config/git/config
#   ~/.config/git/ignore
# =============================================================================

if \
    (( DO_GIT )) && \
    : \
; then
    ensure_dir "$XDG_CONFIG_HOME"
    ensure_dir "$XDG_CONFIG_HOME/git"
    link_file "$DOTFILES_DIR/config/git/config"    "$XDG_CONFIG_HOME/git/config"    "git config (XDG)"
    link_file "$DOTFILES_DIR/config/git/ignore"    "$XDG_CONFIG_HOME/git/ignore"    "git ignore (XDG)"
    link_file "$DOTFILES_DIR/config/git/config_ox" "$XDG_CONFIG_HOME/git/config_ox" "git config for Oxford (XDG)"
fi

# =============================================================================
# SECTION 04: XDG configs under ~/.config
# =============================================================================

if \
    (( DO_GUI )) && \
    : \
; then
    # Xresources (for dwm/st/dmenu etc.)
    ensure_dir "$XDG_CONFIG_HOME/X11"
    link_file "$DOTFILES_DIR/config/X11/Xresources" \
              "$XDG_CONFIG_HOME/X11/Xresources" \
              "Xresources"

    # GTK themes
    ensure_dir "$XDG_CONFIG_HOME/gtk-3.0"
    ensure_dir "$XDG_CONFIG_HOME/gtk-4.0"
    link_file "$DOTFILES_DIR/config/gtk-3.0/settings.ini" \
              "$XDG_CONFIG_HOME/gtk-3.0/settings.ini" \
              "GTK 3 settings"
    link_file "$DOTFILES_DIR/config/gtk-4.0/settings.ini" \
              "$XDG_CONFIG_HOME/gtk-4.0/settings.ini" \
              "GTK 4 settings"

    # Zathura
    ensure_dir "$XDG_CONFIG_HOME/zathura"
    link_file "$DOTFILES_DIR/config/zathura/zathurarc" \
              "$XDG_CONFIG_HOME/zathura/zathurarc" \
              "zathura config"
fi


if \
    (( DO_FZF )) && \
    : \
; then
    # fzf config (bash integration)
    link_file "$DOTFILES_DIR/config/fzf.bash" \
              "$XDG_CONFIG_HOME/fzf.bash" \
              "fzf bash integration"
fi


if \
    (( DO_VIFM )) && \
    : \
; then
    # Vifm
    ensure_dir "$XDG_CONFIG_HOME/vifm"
    link_file "$DOTFILES_DIR/config/vifm/vifmrc" \
              "$XDG_CONFIG_HOME/vifm/vifmrc" \
              "vifmrc"
fi

if \
    (( DO_SCI )) && \
    : \
; then
    # Scientific & TeXLive env helpers (if you use them via .profile/.bashrc)
    if [ -f "$DOTFILES_DIR/config/scientific-env.sh" ]; then
        link_file "$DOTFILES_DIR/config/scientific-env.sh" \
                  "$XDG_CONFIG_HOME/scientific-env.sh" \
                  "scientific env"
    fi
fi

if \
    (( DO_TEX )) && \
    : \
; then
    if [ -f "$DOTFILES_DIR/config/texlive-env.sh" ]; then
        link_file "$DOTFILES_DIR/config/texlive-env.sh" \
                  "$XDG_CONFIG_HOME/texlive-env.sh" \
                  "texlive env"
    fi
fi

# =============================================================================
# SECTION 05: SSH / GnuPG (permissions matter)
# =============================================================================

if \
    (( DO_SSH )) && \
    : \
; then
    # SSH
    ensure_dir "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"

    if [ -f "$DOTFILES_DIR/ssh/config" ]; then
        link_file "$DOTFILES_DIR/ssh/config" "$HOME/.ssh/config" "ssh config"
        chmod 600 "$HOME/.ssh/config" || true
    fi
fi

if \
    (( DO_GPG )) && \
    : \
; then
    # GPG agent
    ensure_dir "$HOME/.gnupg"
    chmod 700 "$HOME/.gnupg"

    if [ -f "$DOTFILES_DIR/gnupg/gpg-agent.conf" ]; then
        link_file "$DOTFILES_DIR/gnupg/gpg-agent.conf" \
                  "$HOME/.gnupg/gpg-agent.conf" \
                  "gpg-agent.conf"
    fi
fi

# =============================================================================
# SECTION 06: User scripts -> ~/.local/bin
# =============================================================================

if \
    (( DO_USER )) && \
    : \
; then
    ensure_dir "$HOME/.local/bin"

    if [ -d "$DOTFILES_DIR/scripts" ]; then
        for script in "$DOTFILES_DIR"/scripts/*; do
            [ -f "$script" ] || continue
            dest="$HOME/.local/bin/$(basename "$script")"
            link_file "$script" "$dest" "user script"
            # Keep source executable; dest inherits via symlink
            chmod +x "$script" || true
        done
    fi
fi

# =============================================================================
# SECTION 07: Wolfram: *merge* into ~/.Wolfram, don’t clobber the whole dir
# =============================================================================

if \
    (( DO_WOLFRAM)) && \
    [ -d "$DOTFILES_DIR/Wolfram" ] && \
    : \
; then
    ensure_dir "$HOME/.Wolfram"

    # Kernel/init.m
    if [ -f "$DOTFILES_DIR/Wolfram/Kernel/init.m" ]; then
        ensure_dir "$HOME/.Wolfram/Kernel"
        link_file "$DOTFILES_DIR/Wolfram/Kernel/init.m" \
                  "$HOME/.Wolfram/Kernel/init.m" \
                  "Wolfram Kernel init.m"
    fi

    # Applications/* -> ~/.Wolfram/Applications/*
    if [ -d "$DOTFILES_DIR/Wolfram/Applications" ]; then
        ensure_dir "$HOME/.Wolfram/Applications"
        for app in "$DOTFILES_DIR"/Wolfram/Applications/*; do
            [ -e "$app" ] || continue
            name=$(basename "$app")
            link_file "$app" "$HOME/.Wolfram/Applications/$name" \
                      "Wolfram Application $name"
        done
    fi
fi

# =============================================================================
# SECTION 08: Templates
# =============================================================================

if \
    (( DO_TEMPLATES )) && \
    [ -d "$DOTFILES_DIR/templates" ] && \
    : \
; then
    ensure_dir "$HOME/dev"
    ensure_dir "$HOME/dev/templates"

    # LaTeX note templates for ZK workflow
    if [ -d "$DOTFILES_DIR/templates/latex" ]; then
        link_file "$DOTFILES_DIR/templates/latex" \
                  "$HOME/dev/templates/latex" \
                  "LaTeX templates (ZK)"
    else
        log_warn "No LaTeX templates found at: $DOTFILES_DIR/templates/latex"
    fi
fi

# =============================================================================
# SECTION 09: Krita 
# =============================================================================

if \
    (( DO_KRITA)) && \
    [ -d "$DOTFILES_DIR/templates" ] && \
    : \
; then

	#========================================
	# Krita (configs in ~/.config, resources in ~/.local/share)
	#   - Symlink config files
	#   - *Merge* paintoppresets into ~/.local/share/krita/paintoppresets
	#========================================

	# Config files -> ~/.config
	# (These are plain files; linking is typically fine. kritadisplayrc may be machine-dependent.)
	if [ -f "$DOTFILES_DIR/config/kritarc" ] || \
	   [ -f "$DOTFILES_DIR/config/kritashortcutsrc" ] || \
	   [ -f "$DOTFILES_DIR/config/kritadisplayrc" ]; then

		ensure_dir "$XDG_CONFIG_HOME"

		if [ -f "$DOTFILES_DIR/config/kritarc" ]; then
			link_file "$DOTFILES_DIR/config/kritarc" \
					  "$XDG_CONFIG_HOME/kritarc" \
					  "Krita config"
		fi

		if [ -f "$DOTFILES_DIR/config/kritashortcutsrc" ]; then
			link_file "$DOTFILES_DIR/config/kritashortcutsrc" \
					  "$XDG_CONFIG_HOME/kritashortcutsrc" \
					  "Krita shortcuts"
		fi

		if [ -f "$DOTFILES_DIR/config/kritadisplayrc" ]; then
			link_file "$DOTFILES_DIR/config/kritadisplayrc" \
					  "$XDG_CONFIG_HOME/kritadisplayrc" \
					  "Krita display"
		fi
	fi

	# Presets/resources -> ~/.local/share/krita (merge individual files)
	if [ -d "$DOTFILES_DIR/krita/paintoppresets" ]; then
		ensure_dir "$HOME/.local/share"
		ensure_dir "$HOME/.local/share/krita"
		ensure_dir "$HOME/.local/share/krita/paintoppresets"

		for preset in "$DOTFILES_DIR"/krita/paintoppresets/*; do
			[ -e "$preset" ] || continue
			name=$(basename "$preset")
			link_file "$preset" \
					  "$HOME/.local/share/krita/paintoppresets/$name" \
					  "Krita paintop preset $name"
		done
	fi
fi


# =============================================================================
# OUTRO
# =============================================================================

log_info "All dotfile symlinks processed."
