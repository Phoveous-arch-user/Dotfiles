#!/usr/bin/env bash

if hyprctl layers -j 2>/dev/null | grep -q swaync-control-center; then
    swaync-client -cp
else
    swaync-client -op
fi
