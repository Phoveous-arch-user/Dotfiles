#!/usr/bin/env bash

STATE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/display"
STATE="$STATE_DIR/state"
mkdir -p "$STATE_DIR"

if [ ! -f "$STATE" ]; then
    printf 'temp=off\n' > "$STATE"
fi

get() { awk -F= -v k="$1" '$1 == k { print $2 }' "$STATE"; }
put() { sed -i "s/^$1=.*/$1=$2/" "$STATE"; }

apply() {
    command -v gammastep >/dev/null 2>&1 || {
        notify-send -a "Display" -u critical "gammastep not installed" "Run: sudo pacman -S gammastep"
        return 1
    }

    pkill -x gammastep 2>/dev/null
    if [ "$(get temp)" != "off" ]; then
        setsid gammastep -P -O 4500 >/dev/null 2>&1 &
    fi
}

case "${1:-blue}" in
    blue)
        case "${2:-toggle}" in
            on)
                put temp 4500
                apply
                notify-send -a "Blue light" "Blue light filter" "On — warmer screen"
                ;;
            off)
                put temp off
                apply
                notify-send -a "Blue light" "Blue light filter" "Off"
                ;;
            toggle)
                if [ "$(get temp)" = "off" ]; then
                    put temp 4500
                else
                    put temp off
                fi
                apply
                if [ "$(get temp)" = "off" ]; then
                    notify-send -a "Blue light" "Blue light filter" "Off"
                else
                    notify-send -a "Blue light" "Blue light filter" "On — warmer screen"
                fi
                ;;
            status)
                get temp
                ;;
        esac
        ;;
    *)
        echo "usage: $0 blue [on|off|toggle|status]" >&2
        exit 2
        ;;
esac
