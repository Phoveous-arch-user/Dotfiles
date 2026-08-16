#!/usr/bin/env bash
# install.sh — restore the desktop config from this repo.
# Safe by default: never overwrites an existing file unless --force is given.
#
# Usage:
#   ./install.sh            # restore everything
#   ./install.sh --force    # overwrite existing configs (existing ones moved to <path>.bak)
#   ./install.sh --help

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORCE=0
for a in "$@"; do
    case "$a" in
        --force) FORCE=1 ;;
        --help|-h) grep '^#' "$0" | head -20; exit 0 ;;
        *) echo "Unknown arg: $a" >&2; exit 1 ;;
    esac
done

link() {
    local src="$1" dst="$2"
    [ -e "$src" ] || { echo "  [skip] $dst (missing in repo)"; return 0; }
    if [ -e "$dst" ] || [ -L "$dst" ]; then
        if [ "$FORCE" -eq 1 ]; then
            mv "$dst" "$dst.bak" 2>/dev/null || true
        else
            echo "  [skip] $dst already exists (use --force to replace)"
            return 0
        fi
    fi
    mkdir -p "$(dirname "$dst")"
    ln -s "$src" "$dst"
    echo "  [ok]   $dst -> $src"
}

copy() {
    local src="$1" dst="$2"
    [ -e "$src" ] || { echo "  [skip] $dst (missing in repo)"; return 0; }
    if [ -e "$dst" ] || [ -L "$dst" ]; then
        if [ "$FORCE" -eq 1 ]; then
            mv "$dst" "$dst.bak" 2>/dev/null || true
        else
            echo "  [skip] $dst already exists (use --force to replace)"
            return 0
        fi
    fi
    mkdir -p "$(dirname "$dst")"
    cp -a "$src" "$dst"
    echo "  [ok]   $dst"
}

echo "==> Restoring Hyprland config"
link "$REPO/.config/hypr"      "$HOME/.config/hypr"

echo "==> Restoring Waybar"
link "$REPO/.config/waybar"    "$HOME/.config/waybar"

echo "==> Restoring Rofi (theme switcher / launcher)"
link "$REPO/.config/rofi"      "$HOME/.config/rofi"

echo "==> Restoring theme-switcher colors"
link "$REPO/.config/ml4w"      "$HOME/.config/ml4w"

echo "==> Restoring SwayNC"
link "$REPO/.config/swaync"    "$HOME/.config/swaync"

echo "==> Restoring matugen templates (used by the theme switcher)"
link "$REPO/matugen"           "$HOME/.config/matugen"

echo "==> Restoring theme wallpapers"
mkdir -p "$HOME/Pictures"
link "$REPO/Pictures/Themes"   "$HOME/Pictures/Themes"

echo "==> Restoring SDDM (needs sudo)"
if command -v sudo >/dev/null 2>&1; then
    sudo mkdir -p /usr/share/sddm/themes
    if [ -d /usr/share/sddm/themes/pixel-night-city ] && [ "$FORCE" -eq 1 ]; then
        sudo mv /usr/share/sddm/themes/pixel-night-city /usr/share/sddm/themes/pixel-night-city.bak
    fi
    if [ ! -d /usr/share/sddm/themes/pixel-night-city ]; then
        sudo cp -a "$REPO/sddm/theme-pixel-night-city" /usr/share/sddm/themes/pixel-night-city
        echo "  [ok]   /usr/share/sddm/themes/pixel-night-city"
    else
        echo "  [skip] /usr/share/sddm/themes/pixel-night-city already exists (use --force to replace)"
    fi
    if [ -f /etc/sddm.conf ] && [ "$FORCE" -eq 1 ]; then
        sudo mv /etc/sddm.conf /etc/sddm.conf.bak
    fi
    if [ ! -f /etc/sddm.conf ]; then
        sudo cp "$REPO/sddm/sddm.conf" /etc/sddm.conf
        echo "  [ok]   /etc/sddm.conf"
    else
        echo "  [skip] /etc/sddm.conf already exists (use --force to replace)"
    fi
else
    echo "  sudo not available — copy sddm/ manually"
fi

echo
echo "Done. Log out and back in for changes to take effect."
