#!/usr/bin/env bash
# wallpaper-picker.sh — horizontal wallpaper strip
#
# Shows every wallpaper belonging to the active theme as a scrollable strip
# of thumbnails. Hovering highlights a thumbnail; clicking (or Enter) applies
# it and re-themes the stack, keeping the theme's scheme/accent.
#
#   wallpaper-picker.sh [theme]   open the picker (default: active theme)
#   wallpaper-picker.sh list      print the wallpaper set being offered
#
# Keybinding: SUPER + W  (see ~/.config/hypr/hyprland.lua)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib-theme.sh
source "$SCRIPT_DIR/lib-theme.sh"

THEME_RASI="$HOME/.config/rofi/config-wallpaperpicker.rasi"

usage() {
    sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'
}

load_picker_set() { # $1 = theme name (optional) -> sets PICK_THEME + PICK_SET
    PICK_THEME="${1:-$(current_theme)}"
    if [ -n "$PICK_THEME" ] && [ -d "$THEMES_DIR/$PICK_THEME" ]; then
        load_theme_config "$THEMES_DIR/$PICK_THEME"
    else
        PICK_THEME=""
        WALLPAPER=""; WALLPAPERS="$WALLPAPER_FOLDER_DEFAULT"
        THEME_WALLPAPER_SET="$(build_wallpaper_set "$WALLPAPER_FOLDER_DEFAULT")"
    fi
    PICK_SET="$THEME_WALLPAPER_SET"
}

list_wallpapers() {
    load_picker_set "$1"
    printf '%s\n' "$PICK_SET"
}

open_picker() {
    has rofi || die "rofi not installed"
    load_picker_set "$1"
    [ -n "$PICK_SET" ] || die "no wallpapers for theme '${1:-$(current_theme)}'"

    # Make sure the rofi background import exists so the theme always parses.
    if [ ! -f "$ROFI_BG" ] && [ -n "$WALLPAPER" ] && [ -f "$WALLPAPER" ]; then
        mkdir -p "$(dirname "$ROFI_BG")"
        printf '* { current-image: url("%s", height); }\n' "$WALLPAPER" > "$ROFI_BG"
    fi

    local -a imgs=()
    local line
    while IFS= read -r line; do
        [ -n "$line" ] && imgs+=("$line")
    done <<< "$PICK_SET"
    [ "${#imgs[@]}" -gt 0 ] || die "no wallpapers found"

    # Full-resolution image is passed as the row icon so both the thumbnail
    # strip (element-icon) and the big preview (icon-current-entry) stay sharp.
    local cur input="" img base mark
    cur="$(cat "$CURRENT_WALLPAPER" 2>/dev/null)"
    for img in "${imgs[@]}"; do
        base="$(basename "$img")"
        mark=""
        [ "$img" = "$cur" ] && mark="  ✓"
        input+="$base$mark\0icon\x1f$img\n"
    done

    local idx
    idx="$(printf '%b' "$input" | rofi -dmenu \
        -config "$THEME_RASI" \
        -format i -i -p " Wallpaper " 2>/dev/null)"
    [ -n "$idx" ] || return 0

    img="${imgs[$idx]}"
    [ -n "$img" ] || return 0
    log "Applying wallpaper: $img"
    "$SCRIPT_DIR/wallpaper.sh" select "$img"
}

CMD="${1:-open}"
case "$CMD" in
    list) list_wallpapers "$2" ;;
    open|pick) open_picker "$2" ;;
    -h|--help|help) usage ;;
    *) open_picker "$CMD" ;;
esac
