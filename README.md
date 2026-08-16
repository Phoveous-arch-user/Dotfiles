# dotfiles

Personal desktop configuration backup.

## Contents

| What | Where |
|---|---|
| Hyprland config (lua) | `.config/hypr/` |
| Waybar | `.config/waybar/` |
| Rofi (launcher + theme switcher picker) | `.config/rofi/` |
| Theme-switcher color files | `.config/ml4w/` |
| SwayNC (notification center) | `.config/swaync/` |
| matugen templates (theme-switcher color engine) | `matugen/` |
| Theme wallpapers | `Pictures/Themes/` |
| SDDM (lock screen) | `sddm/` |

## Theme switcher

- Toggle with `CTRL + Tab` (`~/.config/hypr/scripts/theme-switcher.sh`)
- Wallpapers: `CTRL + left` / `CTRL + right`

## Install / restore

```bash
./install.sh          # symlink configs back into ~/.config, needs sudo for SDDM
./install.sh --force  # replace existing configs (old ones kept as *.bak)
```

## Re-backing up SDDM (run after changing the lock screen)

```bash
sudo cp -a /usr/share/sddm/themes/pixel-night-city sddm/theme-pixel-night-city
cp /etc/sddm.conf sddm/sddm.conf
```

## Re-backing up user configs

The `~/.config` dirs for hypr/waybar/rofi/ml4w/swaync are symlinked to this repo,
so any edits you make are already saved here. Then:

```bash
git add -A && git commit -m "update configs" && git push
```
