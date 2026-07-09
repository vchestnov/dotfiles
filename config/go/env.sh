# Go toolchain environment
#
# XDG_* variables are owned by profile. This file only reads them and falls
# back locally if it is sourced without the repo profile.

_go_xdg_data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
_go_xdg_cache_home="${XDG_CACHE_HOME:-$HOME/.cache}"

export GO_TOOLCHAIN_ROOT="${GO_TOOLCHAIN_ROOT:-$_go_xdg_data_home/go-toolchains}"
export GO_TOOLCHAIN_CURRENT="${GO_TOOLCHAIN_CURRENT:-$GO_TOOLCHAIN_ROOT/current}"
export GOPATH="${GOPATH:-$_go_xdg_data_home/go}"
export GOCACHE="${GOCACHE:-$_go_xdg_cache_home/go-build}"
export GOMODCACHE="${GOMODCACHE:-$_go_xdg_cache_home/go-mod}"

unset GOROOT

if [ -x "$GO_TOOLCHAIN_CURRENT/bin/go" ]; then
    export GOROOT="$GO_TOOLCHAIN_CURRENT"

    case ":$PATH:" in
        *:"$GOROOT/bin":*) ;;
        *) PATH="$GOROOT/bin${PATH:+:$PATH}" ;;
    esac
fi

case ":$PATH:" in
    *:"$GOPATH/bin":*) ;;
    *) PATH="$GOPATH/bin${PATH:+:$PATH}" ;;
esac

export PATH

unset _go_xdg_data_home _go_xdg_cache_home
