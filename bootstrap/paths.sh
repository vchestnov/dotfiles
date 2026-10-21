#!/usr/bin/env bash
set -Eeuo pipefail

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
BUILD_DIR="${BUILD_DIR:-$XDG_CACHE_HOME/bootstrap/build}"
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
SRC_DIR="${SRC_DIR:-$HOME/soft}"
SUCKLESS_LOCK_FILE="${SUCKLESS_LOCK_FILE:-$SCRIPT_DIR/config/suckless.lock}"
SCI_PREFIX="${SCI_PREFIX:-$HOME/.local}"
SCI_REPOS_DIR="${SCI_REPOS_DIR:-$SRC_DIR}"
