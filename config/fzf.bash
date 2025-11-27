# Setup fzf
# ---------
if [[ ! "$PATH" == */home/seva/.local/src/fzf/bin* ]]; then
  PATH="${PATH:+${PATH}:}/home/seva/.local/src/fzf/bin"
fi

eval "$(fzf --bash)"
