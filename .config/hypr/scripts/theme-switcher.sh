#!/usr/bin/env bash
# theme-switcher.sh — curated theme library for Hyprland
# Applies a full-stack theme (wallpaper + matugen colors + waybar + swaync + kitty + gtk + hyprland) in one go.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib-theme.sh
source "$SCRIPT_DIR/lib-theme.sh"

usage() {
    cat <<'EOF'
Usage: theme-switcher.sh <command>

  apply <name>   Apply a curated theme by name
  next | prev    Cycle to the next / previous theme
  menu           Open the theme picker (simple text list) — default
  grid           Open the theme picker (visual grid)
  list           List available themes
  current        Show the active theme
EOF
}

apply_theme() {
    local name="$1"
    [ -n "$name" ] || die "no theme selected"
    [ -d "$THEMES_DIR/$name" ] || die "unknown theme: $name"

    lock_acquire

    load_theme_config "$THEMES_DIR/$name"
    [ -n "$THEME_WALLPAPER_SET" ] || die "no wallpapers associated with theme '$name'"

    local img; img="$(resume_theme_wallpaper "$name")"
    [ -n "$img" ] || img="$WALLPAPER"

    mkdir -p "$CACHE_DIR"
    echo "$name" > "$CURRENT_FILE"
    echo "$img" > "$CURRENT_WALLPAPER"

    local mode="${MODE:-$(current_mode)}"
    set_gtk_mode "$mode"
    set_wallpaper "$img"
    generate_variants "$img"
    run_matugen "$img" "$mode" "$SCHEME" "$ACCENT"
    apply_clock_override
    save_theme_wallpaper "$name" "$img"
    reload_apps

    ensure_preview "$name" >/dev/null 2>&1
    log "Theme '$name' applied (mode=$mode scheme=${SCHEME:-scheme-tonal-spot} accent=${ACCENT:-auto})"
}

cycle_theme() {
    local direction="$1"
    local -a list=()
    local line
    while read -r line; do list+=("$line"); done < <(themes_sorted)
    [ "${#list[@]}" -gt 0 ] || die "no themes found in $THEMES_DIR"

    local cur; cur="$(current_theme)"
    local idx=0 i
    for i in "${!list[@]}"; do
        [ "${list[$i]}" = "$cur" ] && idx="$i"
    done
    if [ "$direction" = "next" ]; then
        idx=$(( (idx + 1) % ${#list[@]} ))
    else
        idx=$(( (idx - 1 + ${#list[@]}) % ${#list[@]} ))
    fi
    apply_theme "${list[$idx]}"
}

rofi_menu() {
    local config="$1"
    local -a names=()
    local input="" d name i=0
    for d in "$THEMES_DIR"/*/; do
        [ -d "$d" ] || continue
        name="$(basename "$d")"
        names[$i]="$name"
        load_theme_config "$d"
        local cur=""
        [ "$name" = "$(current_theme)" ] && cur="  (active)"
        if [ "$config" = "grid" ]; then
            ensure_preview "$name"
            input+="$NAME — $DESCRIPTION\0icon\x1f$CACHE_DIR/previews/$name.png\n"
        else
            input+="$NAME — $DESCRIPTION$cur\n"
        fi
        ((i++))
    done
    [ "$i" -gt 0 ] || die "no themes found in $THEMES_DIR"

    local idx
    idx="$(printf '%b' "$input" | rofi -dmenu \
        -config "$HOME/.config/rofi/$config.rasi" \
        -format i -i -p " Theme " 2>/dev/null)"
    [ -n "$idx" ] || return 1
    apply_theme "${names[$idx]}"
}

text_menu() { rofi_menu "config-themesimple"; }
grid_menu() { rofi_menu "config-themeswitcher"; }

list_themes() {
    local line cur
    cur="$(current_theme)"
    while read -r line; do
        load_theme_config "$THEMES_DIR/$line"
        local marker=""
        [ "$line" = "$cur" ] && marker="  (active)"
        printf '%-12s %s — %s%s\n' "$line" "$NAME" "${DESCRIPTION:-}" "$marker"
    done < <(themes_sorted)
}

CMD="${1:-menu}"
case "$CMD" in
    apply)   apply_theme "$2" ;;
    next|prev) cycle_theme "$CMD" ;;
    menu|pick|open) text_menu ;;
    grid)    grid_menu ;;
    list)    list_themes ;;
    current) current_theme; echo ;;
    -h|--help|help) usage ;;
    *)       usage; exit 1 ;;
esac
