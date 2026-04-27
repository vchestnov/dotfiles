export PATH="$HOME/.local/bin:${PATH}"
export CPPFLAGS="-I${HOME}/.local/include${CPPFLAGS:+ $CPPFLAGS}"
export LDFLAGS="-L${HOME}/.local/lib${LDFLAGS:+ $LDFLAGS}"

# pkg-config files
export PKG_CONFIG_PATH="${HOME}/.local/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"

# Runtime library search path
export LD_LIBRARY_PATH="${HOME}/.local/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

# Headers and link-time library path for compilers
export CPATH="${HOME}/.local/include${CPATH:+:$CPATH}"
export LIBRARY_PATH="${HOME}/.local/lib${LIBRARY_PATH:+:$LIBRARY_PATH}"

# Convenience
export SCIENCE_REPOS_DIR="${HOME}/soft"

# Julia
export JULIA_DEPOT_PATH="${XDG_DATA_HOME:-${HOME}/.local/share}/julia"
export JULIA_HISTORY="${XDG_STATE_HOME:-${HOME}/.local/state}/julia/repl_history.jl"

# Fermat
export FERMATPATH="${HOME}/.local/bin/fer64"
