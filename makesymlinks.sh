#!/usr/bin/env bash
set -euo pipefail

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

# Logging
log_info()    { printf "\033[1;34m[INFO]\033[0m %s\n" "$@"; }
log_warn()    { printf "\033[1;33m[WARN]\033[0m %s\n" "$@"; }
log_error()   { printf "\033[1;31m[ERROR]\033[0m %s\n" "$@"; }
log_success() { printf "\033[1;32m[SUCCESS]\033[0m %s\n" "$@"; }

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

#========================================
# Sanity check
#========================================

if [ ! -d "$DOTFILES_DIR" ]; then
    log_error "DOTFILES_DIR does not exist: $DOTFILES_DIR"
    exit 1
fi

log_info "Using DOTFILES_DIR=$DOTFILES_DIR"
log_info "Using XDG_CONFIG_HOME=$XDG_CONFIG_HOME"

#========================================
# Basic shell dotfiles in $HOME
#========================================

link_file "$DOTFILES_DIR/bashrc"        "$HOME/.bashrc"        "bashrc"
link_file "$DOTFILES_DIR/bash_profile"  "$HOME/.bash_profile"  "bash_profile"
link_file "$DOTFILES_DIR/profile"       "$HOME/.profile"       "POSIX profile"

link_file "$DOTFILES_DIR/tmux.conf"     "$HOME/.tmux.conf"     "tmux"
link_file "$DOTFILES_DIR/vimrc"         "$HOME/.vimrc"         "vimrc"
link_file "$DOTFILES_DIR/vim"           "$HOME/.vim"           ".vim runtime"

# Optional: xinitrc
if [ -f "$DOTFILES_DIR/xinitrc" ]; then
    link_file "$DOTFILES_DIR/xinitrc" "$HOME/.xinitrc" "xinitrc"
fi

#========================================
# Git config in XDG-compliant locations
#   ~/.config/git/config
#   ~/.config/git/ignore
#========================================

ensure_dir "$XDG_CONFIG_HOME"
ensure_dir "$XDG_CONFIG_HOME/git"

link_file "$DOTFILES_DIR/gitconfig"         "$XDG_CONFIG_HOME/git/config" "git config (XDG)"
link_file "$DOTFILES_DIR/gitignore_global"  "$XDG_CONFIG_HOME/git/ignore" "git ignore (XDG)"

#========================================
# XDG configs under ~/.config
#========================================

# Xresources (for dwm/st/dmenu etc.)
ensure_dir "$XDG_CONFIG_HOME/X11"
link_file "$DOTFILES_DIR/config/X11/Xresources" \
          "$XDG_CONFIG_HOME/X11/Xresources" \
          "Xresources"

# fzf config (bash integration)
link_file "$DOTFILES_DIR/config/fzf.bash" \
          "$XDG_CONFIG_HOME/fzf.bash" \
          "fzf bash integration"

# GTK themes
ensure_dir "$XDG_CONFIG_HOME/gtk-3.0"
ensure_dir "$XDG_CONFIG_HOME/gtk-4.0"

link_file "$DOTFILES_DIR/config/gtk-3.0/settings.ini" \
          "$XDG_CONFIG_HOME/gtk-3.0/settings.ini" \
          "GTK 3 settings"

link_file "$DOTFILES_DIR/config/gtk-4.0/settings.ini" \
          "$XDG_CONFIG_HOME/gtk-4.0/settings.ini" \
          "GTK 4 settings"

# Vifm
ensure_dir "$XDG_CONFIG_HOME/vifm"
link_file "$DOTFILES_DIR/config/vifm/vifmrc" \
          "$XDG_CONFIG_HOME/vifm/vifmrc" \
          "vifmrc"

# Zathura
ensure_dir "$XDG_CONFIG_HOME/zathura"
link_file "$DOTFILES_DIR/config/zathura/zathurarc" \
          "$XDG_CONFIG_HOME/zathura/zathurarc" \
          "zathura config"

# Scientific & TeXLive env helpers (if you use them via .profile/.bashrc)
if [ -f "$DOTFILES_DIR/config/scientific-env.sh" ]; then
    link_file "$DOTFILES_DIR/config/scientific-env.sh" \
              "$XDG_CONFIG_HOME/scientific-env.sh" \
              "scientific env"
fi

if [ -f "$DOTFILES_DIR/config/texlive-env.sh" ]; then
    link_file "$DOTFILES_DIR/config/texlive-env.sh" \
              "$XDG_CONFIG_HOME/texlive-env.sh" \
              "texlive env"
fi

#========================================
# SSH / GnuPG (permissions matter)
#========================================

# SSH
ensure_dir "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

if [ -f "$DOTFILES_DIR/ssh/config" ]; then
    link_file "$DOTFILES_DIR/ssh/config" "$HOME/.ssh/config" "ssh config"
    chmod 600 "$HOME/.ssh/config" || true
fi

# GPG agent
ensure_dir "$HOME/.gnupg"
chmod 700 "$HOME/.gnupg"

if [ -f "$DOTFILES_DIR/gnupg/gpg-agent.conf" ]; then
    link_file "$DOTFILES_DIR/gnupg/gpg-agent.conf" \
              "$HOME/.gnupg/gpg-agent.conf" \
              "gpg-agent.conf"
fi

#========================================
# User scripts -> ~/.local/bin
#========================================

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

#========================================
# Wolfram: *merge* into ~/.Wolfram, don’t clobber the whole dir
#========================================

if [ -d "$DOTFILES_DIR/Wolfram" ]; then
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

log_info "All dotfile symlinks processed."
