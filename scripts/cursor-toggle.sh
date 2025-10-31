# !/bin/bash
current=$(hyprctl getoption cursor:hide_on_key_press -j | jq -r ".int");
if [ "$current" = "1" ]; then
    hyprctl keyword cursor:hide_on_key_press false;
    notify-send "Cursor" "Hide on key press: OFF";
else
    hyprctl keyword cursor:hide_on_key_press true;
    notify-send "Cursor" "Hide on key press: ON";
fi
