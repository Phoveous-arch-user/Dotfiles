#!/usr/bin/env bash
# wallpaper.sh — wallpaper-based theming (saneAspect style)
# Sets a wallpaper and re-themes the whole stack with matugen.
#
#   wallpaper.sh set <path> [--no-theme]   set a wallpaper (re-theme by default)
#   wallpaper.sh next [folder]             cycle forward (within the active theme, or a folder)
#   wallpaper.sh prev [folder]             cycle backward
#   wallpaper.sh random [folder]           pick a random wallpaper

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib-theme.sh
source "$SCRIPT_DIR/lib-theme.sh"

usage() {
    cat <<'EOF'
Usage: wallpaper.sh <command>

  set <path> [--no-theme]   Set a wallpaper (and re-theme by default)
  next [folder]             Cycle to the next wallpaper (active theme's set, or a folder)
  prev [folder]             Cycle to the previous wallpaper
  random [folder]           Pick a random wallpaper
  select <path>             Apply a wallpaper, keeping the active theme's scheme/accent

With no folder argument, next/prev/random cycle only the wallpapers
associated with the active theme (theme folder images + its wallpapers key).
EOF
}

list_wallpapers() {
    local folder="$1"
    find "$folder" -maxdepth 2 -type f \
        \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) 2>/dev/null | sort
}

wallpaper_folder() {
    local folder="${1:-}"
    if [ -z "$folder" ]; then
        if [ -f "$WALLPAPER_FOLDER_STATE" ]; then
            folder="$(cat "$WALLPAPER_FOLDER_STATE")"
        else
            folder="$WALLPAPER_FOLDER_DEFAULT"
        fi
    fi
    [ -d "$folder" ] || die "wallpaper folder not found: $folder"
    echo "$folder"
}

pick_by_index() {
    local folder="$1" target="$2" want="$3"  # want = current index to offset from
    local -a imgs=()
    local line i=0 idx=-1
    while read -r line; do imgs+=("$line"); done < <(list_wallpapers "$folder")
    [ "${#imgs[@]}" -gt 0 ] || die "no wallpapers found in $folder"
    for i in "${!imgs[@]}"; do
        [ "${imgs[$i]}" = "$target" ] && idx="$i"
    done
    [ "$idx" -ge 0 ] || idx=0
    if [ "$want" = "next" ]; then
        idx=$(( (idx + 1) % ${#imgs[@]} ))
    else
        idx=$(( (idx - 1 + ${#imgs[@]}) % ${#imgs[@]} ))
    fi
    echo "${imgs[$idx]}"
}

set_wallpaper_themed() {
    local img="$1" theme="$2" mode="$3" scheme="$4" accent="$5"
    [ -f "$img" ] || die "wallpaper not found: $img"

    lock_acquire

    mkdir -p "$CACHE_DIR"
    echo "$img" > "$CURRENT_WALLPAPER"

    if [ "$theme" = "yes" ]; then
        mode="${mode:-$(current_mode)}"
        set_wallpaper "$img"
        generate_variants "$img"
        run_matugen "$img" "$mode" "${scheme:-scheme-tonal-spot}" "$accent"
        apply_clock_override
        reload_apps
    else
        set_wallpaper "$img"
    fi
    log "Wallpaper applied: $img"
}

# Cycle within the ACTIVE THEME's wallpaper set, keeping the theme's identity.
theme_wallpaper_pick() {
    local direction="$1"
    local name; name="$(current_theme)"
    [ -n "$name" ] && [ -d "$THEMES_DIR/$name" ] || die "no active theme — apply a theme or pass a folder"
    load_theme_config "$THEMES_DIR/$name"
    [ -n "$THEME_WALLPAPER_SET" ] || die "theme '$name' has no wallpapers"

    local -a imgs=()
    local line
    while IFS= read -r line; do imgs+=("$line"); done <<< "$THEME_WALLPAPER_SET"

    local cur; cur="$(cat "$CURRENT_WALLPAPER" 2>/dev/null)"
    local idx=0 i
    for i in "${!imgs[@]}"; do
        [ "${imgs[$i]}" = "$cur" ] && idx="$i"
    done
    case "$direction" in
        next) idx=$(( (idx + 1) % ${#imgs[@]} )) ;;
        prev) idx=$(( (idx - 1 + ${#imgs[@]}) % ${#imgs[@]} )) ;;
        random) idx=$(( RANDOM % ${#imgs[@]} )) ;;
    esac

    local img="${imgs[$idx]}"
    save_theme_wallpaper "$name" "$img"
    set_wallpaper_themed "$img" "yes" "$MODE" "$SCHEME" "$ACCENT"
}

# Apply a specific wallpaper in the context of the ACTIVE THEME, keeping the
# theme's scheme/accent/mode and remembering the choice for next time.
apply_in_theme() {
    local img="$1"
    [ -f "$img" ] || die "wallpaper not found: $img"
    local name; name="$(current_theme)"
    if [ -n "$name" ] && [ -d "$THEMES_DIR/$name" ]; then
        load_theme_config "$THEMES_DIR/$name"
        save_theme_wallpaper "$name" "$img"
        set_wallpaper_themed "$img" "yes" "$MODE" "$SCHEME" "$ACCENT"
    else
        set_wallpaper_themed "$img" "yes"
    fi
}

cycle_folder() {
    local folder; folder="$(wallpaper_folder "$1")"
    local current; current="$(cat "$CURRENT_WALLPAPER" 2>/dev/null)"
    local img; img="$(pick_by_index "$folder" "$current" "$CMD")"
    echo "$folder" > "$WALLPAPER_FOLDER_STATE"
    set_wallpaper_themed "$img" "yes"
}

CMD="${1:-set}"
case "$CMD" in
    set)
        [ -n "$2" ] || die "missing wallpaper path"
        local img="$2" theme="yes"
        [ "$3" = "--no-theme" ] && theme="no"
        set_wallpaper_themed "$img" "$theme"
        ;;
    next|prev|random)
        if [ -n "$2" ]; then
            cycle_folder "$2"
        else
            theme_wallpaper_pick "$CMD"
        fi
        ;;
    select)
        [ -n "$2" ] || die "missing wallpaper path"
        apply_in_theme "$2"
        ;;
    -h|--help|help) usage ;;
    *) set_wallpaper_themed "$CMD" "yes" ;;
esac
