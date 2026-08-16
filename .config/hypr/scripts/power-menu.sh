#!/usr/bin/env bash
# power-menu.sh — rofi power menu (lock / suspend / logout / reboot / shutdown)

CONFIG="$HOME/.config/rofi/power-menu.rasi"
OPTS=("Lock" "Suspend" "Logout" "Reboot" "Shutdown")

idx="$(printf '%s\n' \
    "  ${OPTS[0]}" \
    "  ${OPTS[1]}" \
    "  ${OPTS[2]}" \
    "  ${OPTS[3]}" \
    "  ${OPTS[4]}" \
    | rofi -dmenu -config "$CONFIG" -format i -i -p " " 2>/dev/null)"
[ -n "$idx" ] || exit 1

case "$idx" in
    0) hyprlock ;;
    1) systemctl suspend ;;
    2) hyprctl dispatch 'hl.dsp.exit()' ;;
    3) systemctl reboot ;;
    4) systemctl poweroff ;;
esac
