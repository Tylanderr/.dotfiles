# Setup fzf
# ---------
if [[ ! "$PATH" == */home/tyler/.fzf/bin* ]]; then
  PATH="${PATH:+${PATH}:}/home/tyler/.fzf/bin"
fi

eval "$(fzf --bash)"
