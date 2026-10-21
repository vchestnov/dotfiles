#!/bin/bash
############################
# .make.sh
# This script creates symlinks from the home directory to any desired dotfiles in ~/dotfiles
# Updated to support XDG Base Directory compliance
############################

########## Variables
dir="$HOME/dotfiles"
private_dir="$HOME/dotfiles/dotfiles-private"
olddir="$HOME/.config/dotfiles_old"

# XDG Base Directory variables
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

##########

# Function to create XDG directories
create_xdg_dirs() {
    echo "Creating XDG Base Directory structure..."
    mkdir -p "$XDG_CONFIG_HOME"/{git,X11,readline,wget}
    mkdir -p "$XDG_DATA_HOME"/{vim,bash,zsh,less,cargo,rustup,go}
    mkdir -p "$XDG_STATE_HOME"/{bash,less,wget}
    mkdir -p "$XDG_CACHE_HOME"
    echo "XDG directories created"
}

# Function to backup and symlink files
backup_and_link() {
    local source="$1"
    local target="$2"
    local backup_path="$3"
    
    echo "Processing $target"
    
    # Create target directory if it doesn't exist
    mkdir -p "$(dirname "$target")"
    mkdir -p "$(dirname "$backup_path")"
    
    # Backup existing file/directory
    if [ -e "$target" ] || [ -L "$target" ]; then
        echo "  Backing up existing $target"
        mv "$target" "$backup_path"
    fi
    
    # Create symlink
    echo "  Creating symlink: $target -> $source"
    ln -s "$source" "$target"
}

##########

if [[ "$(uname)" == "Darwin" ]]; then
    # macOS configuration
    # Traditional home dotfiles
    home_files="profile vimrc vim zshrc tmux.conf fzf.zsh"
    
    # XDG config files (source_name:target_path)
    xdg_config_files=(
        "gitconfig:$XDG_CONFIG_HOME/git/config"
        "gitignore_global:$XDG_CONFIG_HOME/git/ignore"
    )
    
    # Private files
    private_files=""
else
    # Linux configuration
    # Traditional home dotfiles (these need to stay in $HOME)
    home_files="profile vimrc vim bashrc zshrc tmux.conf fzf.bash"
    
    # XDG config files (source_name:target_path)
    xdg_config_files=(
        "gitconfig:$XDG_CONFIG_HOME/git/config"
        "gitignore_global:$XDG_CONFIG_HOME/git/ignore"
        "xinitrc:$XDG_CONFIG_HOME/X11/xinitrc"
        "xsession:$XDG_CONFIG_HOME/X11/xsession"
        "Xresources:$XDG_CONFIG_HOME/X11/Xresources"
    )
    
    # Private files that go to XDG state (fixed: using STATE instead of DATA)
    private_xdg_state_files=(
        "bash_history:$XDG_STATE_HOME/bash/history"
    )
fi

##########

# Create backup directory for old dotfiles
echo "Creating $olddir for backup of any existing dotfiles..."
mkdir -p "$olddir"
echo "done"

# Create XDG directories
create_xdg_dirs

# Change to the dotfiles directory
echo "Changing to the $dir directory..."
cd "$dir" || { echo "Failed to change directory to $dir"; exit 1; }
echo "done"

# Process traditional home dotfiles
echo "Processing traditional home dotfiles..."
for file in $home_files; do
    backup_and_link "$dir/$file" "$HOME/.$file" "$olddir/$file"
done

# Process XDG config files
echo "Processing XDG config files..."
for entry in "${xdg_config_files[@]}"; do
    source_name="${entry%%:*}"
    target_path="${entry##*:}"
    backup_path="$olddir/xdg_config/$(basename "$target_path")"
    
    backup_and_link "$dir/$source_name" "$target_path" "$backup_path"
done

# Process private XDG state files (Linux only) - renamed from data to state
if [[ "$(uname)" != "Darwin" ]] && [[ ${#private_xdg_state_files[@]} -gt 0 ]]; then
    echo "Processing private XDG state files..."
    for entry in "${private_xdg_state_files[@]}"; do
        source_name="${entry%%:*}"
        target_path="${entry##*:}"
        backup_path="$olddir/dotfiles-private/$(basename "$target_path")"
        
        backup_and_link "$private_dir/$source_name" "$target_path" "$backup_path"
    done
fi

# Update applications to use XDG paths
echo "Updating application configurations for XDG compliance..."

# Update .bashrc to use XDG HISTFILE (if it exists and is ours)
if [ -f "$HOME/.bashrc" ] && [ -L "$HOME/.bashrc" ]; then
    echo "Note: Update your bashrc to use: export HISTFILE=\"\$XDG_STATE_HOME/bash/history\""
fi

# Update .zshrc to use XDG paths (if it exists and is ours)
if [ -f "$HOME/.zshrc" ] && [ -L "$HOME/.zshrc" ]; then
    echo "Note: Update your zshrc to use XDG paths for history and other data"
fi

# Update vim configuration
if [ -f "$HOME/.vimrc" ] && [ -L "$HOME/.vimrc" ]; then
    echo "Note: Add to your vimrc: set viminfo+=n\$XDG_DATA_HOME/vim/viminfo"
fi

echo ""
echo "=== XDG-Compliant Dotfiles Setup Complete! ==="
echo ""
echo "Your configuration files are now organized as follows:"
echo "  ~/.config/     - Application configurations"
echo "  ~/.local/share/ - Application data"
echo "  ~/.cache/      - Application cache"
echo "  ~/.local/state/ - Application state"
echo ""
echo "Remember to:"
echo "1. Your .profile will automatically set up XDG environment variables"
echo "2. Your .bashrc should source .profile to ensure variables are available"
echo "3. Configure applications to use XDG paths where supported"
echo "4. Restart your session or source ~/.profile"
echo ""
echo "Auf Wiedersehen!"
