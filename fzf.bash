# Setup fzf
# ---------
if [[ ! "$PATH" == */home/seva/scratch/software/fzf/bin* ]]; then
  PATH="${PATH:+${PATH}:}/home/seva/scratch/software/fzf/bin"
fi

eval "$(fzf --bash)"
