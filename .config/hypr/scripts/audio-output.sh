#!/usr/bin/env bash

default="$(pactl get-default-sink 2>/dev/null)"

entries=""
for name in $(pactl list short sinks 2>/dev/null | awk '{print $2}'); do
    desc="$(pactl list sinks 2>/dev/null | awk -v n="$name" '
        /^Sink #/ { have = 0 }
        $1 == "Name:" && $2 == n { have = 1 }
        have && $1 == "Description:" { print substr($0, index($0, $2)); exit }')"
    marker=""
    [ "$name" = "$default" ] && marker=" (default)"
    entries+="$name — $desc$marker"$'\n'
done

[ -z "$entries" ] && exit 1

choice="$(printf '%s' "$entries" | walker --dmenu --placeholder "Audio Output:")"
[ -z "$choice" ] && exit 0

sink="$(echo "$choice" | sed 's/ — .*//')"
desc="$(echo "$choice" | sed 's/^[^—]*— //; s/ (default)//')"
[ -z "$sink" ] || [ "$sink" = "$default" ] && exit 0

pactl set-default-sink "$sink" 2>/dev/null
for idx in $(pactl list short sink-inputs 2>/dev/null | awk '{print $1}'); do
    pactl move-sink-input "$idx" "$sink" 2>/dev/null
done

notify-send -a "Audio" "Output: $desc"
