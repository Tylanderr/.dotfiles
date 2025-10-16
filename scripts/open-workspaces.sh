# !/bin/bash
hyprctl dispatch exec [workspace 6] $TERMINAL 
hyprctl dispatch exec [workspace 2 silent] /opt/zen-browser-bin/zen
hyprctl dispatch exec [workspace 5 silent] spotify
# hyprctl dispatch exec [workspace 3 silent] thunderbird

sleep 1
hyprctl dispatch workspace 4 && hyprctl dispatch exec "omarchy-launch-or-focus-webapp Discord 'https://discord.com/channels/@me'"
