#!/bin/bash
# Scientific software environment setup (GMP, FLINT deps, FiniteFlow)
# All installed under: $HOME/.local

# Binaries (FiniteFlow may provide executables here)
export PATH="$HOME/.local/bin${PATH:+:$PATH}"

# pkg-config files for GMP, FLINT deps, FiniteFlow
export PKG_CONFIG_PATH="$HOME/.local/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"

# Runtime library search path (for dlopen / shared libs)
export LD_LIBRARY_PATH="$HOME/.local/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

# Headers and link-time library path for compilers
export CPATH="$HOME/.local/include${CPATH:+:$CPATH}"
export LIBRARY_PATH="$HOME/.local/lib${LIBRARY_PATH:+:$LIBRARY_PATH}"

# Convenience: location of cloned research repos (Mathematica tools, Blade, AMFlow, etc.)
export SCIENCE_REPOS_DIR="$HOME/soft"
