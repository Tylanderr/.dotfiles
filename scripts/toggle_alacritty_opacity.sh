#!/usr/bin/env bash

## If alacritty.toml does not exist, raise an alert
[[ ! -f /mnt/c/Documents/Alacritty/alacritty.toml ]] && \
    echo "alacritty.toml does not exist" && exit 0

## Fetch opacity from alacritty.toml (match only exact 'opacity' key)
opacity=$(awk -F '=' '/^opacity[[:space:]]*=/ {gsub(/ /, "", $2); print $2}' /mnt/c/Documents/Alacritty/alacritty.toml)

## Assign toggle opacity value
case $opacity in
  1)
    toggle_opacity=0.95
    ;;
  *)
    toggle_opacity=1
    ;;
esac

## Replace opacity value in alacritty.toml (match only exact 'opacity' key)
sed -i -- "s/^opacity = $opacity/opacity = $toggle_opacity/" /mnt/c/Documents/Alacritty/alacritty.toml
