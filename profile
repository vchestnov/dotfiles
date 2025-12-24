# Ensure ~/.local/bin is in PATH (prepend, safe)
case ":$PATH:" in
    *:"$HOME/.local/bin":*) ;;   # already there
    *) PATH="$HOME/.local/bin${PATH:+:$PATH}" ;;
esac
export PATH

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

# Disable IBus to prevent conflicts with setxkbmap
# export GTK_IM_MODULE=none
# export QT_IM_MODULE=none
# export XMODIFIERS=
export GTK_IM_MODULE=xim
export QT_IM_MODULE=xim
export XMODIFIERS=@im=xim

# Source existing profile content if it exists
[ -f "$HOME/.profile.local" ] && . "$HOME/.profile.local"

# Rust (XDG) environment
[ -f "$CARGO_HOME/env" ] && . "$CARGO_HOME/env"
. "$CARGO_HOME/env"
