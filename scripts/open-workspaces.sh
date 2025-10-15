# !/bin/bash
hyprctl dispatch exec [workspace 2] /opt/zen-browser-bin/zen
hyprctl dispatch exec [workspace 3 silent] thunderbird
hyprctl dispatch exec [workspace 5 silent] spotify
hyprctl dispatch exec [workspace 6] ghostty
hyprctl dispatch exec "hyprctl dispatch workspace 4 && discord"
