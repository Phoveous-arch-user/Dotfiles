#!/usr/bin/env bash
# lib-theme.sh — shared helpers for theme-switcher.sh and wallpaper.sh
# This is a library; source it, do not execute it.

# ---------------------------------------------------------------
# Paths / defaults
# ---------------------------------------------------------------
THEMES_DIR="${THEMES_DIR:-$HOME/.config/hypr/themes}"
CACHE_DIR="$HOME/.cache/hypr/themes"
CURRENT_FILE="$CACHE_DIR/current_theme"
CURRENT_WALLPAPER="$CACHE_DIR/current_wallpaper"
WALLPAPER_FOLDER_STATE="$CACHE_DIR/wallpaper_folder"
WALLPAPER_STATE_DIR="$CACHE_DIR/wallpaper_state"
BLURRED_WALL="$CACHE_DIR/blurred_wallpaper.png"
SQUARE_WALL="$CACHE_DIR/square_wallpaper.png"
ROFI_BG_DIR="$HOME/.cache/ml4w/hyprland-dotfiles"
ROFI_BG="$ROFI_BG_DIR/current_wallpaper.rasi"

TRANSITION="${TRANSITION:-any}"
BLUR="${BLUR:-0x20}"
WALLPAPER_FOLDER_DEFAULT="${WALLPAPER_FOLDER_DEFAULT:-$HOME/Pictures/Wallpapers}"

GTK3_SETTINGS="$HOME/.config/gtk-3.0/settings.ini"
GTK4_SETTINGS="$HOME/.config/gtk-4.0/settings.ini"

MATUGEN_BIN="matugen"
for _cand in "$HOME/.cargo/bin/matugen" "$HOME/.local/bin/matugen" "$(command -v matugen 2>/dev/null)"; do
    [ -n "$_cand" ] && [ -x "$_cand" ] && MATUGEN_BIN="$_cand" && break
done

# ---------------------------------------------------------------
# Utilities
# ---------------------------------------------------------------
log() { printf '%s\n' "[theme-switcher] $*" >&2; }
die() { log "ERROR: $*"; exit 1; }
has() { command -v "$1" >/dev/null 2>&1; }

# ---------------------------------------------------------------
# Apply lock (mkdir-based: atomic and never inherited by children)
# ---------------------------------------------------------------
LOCKDIR="$CACHE_DIR/.lock"
lock_acquire() {
    mkdir -p "$CACHE_DIR"
    if ! mkdir "$LOCKDIR" 2>/dev/null; then
        if [ -f "$LOCKDIR/pid" ] && ! kill -0 "$(cat "$LOCKDIR/pid" 2>/dev/null)" 2>/dev/null; then
            log "Removing stale lock from dead process $(cat "$LOCKDIR/pid")"
            rm -rf "$LOCKDIR"
            mkdir "$LOCKDIR" || die "could not create lock"
        else
            die "another apply is already running"
        fi
    fi
    echo $$ > "$LOCKDIR/pid"
    trap 'rm -rf "$LOCKDIR"' EXIT
    trap 'rm -rf "$LOCKDIR"; exit 1' INT TERM HUP
}
lock_release() {
    rm -rf "$LOCKDIR"
    trap - EXIT INT TERM HUP
}

# ---------------------------------------------------------------
# GTK light / dark mode
# ---------------------------------------------------------------
current_mode() {
    grep -E '^gtk-application-prefer-dark-theme=' "$GTK3_SETTINGS" 2>/dev/null \
        | awk -F= '{print $2}' | grep -qE '1|true' && echo "dark" || echo "light"
}

# Edits the *target* of a settings file so symlinks (dotfiles) are preserved.
_set_ini_bool() {
    local file="$1" key="$2" val="$3"
    [ -f "$file" ] || return 0
    local target; target="$(realpath "$file" 2>/dev/null || echo "$file")"
    if grep -qE "^$key=" "$target"; then
        sed -i "s|^$key=.*|$key=$val|" "$target"
    else
        printf '%s=%s\n' "$key" "$val" >> "$target"
    fi
}

set_gtk_mode() {
    local mode="$1" val=1
    [ "$mode" = "light" ] && val=0
    _set_ini_bool "$GTK3_SETTINGS" "gtk-application-prefer-dark-theme" "$val"
    _set_ini_bool "$GTK4_SETTINGS" "gtk-application-prefer-dark-theme" "$val"
    if has gsettings; then
        gsettings set org.gnome.desktop.interface color-scheme "prefer-$mode" 2>/dev/null
        gsettings set org.gnome.desktop.interface gtk-theme "Adwaita" 2>/dev/null
    fi
    log "GTK mode set to: $mode"
}

# ---------------------------------------------------------------
# Wallpaper (awww)
# ---------------------------------------------------------------
set_wallpaper() {
    local img="$1"
    has awww || { log "awww not found — skipping wallpaper"; return 1; }
    local args="--transition-type $TRANSITION"
    local minor patch
    read -r minor patch <<< "$(awww --version 2>/dev/null | awk -F. '{print $2 " " $3}')"
    if [ -n "$minor" ] && [ -n "$patch" ] && { [ "$minor" -gt 12 ] || { [ "$minor" -eq 12 ] && [ "$patch" -gt 0 ]; }; }; then
        args="--resize crop --crop-gravity center $args"
    fi
    log "Setting wallpaper: $img"
    awww img "$img" $args 2>/dev/null || awww img "$img" 2>/dev/null || log "Failed to set wallpaper"
}

# ---------------------------------------------------------------
# Blurred / square variants + rofi background
# ---------------------------------------------------------------
generate_variants() {
    local img="$1"
    mkdir -p "$CACHE_DIR" "$ROFI_BG_DIR"
    if has magick; then
        magick "$img" -resize 75% -blur "$BLUR" "$BLURRED_WALL" 2>/dev/null
        magick "$img" -gravity Center -extent 1:1 "$SQUARE_WALL" 2>/dev/null
    else
        cp "$img" "$BLURRED_WALL" 2>/dev/null
        cp "$img" "$SQUARE_WALL" 2>/dev/null
    fi
    printf '* { current-image: url("%s", height); }\n' "$BLURRED_WALL" > "$ROFI_BG"
    log "Wallpaper variants updated"
}

# ---------------------------------------------------------------
# matugen
# ---------------------------------------------------------------
run_matugen() {
    local img="$1" mode="$2" scheme="$3" accent="$4"
    local args=(-m "$mode" -t "${scheme:-scheme-tonal-spot}" -q)
    if [ -n "$accent" ]; then
        log "Running matugen from accent ${accent} (${mode}, ${scheme:-scheme-tonal-spot})"
        "$MATUGEN_BIN" color hex "${accent//\#/}" "${args[@]}" || die "matugen failed"
    else
        log "Running matugen from wallpaper (${mode}, ${scheme:-scheme-tonal-spot})"
        "$MATUGEN_BIN" image "$img" --source-color-index 0 "${args[@]}" || die "matugen failed"
    fi
}

apply_clock_override() {
    [ -n "$CLOCK" ] || return 0
    local css="$HOME/.config/waybar/colors.css"
    [ -f "$css" ] || return 0
    if grep -q '^@define-color clock ' "$css"; then
        sed -i "s|^@define-color clock .*|@define-color clock $CLOCK;|" "$css"
    else
        printf '\n@define-color clock %s;\n' "$CLOCK" >> "$css"
    fi
    log "Clock color overridden: $CLOCK"
}

# ---------------------------------------------------------------
# Reload running apps
# ---------------------------------------------------------------
reload_apps() {
    if has waybar; then
        if pgrep -x waybar >/dev/null 2>&1; then
            killall waybar 2>/dev/null || true
            sleep 0.4
        fi
        nohup waybar -c "$HOME/.config/waybar/config.jsonc" -s "$HOME/.config/waybar/style.css" >/dev/null 2>&1 &
        disown
        log "Waybar reloaded"
    fi
    if has swaync-client && pgrep -x swaync >/dev/null 2>&1; then
        swaync-client -rs 2>/dev/null || true
        log "SwayNC refreshed"
    fi
    if pgrep -x qs >/dev/null 2>&1; then
        qs ipc call theme-manager reload 2>/dev/null || true
    fi
    if has pywalfox; then
        pywalfox update 2>/dev/null || true
    fi
    if has hyprctl; then
        hyprctl reload >/dev/null 2>&1
    fi
}

# ---------------------------------------------------------------
# Theme config parsing
# ---------------------------------------------------------------
image_files() { 
    local p
    for p in "$@"; do
        [ -e "$p" ] || continue
        if [ -d "$p" ]; then
            find "$p" -maxdepth 1 -type f \
                \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) 2>/dev/null | sort
        elif [ -f "$p" ]; then
            echo "$p"
        fi
    done
}

build_wallpaper_set() {
    local dir="$1" path line
    local -a parts=() images=()
    local -A seen=()
    if [ -n "$WALLPAPER" ] && [ -f "$WALLPAPER" ]; then
        seen["$WALLPAPER"]=1
        images+=("$WALLPAPER")
    fi
    if [ -n "$WALLPAPERS" ]; then
        IFS=';' read -ra parts <<< "$WALLPAPERS"
        for path in "${parts[@]}"; do
            path="${path//[$'\t\r ']/}"
            while IFS= read -r line; do
                [ -n "$line" ] && [ -z "${seen[$line]:-}" ] && { seen["$line"]=1; images+=("$line"); }
            done < <(image_files "$path")
        done
    fi
    while IFS= read -r line; do
        [ -n "$line" ] && [ -z "${seen[$line]:-}" ] && { seen["$line"]=1; images+=("$line"); }
    done < <(image_files "$dir")
    printf '%s\n' "${images[@]}"
}

load_theme_config() {
    local dir="$1"
    ACCENT="" MODE="" SCHEME="scheme-tonal-spot" WALLPAPER="" WALLPAPERS="" DESCRIPTION="" NAME="" ORDER="99" CLOCK=""
    local conf="$dir/theme.conf"
    if [ -f "$conf" ]; then
        local k v
        while IFS='=' read -r k v; do
            k="${k//[$'\t\r ']/}"
            [ -n "$k" ] || continue
            case "$k" in
                \#*) continue ;;
            esac
            v="${v//\~/$HOME}"
            v="${v#\"}"; v="${v%\"}"
            v="${v#\'}"; v="${v%\'}"
            v="${v#"${v%%[![:space:]]*}"}"
            v="${v%"${v##*[![:space:]]}"}"
            case "$k" in
                accent)      ACCENT="$v" ;;
                mode)        MODE="$v" ;;
                scheme)      SCHEME="$v" ;;
                description) DESCRIPTION="$v" ;;
                name)        NAME="$v" ;;
                order)       ORDER="$v" ;;
                wallpaper)   WALLPAPER="$v" ;;
                wallpapers)  WALLPAPERS="$v" ;;
                clock)       CLOCK="$v" ;;
            esac
        done < <(grep -vE '^\s*#|^\s*$' "$conf")
    fi
    [ -n "$NAME" ] || NAME="$(basename "$dir")"
    THEME_WALLPAPER_SET="$(build_wallpaper_set "$dir")"
    [ -n "$WALLPAPER" ] || WALLPAPER="${THEME_WALLPAPER_SET%%$'\n'*}"
}

theme_wallpapers() { # print the wallpaper set for a theme by name
    load_theme_config "$THEMES_DIR/$1"
    printf '%s\n' "$THEME_WALLPAPER_SET"
}

resume_theme_wallpaper() { # echo last-used wallpaper for $1 if still in current set
    local stored
    stored="$(cat "$WALLPAPER_STATE_DIR/$1" 2>/dev/null)"
    if [ -n "$stored" ] && grep -qF -- "$stored" <<< "$THEME_WALLPAPER_SET"; then
        echo "$stored"
    fi
}

save_theme_wallpaper() { # remember last-used wallpaper per theme
    mkdir -p "$WALLPAPER_STATE_DIR"
    echo "$2" > "$WALLPAPER_STATE_DIR/$1"
}

get_dominant_color() {
    local img="$1" hex
    if has magick; then
        hex="$(magick "$img" -resize 1x1! -colorspace sRGB txt:- 2>/dev/null | grep -oE '#[0-9A-Fa-f]{6,8}' | head -1)"
    fi
    [ -n "$hex" ] && echo "${hex:0:7}" || echo "#1a1a1a"
}

# ---------------------------------------------------------------
# Preview card for the rofi picker
# ---------------------------------------------------------------
ensure_preview() {
    local name="$1"
    local out="$CACHE_DIR/previews/$name.png"
    mkdir -p "$CACHE_DIR/previews"
    load_theme_config "$THEMES_DIR/$name"
    [ -n "$WALLPAPER" ] && [ -f "$WALLPAPER" ] || return 0
    if [ ! -f "$out" ] || [ "$WALLPAPER" -nt "$out" ]; then
        local accent="${ACCENT:-$(get_dominant_color "$WALLPAPER")}"
        if has magick; then
            magick "$WALLPAPER" -resize 400x225^ -gravity center -extent 400x225 \
                -fill "rgba(0,0,0,0.42)" -draw "rectangle 0,0 400,225" \
                -fill "$accent" -draw "rectangle 0,180 400,225" \
                "$out" 2>/dev/null
        fi
    fi
}

# ---------------------------------------------------------------
# Theme ordering
# ---------------------------------------------------------------
themes_sorted() {
    local -a pairs=()
    local d name
    for d in "$THEMES_DIR"/*/; do
        [ -d "$d" ] || continue
        name="$(basename "$d")"
        load_theme_config "$d"
        pairs+=("$(printf '%s %s' "$(printf '%04d' "${ORDER:-99}")" "$name")")
    done
    printf '%s\n' "${pairs[@]}" | sort -k1,1 -k2,2 | awk '{ print $2 }'
}

current_theme() {
    [ -f "$CURRENT_FILE" ] && cat "$CURRENT_FILE"
}
