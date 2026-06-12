#!/bin/bash

# =========================
# SPEED OPTIMIZATION
# =========================
export NM_CLIENT_TIMEOUT=3

# =========================
# WIFI LIST (FAST MODE)
# =========================
wifi_list=$(nmcli -t -f SSID,SECURITY,BARS device wifi list --rescan no | grep -v '^:' | sort -u)

# =========================
# VPN LIST
# =========================
vpn_list=$(nmcli -t -f NAME,TYPE connection show | awk -F: '$2=="vpn" || $2=="wireguard"{print $1}')

active_vpn=$(nmcli -t -f NAME,TYPE connection show --active | awk -F: '$2=="vpn" || $2=="wireguard"{print $1}')

current_ssid=$(nmcli -t -f ACTIVE,SSID dev wifi | awk -F: '$1=="yes"{print $2}')

# =========================
# BUILD MENU
# =========================
menu=""

# =========================
# ACTIVE VPN (TOP GLOBAL)
# =========================
if [ -n "$active_vpn" ]; then
    menu+="━━ VPN ACTIVA ━━\n"
    menu+="󰖂  ● $active_vpn\n\n"
fi

menu+="━━ WIFI ━━\n"

# =========================
# WIFI SECTION
# =========================
declare -A seen_ssid

while IFS=':' read -r ssid security bars; do
    [ -z "$ssid" ] && continue

    if [[ -n "${seen_ssid[$ssid]}" ]]; then
        continue
    fi
    seen_ssid[$ssid]=1

    if [[ "$ssid" == "$current_ssid" ]]; then
        menu+="  ● $ssid (Conectado)\n"
    else
        if [[ "$security" == *"WPA"* ]]; then
            menu+="    $ssid (Seguro)\n"
        else
            menu+="    $ssid (Abierta)\n"
        fi
    fi

done <<< "$wifi_list"

# =========================
# VPN SECTION (DISPONIBLES)
# =========================
menu+="\n━━ VPN DISPONIBLES ━━\n"

while read -r vpn_name; do
    [ -z "$vpn_name" ] && continue

    # skip active vpn (already shown on top)
    echo "$active_vpn" | grep -qxF "$vpn_name" && continue

    menu+="󰖂    $vpn_name\n"
done <<< "$vpn_list"

# =========================
# ROFI MENU
# =========================
chosen=$(echo -e "$menu" | rofi -dmenu -i -p "Redes / VPN" -config ~/.config/rofi/network.rasi)

[ -z "$chosen" ] && exit 0

# =========================
# VPN TOGGLE
# =========================
if [[ "$chosen" == *"󰖂"* ]]; then

    vpn_name=$(echo "$chosen" | sed -E 's/^󰖂  ● //; s/^󰖂    //')

    if echo "$active_vpn" | grep -qxF "$vpn_name"; then
        notify-send "VPN" "Desconectando $vpn_name"
        nmcli connection down id "$vpn_name"
    else
        notify-send "VPN" "Conectando $vpn_name"
        nmcli connection up id "$vpn_name"
    fi

# =========================
# WIFI CONNECT
# =========================
else
    ssid=$(echo "$chosen" | sed -E 's/^[^ ]+  ● //; s/^[^ ]+    //; s/ \(.*\)//')

    if nmcli -t -f NAME connection show --active | grep -qxF "$ssid"; then
        notify-send "WiFi" "Ya conectado a $ssid"
        exit 0
    fi

    if [[ "$chosen" == *"(Abierta)"* ]]; then
        nmcli device wifi connect "$ssid" && notify-send "WiFi" "Conectado $ssid"
    else
        if nmcli connection show | grep -qxF "$ssid"; then
            nmcli connection up id "$ssid" && notify-send "WiFi" "Conectado $ssid"
        else
            pass=$(rofi -dmenu -p "Password $ssid:" -password -config ~/.config/rofi/network.rasi)
            [ -z "$pass" ] && exit 0

            nmcli device wifi connect "$ssid" password "$pass" && notify-send "WiFi" "Conectado $ssid"
        fi
    fi
fi
