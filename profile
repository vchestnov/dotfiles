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
export CONDA_HOME="${CONDA_HOME:-$XDG_DATA_HOME/miniforge3}"
export CONDARC="${CONDARC:-$XDG_CONFIG_HOME/conda/condarc}"
export CONDA_ENVS_PATH="${CONDA_ENVS_PATH:-$XDG_DATA_HOME/conda/envs}"
export CONDA_PKGS_DIRS="${CONDA_PKGS_DIRS:-$XDG_CACHE_HOME/conda/pkgs}"
export MAMBA_ROOT_PREFIX="${MAMBA_ROOT_PREFIX:-$CONDA_HOME}"
export POLYMAKE_USER_DIR="${POLYMAKE_USER_DIR:-$XDG_CONFIG_HOME/polymake/user}"
export POLYMAKE_CONFIG_PATH="${POLYMAKE_CONFIG_PATH:-user=$POLYMAKE_USER_DIR}"
export MAILDIR="${MAILDIR:-$XDG_DATA_HOME/mail}"
export NOTMUCH_PROFILE="${NOTMUCH_PROFILE:-default}"
export NOTMUCH_CONFIG="${NOTMUCH_CONFIG:-$XDG_CONFIG_HOME/notmuch/$NOTMUCH_PROFILE/config}"
export MSMTP_CONFIG="${MSMTP_CONFIG:-$XDG_CONFIG_HOME/msmtp/config}"

# Go toolchain (repo-managed XDG config)
[ -f "$XDG_CONFIG_HOME/go/env.sh" ] && . "$XDG_CONFIG_HOME/go/env.sh"

# Disable IBus to prevent conflicts with setxkbmap
# export GTK_IM_MODULE=none
# export QT_IM_MODULE=none
# export XMODIFIERS=
export GTK_IM_MODULE=xim
export QT_IM_MODULE=xim
export XMODIFIERS=@im=xim

# Source existing profile content if it exists
[ -f "$HOME/.profile.local" ] && . "$HOME/.profile.local"

# Conda/Mamba (XDG) environment
case ":$PATH:" in
    *:"$CONDA_HOME/condabin":*) ;;
    *) PATH="$CONDA_HOME/condabin${PATH:+:$PATH}" ;;
esac
export PATH

[ -f "$CONDA_HOME/etc/profile.d/conda.sh" ] && . "$CONDA_HOME/etc/profile.d/conda.sh"
[ -f "$CONDA_HOME/etc/profile.d/mamba.sh" ] && . "$CONDA_HOME/etc/profile.d/mamba.sh"

# Rust (XDG) environment
[ -f "$CARGO_HOME/env" ] && . "$CARGO_HOME/env"
. "$CARGO_HOME/env"
