# Use the fzf installed on PATH; profile adds the user-local bin directory.
if command -v fzf >/dev/null 2>&1; then
    source <(fzf --bash)
fi
