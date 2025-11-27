# Login shell: load generic profile first
[[ -f "$HOME/.profile" ]] && . "$HOME/.profile"

# Then interactive bash customizations
[[ -f "$HOME/.bashrc" ]] && . "$HOME/.bashrc"
