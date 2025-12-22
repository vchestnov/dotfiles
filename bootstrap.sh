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

        # Fetch and checkout the chosen branch
        git fetch --all --prune

        if [[ -n "$branch" ]]; then
            # Try to checkout existing local branch, otherwise create tracking branch
            if ! git checkout "$branch" 2>/dev/null; then
                git checkout -b "$branch" "origin/$branch" 2>/dev/null || true
            fi
            git pull origin "$branch" || true
        else
            # Should not really happen, but keep a conservative fallback
            git pull || true
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

# Function to build with make and proper ownership
build_and_install() {
    local project_name=$1
    local build_cmd=${2:-"make -j$(nproc)"}
    local install_cmd=${3:-"make install"}
    local install_to_local=${4:-true}
    
    log_info "Building $project_name..."
    
    # Build as user
    eval "$build_cmd"
    
    # Install with appropriate permissions
    if [ "$install_to_local" = true ]; then
        # Install to user's local directory
        eval "$install_cmd"
        log_info "Installed $project_name to user's local directory"
    else
        # Install system-wide with sudo
        refresh_sudo
        sudo $install_cmd
        log_info "Installed $project_name system-wide"
    fi
}

# =============================================================================
# SETUP: profile selection 
# =============================================================================

# You can call this script as:
#   ./bootstrap.sh            # default profile: desktop
#   ./bootstrap.sh server     # use server profile
# or set BOOTSTRAP_PROFILE in the environment.

BOOTSTRAP_PROFILE="${BOOTSTRAP_PROFILE:-desktop}"

if [[ $# -gt 0 ]]; then
    BOOTSTRAP_PROFILE="$1"
    shift
fi

log_info "Using bootstrap profile: $BOOTSTRAP_PROFILE"

# Default feature flags for desktop profile
DO_CORE=1         # core directories, shell basics
DO_DWM=1          # suckless stuff
DO_GUI=1          # GUI desktop-only stuff
DO_TEX=1          # TeX Live & tex-related env
DO_GPG=1          # gpg-agent + pinentry tweaks
DO_POETRY=1       # poetry / arxivterminal
DO_RUST_TOOLS=1   # rustup + fzf, rg, fd, bat
DO_SCI=1          # scientific stack (GMP, FLINT, FiniteFlow, etc.)
DO_MAC=0          # Macbook-related tweaks
DO_SINGULAR=1     # temp stub for Singular
DO_EXPERIMENTAL=0 # dev stub
DO_SYSTEM=1       # system packages from apt
DO_QD=1           # install QD library
DO_ZK=1           # Zettelkasten + templates

case "$BOOTSTRAP_PROFILE" in
    desktop)
        # defaults already represent desktop
        ;;
    server)
        DO_CORE=1
        DO_DWM=0
        DO_GUI=0
        DO_TEX=0
        DO_GPG=0
        DO_POETRY=0
        DO_RUST_TOOLS=1
        DO_SCI=1
        DO_MAC=0
        DO_SINGULAR=0
        DO_EXPERIMENTAL=0
        DO_SYSTEM=0
        DO_QD=0
        DO_ZK=0
        ;;
    nothing)
        DO_CORE=0
        DO_DWM=0
        DO_GUI=0
        DO_TEX=0
        DO_GPG=0
        DO_POETRY=0
        DO_RUST_TOOLS=0
        DO_SCI=0
        DO_MAC=0
        DO_SINGULAR=1
        DO_SOMETHING=0
        DO_SYSTEM=0
        ;;
    *)
        log_error "Unknown profile '$BOOTSTRAP_PROFILE'!"
        exit 1
        ;;
esac

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

    if command -v sudo >/dev/null 2>&1; then
        log_info "Checking sudo access..."
        if ! sudo -n true 2>/dev/null; then
            log_info "Please enter your password to cache sudo credentials:"
            sudo -v
        fi
    else
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
BUILD_DIR="$HOME/.local/build"
BIN_DIR="$HOME/.local/bin"
SRC_DIR="$HOME/.local/src"

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

    # Add local bin to PATH if not already there
    if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
        echo "export PATH=\"$BIN_DIR:\$PATH\"" >> ~/.bashrc
        export PATH="$BIN_DIR:$PATH"
        log_info "Added $BIN_DIR to PATH"
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
    
    # Update system packages
    log_info "Updating system packages..."
    refresh_sudo
    sudo apt update && sudo apt upgrade -y

    log_info "Installing system packages and build dependencies..."
    sudo apt install -y \
        build-essential \
        git \
        curl \
        wget \
        pkg-c $CONFIG_FILESonfig \
        autoconf \
        automake \
        libtool \
        cmake \
        ninja-build \
        unzip \
        gettext \
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
        golang-go \
        bluetooth \
        bluez \
        bluez-tools \
        rfkill \
        blueman \
        vlc \
        geeqie \
        android-file-transfer \
        gnome-screenshot \
        ffmpeg \
        libxcb-cursor0 \
        lm-sensors \
        rename \
        python3-full \
        libreoffice \
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
        pass

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

    # Remove Ubuntu default directories if they exist and are empty
    for dir in Desktop Documents Downloads Music Pictures Public Templates Videos; do
        if [ -d "$HOME/$dir" ] && [ -z "$(ls -A "$HOME/$dir" 2>/dev/null)" ]; then
            rmdir "$HOME/$dir" 2>/dev/null && log_info "Removed empty $dir directory"
        elif [ -d "$HOME/$dir" ]; then
            log_warning "$dir directory is not empty, skipping removal"
        fi
    done

    # Update user-dirs configuration to point to our structure
    mkdir -p "$HOME/.config"
    tee "$HOME/.config/user-dirs.dirs" > /dev/null << 'EOF'
XDG_DESKTOP_DIR="$HOME/docs"
XDG_DOWNLOAD_DIR="$HOME/docs/downloads"
XDG_TEMPLATES_DIR="$HOME/docs"
XDG_PUBLICSHARE_DIR="$HOME/docs"
XDG_DOCUMENTS_DIR="$HOME/docs"
XDG_MUSIC_DIR="$HOME/docs"
XDG_PICTURES_DIR="$HOME/docs"
XDG_VIDEOS_DIR="$HOME/docs"
EOF

    # Disable Ubuntu's automatic directory creation
    tee "$HOME/.config/user-dirs.conf" > /dev/null << 'EOF'
enabled=False
EOF

    log_success "Clean home directory structure created"
fi

# =============================================================================
# SECTION 04: NAUTILUS REMOVAL
# =============================================================================

if \
    (( DO_SYSTEM )) && \
    prompt_continue "Remove Ubuntu file manager (Nautilus)?" && \
    : \
; then
    log_section "NAUTILUS REMOVAL"
    
    # Remove Ubuntu file manager (Nautilus)
    log_info "Removing Ubuntu file manager (Nautilus)..."
    refresh_sudo
    sudo apt remove -y nautilus nautilus-extension-gnome-terminal 2>/dev/null || true
    sudo apt autoremove -y

    log_success "Ubuntu file manager removed"
fi

# =============================================================================
# SECTION 05: MACBOOK AUDIO FIX
# =============================================================================

if \
    (( DO_MAC )) && \
    prompt_continue "Disable MacBook Air startup sound?" \
    : \
; then
    log_section "MACBOOK AUDIO FIX"

    # MacBook Air startup sound disable
    if [ -f "/sys/firmware/efi/efivars/SystemAudioVolume-7c436110-ab2a-4bbb-a880-fe41995c9f82" ]; then
        log_info "Disabling MacBook Air startup sound..."
        refresh_sudo
        # Remove immutable flag
        sudo chattr -i "/sys/firmware/efi/efivars/SystemAudioVolume-7c436110-ab2a-4bbb-a880-fe41995c9f82" 2>/dev/null || true
	# Mute startup sound (try 0x80 first, fallback to 0x00)
        if printf "\x07\x00\x00\x00\x80" | sudo tee /sys/firmware/efi/efivars/SystemAudioVolume-7c436110-ab2a-4bbb-a880-fe41995c9f82 > /dev/null; then
	    log_success "MacBook Air startup sound disabled (0x80)"
        else
            printf "\x07\x00\x00\x00\x00" | sudo tee /sys/firmware/efi/efivars/SystemAudioVolume-7c436110-ab2a-4bbb-a880-fe41995c9f82 > /dev/null || true
            log_success "MacBook Air startup sound disabled (fallback 0x00)"
        fi
        # Make immutable again
        sudo chattr +i "/sys/firmware/efi/efivars/SystemAudioVolume-7c436110-ab2a-4bbb-a880-fe41995c9f82" 2>/dev/null || true
        log_success "MacBook Air startup sound disabled"
    else
        log_warning "EFI SystemAudioVolume variable not found - startup sound may still play"
    fi
fi

# =============================================================================
# SECTION 06: FONT CONFIGURATION
# =============================================================================

if \
	(( DO_SYSTEM )) && \
	prompt_continue "Install fonts and configure fontconfig?" && \
	: \
; then
    log_section "FONT CONFIGURATION"
    
    # Font-based emoji crash fix - install proper fonts and configure fontconfig
    log_info "Installing fonts and configuring fontconfig to prevent emoji crashes..."

    # Install essential fonts including non-color emoji fonts
    refresh_sudo
    sudo apt install -y \
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

    # Ensure proper ownership
    chown -R "$USER:$(id -gn)" "$HOME/.config/fontconfig"

    log_success "Fonts installed and fontconfig configured to prevent emoji crashes"
fi

# =============================================================================
# SECTION 07: XCLIP
# =============================================================================
if \
    (( DO_CORE )) && \
    prompt_continue "Install xclip?" && \
    : \
; then
    log_section "XCLIP INSTALLATION"

    if command -v xclip &> /dev/null; then
        log_info "xclip already installed at $(command -v xclip)"
        return 0
    fi

    clone_or_update "https://github.com/astrand/xclip.git" "$SRC_DIR/xclip"
    cd "$SRC_DIR/xclip"
    autoreconf
    ./configure --prefix="$HOME/.local"
    build_and_install "xclip" "make -j$(nproc)" "make install" true

    log_success "xclip installed"
fi


# =============================================================================
# SECTION 08: VIM FROM SOURCE
# =============================================================================

if \
	(( DO_CORE )) && \
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

    build_and_install "Vim" "make -j$(nproc)" "make install" true

    : "${XDG_CACHE_HOME:=$HOME/.cache}";
    mkdir -p "$XDG_CACHE_HOME/vim/"{swap,undo,backup}

    log_success "Vim installed with terminal and xclip support"
fi

# =============================================================================
# SECTION 09: RUST TOOLS (FZF, RIPGREP, FD, BAT)
# =============================================================================

if \
    (( DO_RUST_TOOLS )) && \
    prompt_continue "Install Rust and Rust-based tools (fzf, ripgrep, fd, bat)?" && \
    : \
; then

    log_section "RUST TOOLS INSTALLATION"
    
    # Install Rust if needed
    if ! command -v cargo &> /dev/null; then
        log_info "Installing Rust..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source "$CARGO_HOME/env"
        export PATH="$HOME/.cargo/bin:$PATH"
    fi

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

	if [ ! -d "$SRC_DIR/bat" ]; then
		git clone https://github.com/sharkdp/bat.git "$SRC_DIR/bat"
		cd "$SRC_DIR/bat"
		cargo build --release
		cp target/release/bat "$BIN_DIR"
	else
		echo "bat already installed, pulling latest changes..."
		cd "$SRC_DIR/bat"
		git pull
		cargo build --release
		cp target/release/bat "$BIN_DIR"
	fi

	log_success "bat installed"
else
    log_info "Skipping Rust tools installation."
fi

# =============================================================================
# SECTION 10: pre NUCLEAR OPTION: WIPE ALL SUCKLESS TOOLS
# =============================================================================

# Nuclear option - wipe all suckless tools and start completely fresh
if \
	(( DO_DWM )) && \
	prompt_continue "Start completely fresh? (removes all existing suckless directories)" && \
	: \
; then
    log_info "Removing all existing suckless directories..."
    rm -rf "$SRC_DIR/dwm" "$SRC_DIR/dmenu" "$SRC_DIR/st" "$SRC_DIR/slstatus" "$SRC_DIR/slock"
fi

# =============================================================================
# SECTION 11: SUCKLESS TOOLS (DWM)
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

    build_and_install "dwm" "make clean && make -j$(nproc)" "make install" false

    log_success "dwm installed with font-based emoji crash fix"
fi

# =============================================================================
# SECTION 12: SUCKLESS TOOLS (DMENU)
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

    build_and_install "dmenu" "make clean && make -j$(nproc)" "make install" false

    log_success "dmenu installed with font-based emoji crash fix"
fi

# =============================================================================
# SECTION 13: SUCKLESS TOOLS (ST TERMINAL)
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

    build_and_install "st" "make clean && make -j$(nproc)" "make install" false

    log_success "st installed with font-based emoji crash fix"
fi

# =============================================================================
# SECTION 14: SUCKLESS TOOLS (SLSTATUS)
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
    build_and_install "slstatus" "make clean && make -j$(nproc)" "make install" false
    log_success "slstatus installed - configure config.h and integrate with dwm"
fi

# =============================================================================
# SECTION 14: SUCKLESS TOOLS (SLOCK)
# =============================================================================
if \
    (( DO_DWM )) && \
    prompt_continue "Build slock (screen locker)?" && \
    : \
; then
    log_section "SLOCK INSTALLATION"

    # Optional but recommended: integrates lockers with X11 idle + systemd sleep
    refresh_sudo
    sudo apt install -y xss-lock

    log_info "Building slock..."
    clone_or_update "https://git.suckless.org/slock" "$SRC_DIR/slock"
    cd "$SRC_DIR/slock"

    if [ ! -f config.h ]; then
        cp config.def.h config.h
    fi

    build_and_install "slock" "make clean && make -j$(nproc)" "make install" false

    # Convenience wrapper (message flag comes from patching in SECTION 21;
    # without the patch, slock will simply ignore -m and still lock fine.)
    cat > "$HOME/.local/bin/lock" <<'EOF'
#!/usr/bin/env bash
exec slock -m "Locked  $(date '+%a %d %b, %H:%M:%S')"
EOF
    chmod +x "$HOME/.local/bin/lock"

    log_success "slock installed"
fi

# =============================================================================
# SECTION 15: FILE MANAGER AND PDF VIEWER
# =============================================================================

if \
	(( DO_SYSTEM )) && \
	prompt_continue "Install vifm (file manager) and zathura (PDF viewer)?" && \
	: \
; then
    log_section "FILE MANAGER AND PDF VIEWER"
    
    # Install vifm
    log_info "Installing vifm..."
    refresh_sudo
    sudo apt install -y vifm

    log_success "vifm installed"

    log_info "Installing colors for vifm..."
    clone_or_update "https://github.com/vifm/vifm-colors" "$HOME/.config/vifm/colors"
    log_success "Colors for vifm installed"

    # Install zathura and plugins
    log_info "Installing zathura..."
    sudo apt install -y zathura zathura-pdf-poppler zathura-ps zathura-djvu

    log_success "zathura installed"
fi

# =============================================================================
# SECTION 16: NEOVIM SETUP
# =============================================================================

if \
	(( DO_SYSTEM )) && \
	prompt_continue "Install Neovim and kickstart.nvim?" && \
	: \
; then
    log_section "NEOVIM SETUP"
    
    # # Install Neovim and kickstart.nvim
    # log_info "Installing Neovim..."

    # # Remove old neovim if installed via apt
    # refresh_sudo
    # sudo apt remove -y neovim 2>/dev/null || true

    # # Install latest Neovim from GitHub releases
    # log_info "Downloading latest Neovim..."
    # NVIM_VERSION=$(curl -s https://api.github.com/repos/neovim/neovim/releases/latest | grep -Po '"tag_name": "\K[^"]*')
    # wget "https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/nvim-linux64.tar.gz" -O /tmp/nvim-linux64.tar.gz
    # tar -xzf /tmp/nvim-linux64.tar.gz -C /tmp/
    # cp -r /tmp/nvim-linux64/* "$HOME/.local/"
    # rm -rf /tmp/nvim-linux64*

    # # Ensure proper ownership of Neovim files
    # chown -R "$USER:$(id -gn)" "$HOME/.local/bin/nvim" "$HOME/.local/share/nvim" "$HOME/.local/lib/nvim" 2>/dev/null || true
    
    log_info "Building Neovim from source..."
    clone_or_update "https://github.com/neovim/neovim.git" "$SRC_DIR/neovim"

    cd "$SRC_DIR/neovim"
    # Clean previous build artefacts if any
    make distclean 2>/dev/null || true
    rm -rf build .deps 2>/dev/null || true

    # Use the helper to build + install into ~/.local
    #   - CMAKE_BUILD_TYPE=RelWithDebInfo for a “release-ish” build
    #   - CMAKE_INSTALL_PREFIX=$HOME/.local so nvim ends up in ~/.local/bin
    build_and_install \
        "Neovim" \
        "make CMAKE_BUILD_TYPE=RelWithDebInfo CMAKE_INSTALL_PREFIX=$HOME/.local" \
        "make install" \
        true

    # Sanity check: ensure nvim on PATH
    if ! command -v nvim >/dev/null 2>&1; then
        log_warning "nvim is not on PATH; ensure $HOME/.local/bin is in your PATH."
    fi

    # Install kickstart.nvim
    log_info "Setting up kickstart.nvim..."
    if [ -d "$HOME/.config/nvim" ]; then
        log_warning "Existing nvim config found, backing up to ~/.config/nvim.backup"
        mv "$HOME/.config/nvim" "$HOME/.config/nvim.backup.$(date +%Y%m%d_%H%M%S)"
    fi

    git clone https://github.com/nvim-lua/kickstart.nvim.git "$HOME/.config/nvim"
    chown -R "$USER:$(id -gn)" "$HOME/.config/nvim"

    log_success "Neovim and kickstart.nvim installed"
fi

# =============================================================================
# SECTION 17: DWM SESSION CONFIGURATION
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
xset s 300 60            # start screensaver after 5 min, cycle every 60s
xset +dpms
xset dpms 300 600 900    # standby/suspend/off (tweak to taste)

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
# SECTION 18: FIX TOUCHPAD CLICK GESTURES
# =============================================================================

if \
	(( DO_MAC )) && \
	prompt_continue "Fix touchpad left and right click gestures?" && \
	: \
; then
    log_section "TOUCHPAD CONFIGURATION"

    log_info "COnfiguring touchpad click gestures..."
    refresh_sudo
    sudo mkdir -p /etc/X11/xorg.conf.d
    sudo tee /etc/X11/xorg.conf.d/40-libinput-bcm5974.conf > /dev/null << 'EOF'
Section "InputClass"
    Identifier "bcm5974 touchpad"
    MatchProduct "bcm5974"
    MatchIsTouchpad "on"
    Driver "libinput"

    Option "Tapping" "on"
    Option "ClickMethod" "clickfinger"
    Option "TappingButtonMap" "lrm"
    Option "NaturalScrolling" "true"
    Option "DisableWhileTyping" "true"
EndSection
EOF

    log_success "Touchpad configuration applied"
fi

# =============================================================================
# SECTION 19: DOTFILES SETUP
# =============================================================================

if \
	(( DO_CORE )) && \
	prompt_continue "Install and setup dotfiles from GitHub?" && \
	: \
; then
    log_section "DOTFILES SETUP"
    
    # Clone dotfiles repository
    DOTFILES_DIR="$HOME/dotfiles"
    
    if [ -d "$DOTFILES_DIR" ]; then
        log_info "Dotfiles directory exists, updating..."
        cd "$DOTFILES_DIR"
        git fetch origin
        git reset --hard origin/main
    else
        log_info "Cloning dotfiles repository..."
        git clone "https://github.com/vchestnov/dotfiles.git" "$DOTFILES_DIR"
    fi
    
    # Ensure proper ownership
    chown -R "$USER:$(id -gn)" "$DOTFILES_DIR"
    
    # Check if makesymlinks.sh exists and is executable
    MAKESYMLINKS_SCRIPT="$DOTFILES_DIR/makesymlinks.sh"
    if [ -f "$MAKESYMLINKS_SCRIPT" ]; then
        log_info "Found makesymlinks.sh, making it executable..."
        chmod +x "$MAKESYMLINKS_SCRIPT"
        
        # Backup existing config files that might be overwritten
        log_info "Creating backup of existing config files..."
        BACKUP_DIR="$HOME/.config_backup_$(date +%Y%m%d_%H%M%S)"
        mkdir -p "$BACKUP_DIR"
        
        # List of common config files/directories that might be overwritten
        CONFIG_FILES=(
            ".bashrc"
            ".vimrc"
            ".tmux.conf"
            ".gitconfig"
            ".xinitrc"
            ".Xresources"
            ".config/nvim"
            ".config/git"
            ".config/tmux"
        )
        
        for config in "${CONFIG_FILES[@]}"; do
            if [ -e "$HOME/$config" ] && [ ! -L "$HOME/$config" ]; then
                log_info "Backing up $config..."
                cp -r "$HOME/$config" "$BACKUP_DIR/" 2>/dev/null || true
            fi
        done
        
        if [ "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]; then
            log_info "Backup created at: $BACKUP_DIR"
        else
            rmdir "$BACKUP_DIR" 2>/dev/null || true
        fi
        
        # Run the makesymlinks script
        log_info "Running makesymlinks.sh to create symbolic links..."
        cd "$DOTFILES_DIR"
        
        # Run the script and capture output
        if ./makesymlinks.sh; then
            log_success "Dotfiles symbolic links created successfully"
            
            # List what was linked
            log_info "Symbolic links created:"
            find "$HOME" -maxdepth 2 -type l -lname "$DOTFILES_DIR/*" 2>/dev/null | while read -r link; do
                target=$(readlink "$link")
                echo "  ${link#$HOME/} -> ${target#$DOTFILES_DIR/}"
            done
        else
            log_error "makesymlinks.sh failed to execute properly"
            log_error "You may need to run it manually: cd $DOTFILES_DIR && ./makesymlinks.sh"
        fi
    else
        log_error "makesymlinks.sh not found in dotfiles repository"
        log_info "Available files in dotfiles directory:"
        ls -la "$DOTFILES_DIR"
        log_info "You may need to create symbolic links manually"
    fi

    if [[ ! -d $DOTFILES_DIR/private ]]; then
        log_info "Creating directory for private dotfiles (bash history)"
        mkdir -p $DOTFILES_DIR/private
    fi

    # Ensure all config files have proper ownership
    chown "$USER:$(id -gn)" "$HOME/.bash_profile"
    
    log_success "Dotfiles setup completed"
fi


# =============================================================================
# SECTION 20: SSH-FIND-AGENT INSTALLATION
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
    
    # Add ssh-find-agent configuration to bashrc if not already present
    if ! grep -q "ssh-find-agent" "$HOME/.bashrc"; then
        log_info "Adding ssh-find-agent configuration to .bashrc..."
        tee -a "$HOME/.bashrc" > /dev/null << 'EOF'

# SSH agent management with ssh-find-agent
if command -v ssh-find-agent >/dev/null 2>&1; then
    source ssh-find-agent
    set_ssh_agent_socket
fi
EOF
    fi
    
    # Create a helper function for easy SSH agent management
    if ! grep -q "ssh_agent_start" "$HOME/.bashrc"; then
        log_info "Adding SSH agent helper functions to .bashrc..."
        tee -a "$HOME/.bashrc" > /dev/null << 'EOF'

# SSH agent helper functions
ssh_agent_start() {
    eval $(ssh-agent -s)
    ssh-add ~/.ssh/id_rsa 2>/dev/null || ssh-add ~/.ssh/id_ed25519 2>/dev/null || echo "No SSH keys found to add"
}

ssh_agent_list() {
    ssh-find-agent -c
}

ssh_agent_kill() {
    ssh-agent -k
}
EOF
    fi
    
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
# SECTION 21: SUCKLESS TOOLS CONFIGURATION
# =============================================================================
if \
	(( DO_DWM )) && \
	prompt_continue "Configure and patch suckless tools?" && \
	: \
; then
    log_section "SUCKLESS CONFIGURATION"

    PATCHES_DIR="$HOME/dotfiles/patches"

	# apply_patch() {
	# 	local source=$1
	# 	local patch_name=$2
	# 	local patch_args="${3:-}"
	# 	local use_git_apply="${4:-}"  # Pass "git" to use git apply
	# 	local patch_file=""

	# 	# Determine patch source type
	# 	if [[ "$source" =~ ^https?:// ]]; then
	# 		patch_file="${patch_name}.patch"
	# 		if wget -q "$source" -O "$patch_file"; then
	# 			log_info "Downloaded $patch_name patch from URL"
	# 		else
	# 			log_warning "Failed to download $patch_name patch"
	# 			return
	# 		fi
	# 	elif [ -f "$source" ]; then
	# 		patch_file="$source"
	# 		patch_name="$(basename "$source" .patch)"
	# 		log_info "Applying local patch from file: $patch_file"
	# 	else
	# 		log_warning "Local patch not found: $source"
	# 		return
	# 	fi

	# 	# Apply the patch using either `patch` or `git apply`
	# 	if [[ "$use_git_apply" == "git" ]]; then
	# 		if git apply $patch_args "$patch_file"; then
	# 			log_success "$patch_name patch applied successfully with git apply"
	# 		else
	# 			log_error "$patch_name patch failed with git apply"
	# 			cp "$patch_file" "${patch_name}.failed.patch"
	# 			log_info "Failed patch saved as ${patch_name}.failed.patch for manual review"
	# 		fi
	# 	else
	# 		if patch -p1 $patch_args < "$patch_file"; then
	# 			log_success "$patch_name patch applied successfully"
	# 		else
	# 			log_error "$patch_name patch failed"
	# 			cp "$patch_file" "${patch_name}.failed.patch"
	# 			log_info "Failed patch saved as ${patch_name}.failed.patch for manual review"
	# 		fi
	# 	fi
	# }

	apply_patch() {
		local source=$1
		local patch_name=$2
		local patch_args="${3:-}"
		local patch_file=""

		# Determine patch source type
		if [[ "$source" =~ ^https?:// ]]; then
			patch_file="${patch_name}.patch"
			if wget -q "$source" -O "$patch_file"; then
				log_info "Downloaded $patch_name patch from URL"
			else
				log_warning "Failed to download $patch_name patch"
				return
			fi
		elif [ -f "$source" ]; then
			patch_file="$source"
			patch_name="$(basename "$source" .patch)"
			log_info "Applying local patch from file: $patch_file"
		else
			log_warning "Local patch not found: $source"
			return
		fi

		# Apply the patch
		if patch -p1 ${patch_args} < "$patch_file" 2>/dev/null; then
			log_success "$patch_name patch applied successfully"
		else
			log_error "$patch_name patch failed"
			cp "$patch_file" "${patch_name}.failed.patch"
			log_info "Failed patch saved as ${patch_name}.failed.patch for manual review"
		fi
	}

	git_apply_patch() {
		local source=$1
		local patch_file=""

		if [ -f "$source" ]; then
			patch_file="$source"
			patch_name="$(basename "$source" .patch)"
			log_info "Applying local patch from file: $patch_file"
		else
			log_warning "Local patch not found: $source"
			return
		fi

		# Apply the patch
		if git apply "$patch_file" 2>/dev/null; then
			log_success "$patch_name patch applied successfully"
		else
			log_error "$patch_name patch failed"
			cp "$patch_file" "${patch_name}.failed.patch"
			log_info "Failed patch saved as ${patch_name}.failed.patch for manual review"
		fi
	}


	# # Function to apply a patch
    # apply_patch() {
        # local patch_url=$1
        # local patch_name=$2
        # local patch_args="${3:-}"
        
        # if wget -q "$patch_url" -O "${patch_name}.patch" 2>/dev/null; then
            # log_info "Applying $patch_name patch..."
            # if patch -p1 ${patch_args} < "${patch_name}.patch" 2>/dev/null; then
                # log_success "$patch_name patch applied successfully"
            # else
                # # log_warning "$patch_name patch failed - checking for partial application..."
                # # # Try to apply with fuzzy matching
                # # if patch -p1 --fuzz=3 < "${patch_name}.patch" 2>/dev/null; then
                # #     log_success "$patch_name patch applied with fuzzy matching"
                # # else
                    # log_error "$patch_name patch failed"
                    # # Save the failed patch for manual inspection
                    # cp "${patch_name}.patch" "${patch_name}.failed.patch"
                    # log_info "Failed patch saved as ${patch_name}.failed.patch for manual review"
                # # fi
            # fi
            # # rm -f "${patch_name}.patch"
        # else
            # log_warning "Failed to download $patch_name patch"
        # fi
    # }
    
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
        if make -j$(nproc) >/dev/null 2>&1; then
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
# SECTION 22: MAC KEYBOARD CONFIGURATION
# =============================================================================
if \
	(( DO_MAC )) && \
	prompt_continue "Configure Mac keyboard layout (swap Alt and Cmd keys)?" && \
	: \
; then
    log_section "MAC KEYBOARD CONFIGURATION"
    
    log_info "Configuring Mac keyboard layout..."
    
    # Create config directory and flag file
    mkdir -p "$HOME/.config/dwm"
    touch "$HOME/.config/dwm/mac-keyboard"
    
    # Apply immediately for current session
    setxkbmap "us,ru" -option "grp:caps_toggle"
    setxkbmap -option altwin:swap_lalt_lwin
    xset r rate 300 50
    
    log_success "Mac keyboard configuration applied"
    log_info "Keyboard changes:"
    echo "  • Left Alt and Cmd keys swapped"
    # echo "  • Cmd+C, Cmd+V, etc. will work as expected"
    echo "  • dwm modkey remains Alt (now physical Cmd key)"
fi

# =============================================================================
# SECTION 23: MESSENGERS 
# =============================================================================
if \
	(( DO_GUI )) && \
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
    sudo apt update
    check_command "Failed to update APT package lists"
    
    log_info "Installing Zulip and Signal from repositories..."
    sudo apt install -y zulip signal-desktop
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
    
    # Cleanup will be handled by the trap
    log_success "Messengers installation completed"
fi

# =============================================================================
# SECTION 24: MEDIA 
# =============================================================================
if \
	(( DO_GUI )) && \
	prompt_continue "Install media software?" && \
	: \
; then
    log_section "MEDIA SOFTWARE INSTALLATION"

	curl -sS https://download.spotify.com/debian/pubkey_C85668DF69375001.gpg | sudo gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/spotify.gpg
	echo "deb https://repository.spotify.com stable non-free" | sudo tee /etc/apt/sources.list.d/spotify.list

    # Update system packages
    log_info "Updating system packages..."
    refresh_sudo
    sudo apt update && sudo apt upgrade -y

	sudo apt install -y \
		spotify-client

    log_info "Installing media software from repositories..."
fi

# =============================================================================
# SECTION 25: MACBOOK FUNCTION KEYS
# =============================================================================

if \
	(( DO_MAC )) && \
	prompt_continue "Configure MacBook function keys (F1-F12) to work without Fn key?" && \
	: \
; then
    log_section "MACBOOK FUNCTION KEYS CONFIGURATION"
    
    log_info "Configuring function keys to work without Fn key..."
    refresh_sudo
    
    # Check if hid_apple module is available
    if [ -f /sys/module/hid_apple/parameters/fnmode ]; then
        current_fnmode=$(cat /sys/module/hid_apple/parameters/fnmode)
        log_info "Current fnmode setting: $current_fnmode"
        
        # Set fnmode to 2 immediately
        echo 2 | sudo tee /sys/module/hid_apple/parameters/fnmode > /dev/null
        sudo update-initramfs -u -k all
        log_info "Set fnmode to 2 for current session"
        
        # Make the change permanent via GRUB
        if grep -q "hid_apple.fnmode" /etc/default/grub; then
            log_info "Updating existing hid_apple.fnmode parameter in GRUB..."
            sudo sed -i 's/hid_apple\.fnmode=[0-9]/hid_apple.fnmode=2/g' /etc/default/grub
        else
            log_info "Adding hid_apple.fnmode parameter to GRUB..."
            sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="\([^"]*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 hid_apple.fnmode=2"/' /etc/default/grub
        fi
        
        # Update GRUB
        sudo update-grub
        log_success "Function keys configured - F1-F12 will work without Fn key after reboot"
        log_info "Note: Use Fn+F1-F12 for media functions (brightness, volume, etc.)"
    else
        log_info "hid_apple module not found - this fix may not be needed on this system"
    fi
fi

# =============================================================================
# SECTION 26: SCIENTIFIC SOFTWARE (GMP, FLINT, FINITEFLOW)
# =============================================================================

if \
	(( DO_SCI )) && \
	prompt_continue "Install scientific software (GMP, FLINT, FiniteFlow)?" && \
	: \
; then
    log_section "SCIENTIFIC SOFTWARE INSTALLATION"

    SCI_PREFIX="$HOME/.local"
    SCI_ENV_PATH="$HOME/.config/scientific-env.sh"
    SCI_REPOS_DIR="$HOME/soft"

    # Ensure required directories exist
    mkdir -p "$SRC_DIR"
    mkdir -p "$SCI_PREFIX"
    mkdir -p "$(dirname "$SCI_ENV_PATH")"
    mkdir -p "$SCI_REPOS_DIR"

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
    log_info "Installing GMP from source..."
    GMP_VERSION="6.3.0"
    GMP_URL="https://gmplib.org/download/gmp/gmp-${GMP_VERSION}.tar.xz"

    cd "$SRC_DIR"
    wget "$GMP_URL" -O "gmp-${GMP_VERSION}.tar.xz"
    tar -xf "gmp-${GMP_VERSION}.tar.xz"
    cd "gmp-${GMP_VERSION}"

    ./configure --prefix="$SCI_PREFIX" --enable-cxx
    build_and_install "GMP" "make -j$(nproc)" "make install" true
    log_success "GMP installed to $SCI_PREFIX"

    # Update environment for subsequent builds
    export PKG_CONFIG_PATH="$SCI_PREFIX/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
    export LD_LIBRARY_PATH="$SCI_PREFIX/lib:${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

    # ========================================
    # FLINT-FiniteFlow-dep
    # ========================================
    log_info "Installing FLINT-FiniteFlow-dep..."
    clone_or_update "https://github.com/peraro/flint-finiteflow-dep.git" "$SRC_DIR/flint-finiteflow-dep"
    cd "$SRC_DIR/flint-finiteflow-dep"
    
    cmake -DCMAKE_PREFIX_PATH="$SCI_PREFIX" \
          -DCMAKE_INSTALL_PREFIX="$SCI_PREFIX" \
          .
    build_and_install "FLINT-FiniteFlow-dep" "make -j$(nproc)" "make install" true
    log_success "FLINT-FiniteFlow-dep installed to $SCI_PREFIX"
    
    # Update environment for FiniteFlow build
    export PKG_CONFIG_PATH="$SCI_PREFIX/lib/pkgconfig:$PKG_CONFIG_PATH"
    export LD_LIBRARY_PATH="$SCI_PREFIX/lib:$LD_LIBRARY_PATH"


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

        # Reset tracked files to a clean state
        git checkout . 2>/dev/null || true

        # Configure with an absolute prefix 
        log_info "Configuring QD with prefix: $SCI_PREFIX"
        ./configure --prefix="$SCI_PREFIX" || {
            log_error "QD configure failed"
            exit 1
        }

        # Build and install using your helper
        build_and_install "QD" "make -j$(nproc)" "make install" true
        log_success "QD installed to $SCI_PREFIX (libs in $SCI_PREFIX/lib, headers in $SCI_PREFIX/include)"
    fi
        
    # ========================================
    # FiniteFlow
    # ========================================
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
          -DCMAKE_PREFIX_PATH="$SCI_PREFIX" \
          -DMATHLIBINSTALL="$FINITEFLOW_MATHLIB" \
          .
    build_and_install "FiniteFlow" "make -j$(nproc)" "make install" true
    log_success "FiniteFlow installed to $SCI_PREFIX; sources are in $FINITEFLOW_DEV_DIR"

    # ========================================
    # Fermat
    # ========================================
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

    # ========================================
    # Extra tools 
    # ========================================
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

    # Blade / AMFlow / CalcLoop 
    if ! clone_sci_repo "blade" "https://gitee.com/multiloop-pku/blade.git"; then
        log_warning "Skipping repo blade"
    fi
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

    # Private FiniteFlow external packages 
    if ! clone_sci_repo "ff_ext_packages" "git@github.com:peraro/ff_ext_packages.git"; then
        log_warning "Skipping private repo ff_ext_packages (SSH keys not configured or access denied)."
    fi

    log_success "Extra scientific packages cloned into $SCI_REPOS_DIR"
    log_info "Consult each repository's README for Mathematica / workflow-specific setup."
    
    log_success "Scientific software installation complete!"
    log_info "To use the software in current session, run: source \"$SCI_ENV_PATH\""
    log_info "The environment will be automatically loaded in new terminal sessions."
fi

# =============================================================================
# SECTION 27: TEXLIVE INSTALLATION
# =============================================================================
if \
	(( DO_TEX )) && \
	prompt_continue "Install TeX Live?" && \
	: \
; then
    log_section "TEXLIVE INSTALLATION"
    
    # Install system dependencies
    log_info "Installing system dependencies..."
    sudo apt-get update
    sudo apt-get install -y wget perl-tk fontconfig
    
    # Download TeX Live installer
    log_info "Downloading TeX Live installer..."
    cd "$SRC_DIR"
    wget -O install-tl-unx.tar.gz "https://mirror.ctan.org/systems/texlive/tlnet/install-tl-unx.tar.gz"
    tar -xzf install-tl-unx.tar.gz
    
    # Find the extracted directory (it's usually named install-tl-YYYYMMDD)
    INSTALL_DIR=$(find . -maxdepth 1 -type d -name "install-tl-*" | head -1)
    if [ -z "$INSTALL_DIR" ]; then
        log_error "Could not find TeX Live installer directory"
        return 1
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
        return 1
    fi
fi

# =============================================================================
# SECTION 28: krita and write
# =============================================================================
if \
	(( DO_GUI )) && \
	prompt_continue "Install krita and write?" && \
	: \
; then
    log_section "KRITA AND WRITE INSTALLATION"
fi

# =============================================================================
# SECTION 29: SINGULAR COMPUTER ALGEBRA SYSTEM
# =============================================================================
if \
	(( DO_SCI )) && \
    prompt_continue "Install Singular (sudo)?" && \
	: \
; then
    log_section "SINGULAR COMPUTER ALGEBRA SYSTEM INSTALLATION"
    
    # Check if Singular is already installed
    if command -v Singular &> /dev/null; then
        CURRENT_VERSION=$(
            Singular --version 2>&1 \
                | head -1 \
                | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' \
                || echo "unknown"
        )
        log_info "Singular is already installed (version: $CURRENT_VERSION)"
        if ! prompt_continue "Reinstall/update Singular?"; then
            log_info "Skipping Singular installation"
        else
            INSTALL_SINGULAR=true
        fi
    else
        INSTALL_SINGULAR=true
    fi
    
    if [ "$INSTALL_SINGULAR" = true ]; then
        log_info "Installing Singular from official repository..."
        
        refresh_sudo
        
        # Add GPG key
        log_info "Adding Singular repository GPG key..."
        wget -q ftp://jim.mathematik.uni-kl.de/repo/extra/gpg -O - | sudo apt-key add -
        
        # Add repository for Ubuntu 24.04
        log_info "Adding Singular repository for Ubuntu 24.04..."
        echo "deb https://www.singular.uni-kl.de/ftp/repo/ubuntu24 noble main" | sudo tee /etc/apt/sources.list.d/singular.list
        
        # Update and install
        log_info "Updating package list and installing Singular..."
        sudo apt-get update
        sudo apt-get install -y singular41
        
        # Verify installation
        log_info "Verifying Singular installation..."
        if command -v Singular &> /dev/null; then
			# Simple test that Singular can run and quit
            # if echo "quit;" | Singular > /dev/null 2>&1; then
			if Singular -c "quit;" > /dev/null 2>&1; then
                log_success "Singular installation verified and working"
            else
                log_warning "Singular is installed but may have issues running"
            fi
            # VERSION=$(Singular --version -c "quit;" 2>&1 | head -1 || echo "Version check failed")
            # log_success "Singular installation verified: $VERSION"
        else
            log_error "Singular installation verification failed"
            log_info "Try running 'sudo apt-get install -f' to fix any dependency issues"
        fi
    fi
fi

# =============================================================================
# SECTION 30: SINGULAR COMPUTER ALGEBRA SYSTEM (LOCAL INSTALL, NO SUDO)
# =============================================================================
if \
    # (( DO_SCI )) && \
    (( DO_SINGULAR )) && \
    prompt_continue "Install Singular locally (no sudo)?" && \
    : \
; then
    log_section "SINGULAR COMPUTER ALGEBRA SYSTEM INSTALLATION (LOCAL)"

    # -------------------------------------------------------------------------
    # 0. Check if Singular is already installed
    # -------------------------------------------------------------------------
    INSTALL_SINGULAR=true

    if command -v Singular &> /dev/null; then
        CURRENT_VERSION=$(
            Singular --version 2>&1 \
                | head -1 \
                | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' \
                || echo "unknown"
        )
        log_info "Singular is already installed (version: $CURRENT_VERSION)"

        if ! prompt_continue "Reinstall / update Singular (local install)?"; then
            log_info "Skipping Singular installation"
            INSTALL_SINGULAR=false
        fi
    fi

    if [ "$INSTALL_SINGULAR" != true ]; then
        log_info "Section 29: nothing to do."
        return 0 2>/dev/null || true
    fi

    # -------------------------------------------------------------------------
    # 1. Paths and versions
    # -------------------------------------------------------------------------
    # Where to install Singular (default: ~/.local, kept consistent with SCI_PREFIX)
    SINGULAR_PREFIX="${SCI_PREFIX:-$HOME/.local}"

    # Use the latest official release tag from GitHub
    # See: https://github.com/Singular/Singular/tags (Release-4-4-1) :contentReference[oaicite:1]{index=1}
    SINGULAR_TAG="Release-4-4-1"
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

    # -------------------------------------------------------------------------
    # 3. Point build system at locally installed scientific libraries (if any)
    # -------------------------------------------------------------------------
    # DO_SCI section installs GMP/FLINT/etc. into $SCI_PREFIX = ~/.local. :contentReference[oaicite:2]{index=2}
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

    # Keep configure minimal and robust; gfanlib and extra backends can be added later
    if ! ./configure --prefix="$SINGULAR_PREFIX"; then
        log_error "Singular ./configure failed"
        exit 1
    fi

    # Use your generic helper for build + install into user prefix
    build_and_install "Singular" "make -j$(nproc)" "make install" true

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
# SECTION 31: MACAULAY2 COMPUTER ALGEBRA SYSTEM
# =============================================================================
if \
    (( DO_SCI )) && \
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
        sudo apt-get update

        log_info "Installing Macaulay2…"
        sudo apt-get install -y macaulay2

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
# SECTION 32: ZATHURA PDF VIEWER (SOURCE BUILD)
# =============================================================================
if \
	(( DO_GUI )) && \
	prompt_continue "Build zathura PDF viewer from source (fixes link opening issues)?" && \
	: \
; then
    log_section "ZATHURA PDF VIEWER (SOURCE BUILD)"
    
    # Check if zathura is already installed
    if command -v zathura >/dev/null 2>&1; then
        log_info "Zathura already installed: $(zathura --version 2>/dev/null | head -1)"
        if ! prompt_continue "Rebuild zathura from source (recommended for Ubuntu 24.04)?"; then
            log_info "Skipping zathura build"
        else
            BUILD_ZATHURA=true
        fi
    else
        BUILD_ZATHURA=true
    fi
    
    if [ "$BUILD_ZATHURA" = true ]; then
        refresh_sudo
        
        log_info "Installing build dependencies..."
        sudo apt update
        sudo apt install -y \
            build-essential \
            meson \
            ninja-build \
            pkg-config \
            libgtk-3-dev \
            libgirara-dev \
            libpoppler-glib-dev \
            libcairo2-dev \
            libglib2.0-dev \
            libmagic-dev \
            libsynctex-dev \
            libsqlite3-dev \
            libjson-glib-dev \
            libdjvulibre-dev
        
        # Remove conflicting system packages
        log_info "Removing system zathura packages..."
        sudo apt remove -y zathura zathura-* 2>/dev/null || true
        sudo apt autoremove -y
        
        # Create temporary build directory
        BUILD_DIR="$(mktemp -d)"
        cd "$BUILD_DIR"
        
        # Build girara (required dependency)
        log_info "Building girara from source..."
        if clone_or_update "https://github.com/pwmt/girara.git" "$BUILD_DIR/girara" "develop"; then
            cd "$BUILD_DIR/girara"
            if meson setup build && cd build && ninja; then
                sudo ninja install
                log_success "Girara built and installed"
            else
                log_error "Failed to build girara"
                cd "$HOME"
                rm -rf "$BUILD_DIR"
                return 1
            fi
        else
            log_error "Failed to clone girara repository"
            return 1
        fi
        
        # Build zathura
        log_info "Building zathura from source..."
        if clone_or_update "https://github.com/pwmt/zathura.git" "$BUILD_DIR/zathura" "develop"; then
            cd "$BUILD_DIR/zathura"
            git submodule update --init --recursive
            if meson setup build -Dseccomp=disabled && cd build && ninja; then
                sudo ninja install
                log_success "Zathura built and installed"
            else
                log_error "Failed to build zathura"
                cd "$HOME"
                rm -rf "$BUILD_DIR"
                return 1
            fi
        else
            log_error "Failed to clone zathura repository"
            return 1
        fi
        
        # Build PDF plugin
        log_info "Building PDF plugin..."
        if clone_or_update "https://github.com/pwmt/zathura-pdf-poppler.git" "$BUILD_DIR/zathura-pdf-poppler" "develop"; then
            cd "$BUILD_DIR/zathura-pdf-poppler"
            if meson setup build && cd build && ninja; then
                sudo ninja install
                log_success "PDF plugin built and installed"
            else
                log_error "Failed to build PDF plugin"
                cd "$HOME"
                rm -rf "$BUILD_DIR"
                return 1
            fi
        else
            log_error "Failed to clone PDF plugin repository"
            return 1
        fi
        
        # Build DjVu plugin
        log_info "Building DjVu plugin..."
        if clone_or_update "https://github.com/pwmt/zathura-djvu.git" "$BUILD_DIR/zathura-djvu" "develop"; then
            cd "$BUILD_DIR/zathura-djvu"
            if meson setup build && cd build && ninja; then
                sudo ninja install
                log_success "DjVu plugin built and installed"
            else
                log_warning "Failed to build DjVu plugin (PDF support will still work)"
            fi
        else
            log_warning "Failed to clone DjVu plugin repository (PDF support will still work)"
        fi
        
        # Update library cache
        log_info "Updating library cache..."
        sudo ldconfig
        
        # Add GTK warning suppression to bashrc if not already present
        if ! grep -q "NO_AT_BRIDGE" "$HOME/.bashrc" 2>/dev/null; then
            log_info "Adding GTK warning suppression to .bashrc..."
            echo "" >> "$HOME/.bashrc"
            echo "# Suppress GTK accessibility bridge warning" >> "$HOME/.bashrc"
            echo "export NO_AT_BRIDGE=1" >> "$HOME/.bashrc"
        fi
        
        # Cleanup
        cd "$HOME"
        rm -rf "$BUILD_DIR"
        
        # Verification
        log_info "Verifying zathura installation..."
        if command -v zathura >/dev/null 2>&1; then
            ZATHURA_VERSION=$(zathura --version 2>/dev/null | head -1)
            log_success "Zathura installed successfully: $ZATHURA_VERSION"
            
            # Test if plugins are loaded
            if zathura --version 2>/dev/null | grep -q "pdf"; then
                log_success "PDF plugin loaded successfully"
            else
                log_warning "PDF plugin may not be loaded properly"
            fi
            
            log_info "Zathura configuration created at ~/.config/zathura/zathurarc"
            log_info "GTK warning suppression added to ~/.bashrc"
            log_info "Note: Source ~/.bashrc or restart shell to apply environment changes"
        else
            log_error "Zathura installation verification failed"
            return 1
        fi
    fi
fi

# =============================================================================
# SECTION 33: PYTHON TOOLS
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
# SECTION 34: PASS PASSWORD STORE & GIT CREDENTIAL HELPER
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
    sudo apt install -y pass gnupg

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

    # Configure Git to use git-credential-pass
    log_info "Configuring Git to use git-credential-pass as credential helper..."
    git config --global credential.helper pass

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
# SECTION 35: GPG TERMINAL PINENTRY (for pass, git-credential-pass)
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
        sudo apt install -y pinentry-curses
    else
        log_info "pinentry-curses is already installed."
    fi

    # Restart gpg-agent
    log_info "Restarting gpg-agent..."
    gpgconf --kill gpg-agent || true

    log_success "GPG terminal pinentry configured."
    log_success "Future GPG/pass prompts will appear directly in the terminal."
fi


# =============================================================================
# SECTION 36: FINAL OWNERSHIP AND CLEANUP
# =============================================================================

if \
	(( DO_CORE )) && \
	prompt_continue "Perform final ownership checks and cleanup?" && \
	: \
; then
    log_section "FINAL OWNERSHIP AND CLEANUP"
    
    # Final ownership check for all created directories
    log_info "Ensuring proper ownership of all created directories..."
    chown -R "$USER:$(id -gn)" "$HOME/.local" "$HOME/.config" "$HOME/dev" "$HOME/docs" "$HOME/soft" 2>/dev/null || true
    
    # Clean up any temporary files
    log_info "Cleaning up temporary files..."
    rm -f /tmp/nvim-linux64* 2>/dev/null || true
    
    log_success "Final cleanup completed"
fi

# =============================================================================
# OUTRO 
# =============================================================================

log_section "BOOTSTRAP COMPLETED SUCCESSFULLY!"

echo
log_info "Summary of installed tools:"
echo "  • Vim (from git) with terminal and xclip support"
echo "  • fzf, ripgrep (rg), fd (from git)"
echo "  • dwm, dmenu, st (from suckless.org) with font-based emoji crash fix"
echo "  • vifm, zathura"
echo "  • Neovim with kickstart.nvim"
echo "  • tmux, htop"
echo "  • Clean home directory structure: ~/dev, ~/docs, ~/soft"
echo
log_info "Display manager integration:"
echo "  • dwm will appear as an option in your login screen"
echo "  • Select 'dwm' from the session menu when logging in"
echo "  • You can still use 'startx' manually if needed"
echo "  • Other desktop environments remain available"
echo
log_info "Next steps:"
echo "  1. Restart your shell or run: source ~/.bashrc"
echo "  2. Logout and login again - select 'dwm' from session menu"
echo "  3. Check patches_info.txt files in each suckless tool directory for popular patches"
echo "  4. Customize your tools by editing their config.h files and rebuilding"
echo "  5. Open nvim to let kickstart.nvim install plugins automatically"
echo "  6. MacBook Air startup sound should be disabled"
echo
log_info "Directory structure:"
echo "  • Development: ~/dev"
echo "  • Documents and downloads: ~/docs and ~/docs/downloads"
echo "  • Software: ~/soft"
echo "  • Source code: $SRC_DIR"
echo "  • Binaries: $BIN_DIR"
echo "  • Build artifacts: $BUILD_DIR"
echo
log_info "Theme management:"
echo "  • theme-dark, theme-light - Switch between themes"
echo "  • theme-toggle - Toggle between light and dark"
echo "  • theme-status - Check current theme"
echo "  • Themes automatically sync across st, dmenu, and dwm"
echo
log_info "Suckless patches applied:"
echo "  • st: scrollback support with Mac-friendly keybindings (Alt+Up/Down)"
echo "  • dmenu: center positioning and highlight matching"
echo "  • dwm: center floating windows"
echo "  • All tools use coordinated color schemes"
echo
log_info "Scrollback controls in st:"
echo "  • Alt+Up/Down: scroll line by line"
echo "  • Alt+Shift+Up/Down: scroll 5 lines at once"
echo "  • Alt+Page Up/Down: scroll full pages (if available)"
log_info "If you encountered any issues:"
echo "  • Check the error messages above"
echo "  • You can re-run individual sections by answering 'n' to skip completed parts"
echo "  • Most tools can be rebuilt by going to their source directories and running 'make clean && make install'"
echo
log_success "Your Ubuntu 24.04 development environment is ready!"

# Create a script status file
tee "$HOME/.bootstrap_status" > /dev/null << EOF
Bootstrap completed on: $(date)
Sections completed: All sections completed successfully
Last run: $(date +%Y-%m-%d_%H:%M:%S)
Script version: Enhanced with breaks and safepoints
EOF

log_info "Status saved to ~/.bootstrap_status"
