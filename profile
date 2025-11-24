# XDG Base Directory Specification
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_STATE_HOME="$HOME/.local/state"

# Application-specific XDG compliance
export HISTFILE="$XDG_STATE_HOME/bash/history"
export LESSHISTFILE="$XDG_STATE_HOME/less/history"
export CARGO_HOME="$XDG_DATA_HOME/cargo"
export RUSTUP_HOME="$XDG_DATA_HOME/rustup"
export GOPATH="$XDG_DATA_HOME/go"
export IPYTHONDIR="$XDG_CONFIG_HOME/ipython"
export JUPYTER_CONFIG_DIR="$XDG_CONFIG_HOME/jupyter"
export PYTHONSTARTUP="$XDG_CONFIG_HOME/python/pythonrc"
export WGET_HSTS_FILE="$XDG_STATE_HOME/wget/hsts"

# Source existing profile content if it exists
if [ -f "$HOME/.profile.local" ]; then
    . "$HOME/.profile.local"
fi
. "$CARGO_HOME/env"
