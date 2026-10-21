#!/bin/sh
set -eu

# Resolve dotfiles dir (allow overriding via env)
if [ -n "${DOTFILES_DIR:-}" ]; then
    DOTFILES_DIR="$DOTFILES_DIR"
else
    DOTFILES_DIR=$(cd "$(dirname "$0")" && pwd)
fi

log_info()    { printf "\033[1;34m[INFO]\033[0m %s\n" "$@"; }
log_warn()    { printf "\033[1;33m[WARN]\033[0m %s\n" "$@"; }
log_error()   { printf "\033[1;31m[ERROR]\033[0m %s\n" "$@"; }
log_success() { printf "\033[1;32m[SUCCESS]\033[0m %s\n" "$@"; }


link() {
    src="$1"
    dest="$2"

    # If source does not exist, just warn_info and skip
    if [ ! -e "$src" ] && [ ! -L "$src" ]; then
        warn_info "source missing: $src (for $dest)"
        return
    fi

    if [ -L "$dest" ]; then
        # Existing symlink
        current=$(readlink -- "$dest" || true)
        if [ "$current" = "$src" ]; then
            log_info "OK   $dest -> $src"
            return
        else
            warn_info "SKIP $dest is a symlink to $current (expected $src)"
            return
        fi
    elif [ -e "$dest" ]; then
        # Real file/dir already there
        warn_info "SKIP $dest already exists and is not a symlink"
        return
    fi

    mkdir -p "$(dirname "$dest")"
    ln -s "$src" "$dest"
    log_info  "LINK $dest -> $src"
}

log_info "Using DOTFILES_DIR=$DOTFILES_DIR"

###############################################################################
# Shell / login files
###############################################################################

link "$DOTFILES_DIR/bashrc"        "$HOME/.bashrc"
link "$DOTFILES_DIR/bash_profile"  "$HOME/.bash_profile"
link "$DOTFILES_DIR/profile"       "$HOME/.profile"
# link "$DOTFILES_DIR/zshrc"         "$HOME/.zshrc"

###############################################################################
# Editor / terminal tools
###############################################################################

# Vim
link "$DOTFILES_DIR/vimrc"         "$HOME/.vimrc"
link "$DOTFILES_DIR/vim"           "$HOME/.vim"

# tmux
link "$DOTFILES_DIR/tmux.conf"     "$HOME/.tmux.conf"

###############################################################################
# Git
###############################################################################

link "$DOTFILES_DIR/gitconfig"        "$HOME/.config/git/config"
link "$DOTFILES_DIR/gitignore_global" "$HOME/.config/git/ignore"

###############################################################################
# SSH
###############################################################################

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh" 2>/dev/null || true
link "$DOTFILES_DIR/ssh/config"    "$HOME/.ssh/config"

###############################################################################
# GnuPG
###############################################################################

mkdir -p "$HOME/.gnupg"
chmod 700 "$HOME/.gnupg" 2>/dev/null || true
link "$DOTFILES_DIR/gnupg/gpg-agent.conf" "$HOME/.gnupg/gpg-agent.conf"

###############################################################################
# XDG configs (under ~/.config)
###############################################################################

# fzf shell integrations (source these from bashrc/zshrc)
link "$DOTFILES_DIR/config/fzf.bash" "$HOME/.config/fzf.bash"
link "$DOTFILES_DIR/config/fzf.zsh"  "$HOME/.config/fzf.zsh"

# GTK
link "$DOTFILES_DIR/config/gtk-3.0/settings.ini" "$HOME/.config/gtk-3.0/settings.ini"
link "$DOTFILES_DIR/config/gtk-4.0/settings.ini" "$HOME/.config/gtk-4.0/settings.ini"

# X11 Xresources (dwm-session explicitly xrdb-merges this path)
link "$DOTFILES_DIR/config/X11/Xresources" "$HOME/.config/X11/Xresources"

# vifm
link "$DOTFILES_DIR/config/vifm/vifmrc" "$HOME/.config/vifm/vifmrc"

# zathura
link "$DOTFILES_DIR/config/zathura/zathurarc" "$HOME/.config/zathura/zathurarc"

###############################################################################
# Misc applications
###############################################################################

# Wolfram / Mathematica
wolfram_src="$DOTFILES_DIR/Wolfram"
wolfram_dest="$HOME/.Wolfram"

if [ -d "$wolfram_src" ]; then
    mkdir -p "$wolfram_dest"

    # Kernel/init.m
    if [ -f "$wolfram_src/Kernel/init.m" ]; then
        mkdir -p "$wolfram_dest/Kernel"
        link "$wolfram_src/Kernel/init.m" "$wolfram_dest/Kernel/init.m"
    fi

    # Applications: mix of subdirs and files 
    if [ -d "$wolfram_src/Applications" ]; then
        mkdir -p "$wolfram_dest/Applications"

        for item in "$wolfram_src/Applications"/*; do
            [ -e "$item" ] || continue  # handle empty dir safely
            name=$(basename "$item")

            if [ -d "$item" ]; then
                # For a subdirectory we symlink the whole directory under ~/.Wolfram/Applications/.
                link "$item" "$wolfram_dest/Applications/$name"
            else
                # For plain files
                link "$item" "$wolfram_dest/Applications/$name"
            fi
        done
    fi
fi

###############################################################################
# Optional legacy / compatibility links
###############################################################################

# If you decide you *do* want a classic ~/.Xresources for e.g. other tools,
# uncomment the line below. For now we keep a single source of truth under
# ~/.config/X11/Xresources and load it from dwm-session.
#
# link "$DOTFILES_DIR/config/X11/Xresources" "$HOME/.Xresources"
#
# Similarly, if you ever want startx to work out of the box, you can link
# your minimal xinitrc:
#
# link "$DOTFILES_DIR/xinitrc" "$HOME/.xinitrc"

log_info "Done."
