#!/usr/bin/env bash
nmcli device wifi rescan >/dev/null 2>&1
sleep 1

NETWORKS=$(nmcli -t -f SSID,SIGNAL,SECURITY,IN-USE device wifi list | awk -F: '
{
    ssid = $1
    signal = $2
    security = $3
    inuse = $4
    if (ssid == "") next
    marker = (inuse == "*") ? " (connected)" : ""
    lock = (security != "" && security != "--") ? " " : ""
    print ssid " — " signal "%" lock marker
}' | sort -u)

if [ -z "$NETWORKS" ]; then
    notify-send "WiFi" "No networks found"
    exit 1
fi

CHOICE=$(echo "$NETWORKS" | walker --dmenu --placeholder "WiFi:")

if [ -z "$CHOICE" ]; then
    exit 0
fi

SSID=$(echo "$CHOICE" | sed 's/ — .*//')

if echo "$CHOICE" | grep -q "(connected)"; then
    exit 0
fi

if nmcli -t -f NAME connection show | grep -qx "$SSID"; then
    nmcli connection up "$SSID"
else
    SECURED=$(echo "$CHOICE" | grep -q "" && echo "yes" || echo "no")
    if [ "$SECURED" == "yes" ]; then
        PASSWORD=$(walker --dmenu --password --placeholder "Password for $SSID:")
        if [ -z "$PASSWORD" ]; then
            exit 0
        fi
        nmcli device wifi connect "$SSID" password "$PASSWORD"
    else
        nmcli device wifi connect "$SSID"
    fi
fi

if [ $? -eq 0 ]; then
    notify-send "WiFi" "Connected to $SSID"
else
    notify-send "WiFi" "Failed to connect to $SSID"
fi
